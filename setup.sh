#!/bin/bash
set -e

# Colors for styling
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Check if gum is installed
if ! command -v gum &> /dev/null; then
    echo -e "${RED}❌ Gum is not installed. Please install it first:${NC}"
    echo "  brew install gum"
    echo "  Or visit: https://github.com/charmbracelet/gum#installation"
    exit 1
fi

# Check if gh CLI is installed
if ! command -v gh &> /dev/null; then
    echo -e "${RED}❌ GitHub CLI is not installed. Please install it first:${NC}"
    echo "  brew install gh"
    exit 1
fi

# Check if user is authenticated with GitHub CLI
if ! gh auth status &> /dev/null; then
    echo -e "${RED}❌ You need to authenticate with GitHub CLI first:${NC}"
    echo "  gh auth login"
    exit 1
fi

# Welcome message
gum style \
    --border normal \
    --margin "1" \
    --padding "1 2" \
    --border-foreground 212 \
    "🚀 Welcome to VPS Template Setup!" \
    "" \
    "This script will help you set up your VPS with NixOS," \
    "configure GitHub secrets, and deploy your infrastructure." \
    "" \
    "Make sure you have:" \
    "• A fresh VPS (Ubuntu recommended)" \
    "• Tailscale account" \
    "• Domain pointing to your VPS" \
    "• GitHub CLI authenticated"

echo

# Get repository info
REPO_INFO=$(git remote get-url origin | sed 's/.*github.com[/:]\([^/]*\)\/\([^.]*\).*/\1 \2/')
GITHUB_ORG=$(echo $REPO_INFO | cut -d' ' -f1)
GITHUB_REPO=$(echo $REPO_INFO | cut -d' ' -f2)

gum style --foreground 212 "📦 Detected Repository: $GITHUB_ORG/$GITHUB_REPO"

# Collect user inputs
echo
gum style --foreground 99 --bold "Let's gather some information..."

EMAIL=$(gum input --placeholder "Enter your email for ACME certificates (e.g., you@example.com)")
DOMAIN=$(gum input --placeholder "Enter your domain (e.g., example.com)")
VPS_IP=$(gum input --placeholder "Enter your VPS IP address (e.g., 192.168.1.100)")

# Sanity checks
echo
gum style --foreground 99 --bold "🔍 Running sanity checks..."

# Check if domain resolves to VPS IP
gum spin --spinner dot --title "Checking if domain resolves to VPS IP..." -- sleep 1
RESOLVED_IP=$(dig +short $DOMAIN | tail -n1)
if [ "$RESOLVED_IP" != "$VPS_IP" ]; then
    gum style --foreground 196 "⚠️  Warning: Domain $DOMAIN resolves to $RESOLVED_IP, but VPS IP is $VPS_IP"
    if ! gum confirm "Continue anyway?"; then
        exit 1
    fi
else
    gum style --foreground 46 "✅ Domain resolves correctly"
fi

# Ping VPS
gum spin --spinner dot --title "Pinging VPS..." -- ping -c 1 $VPS_IP > /dev/null 2>&1
if [ $? -eq 0 ]; then
    gum style --foreground 46 "✅ VPS is reachable"
else
    gum style --foreground 196 "❌ Cannot reach VPS at $VPS_IP"
    exit 1
fi

# Test SSH connection
gum spin --spinner dot --title "Testing SSH connection..." -- timeout 5 ssh -o BatchMode=yes -o ConnectTimeout=5 root@$VPS_IP exit 2>/dev/null
if [ $? -eq 0 ]; then
    gum style --foreground 46 "✅ SSH connection successful"
else
    gum style --foreground 196 "❌ Cannot SSH to VPS. Make sure you can SSH as root."
    if ! gum confirm "Continue anyway? (You'll need to fix SSH access later)"; then
        exit 1
    fi
fi

# Tailscale setup
echo
gum style --foreground 99 --bold "🔧 Tailscale Setup"
gum style --foreground 250 "You need to set up Tailscale OAuth for GitHub Actions."
gum style --foreground 250 "1. Go to: https://login.tailscale.com/admin/settings/oauth"
gum style --foreground 250 "2. Generate OAuth client"
gum style --foreground 250 "3. Copy the Client ID and Client Secret"

if ! gum confirm "Have you created the Tailscale OAuth client?"; then
    gum style --foreground 196 "Please create the OAuth client first, then run this script again."
    exit 1
fi

TS_OAUTH_CLIENT_ID=$(gum input --placeholder "Enter Tailscale OAuth Client ID")
TS_OAUTH_SECRET=$(gum input --password --placeholder "Enter Tailscale OAuth Client Secret")

gum style --foreground 250 "Now you need a Tailscale auth key for the VPS."
gum style --foreground 250 "Go to: https://login.tailscale.com/admin/settings/keys"
TS_AUTH_KEY=$(gum input --password --placeholder "Enter Tailscale Auth Key")

# Generate SSH key
echo
gum style --foreground 99 --bold "🔑 Generating SSH keys..."

SSH_KEY_PATH="/tmp/vps-setup-key"
if [ -f "$SSH_KEY_PATH" ]; then
    if gum confirm "SSH key already exists. Regenerate?"; then
        rm -f "$SSH_KEY_PATH" "$SSH_KEY_PATH.pub"
    fi
fi

if [ ! -f "$SSH_KEY_PATH" ]; then
    gum spin --spinner dot --title "Generating SSH key pair..." -- ssh-keygen -t ed25519 -f "$SSH_KEY_PATH" -N "" -C "vps-setup-$(date +%s)"
    gum style --foreground 46 "✅ SSH key generated"
fi

SSH_PUBLIC_KEY=$(cat "$SSH_KEY_PATH.pub")
SSH_PRIVATE_KEY=$(cat "$SSH_KEY_PATH")

# Generate Grafana password
GRAFANA_PASSWORD=$(openssl rand -base64 32)
gum style --foreground 46 "✅ Generated Grafana admin password"

# Replace placeholders in files
echo
gum style --foreground 99 --bold "📝 Updating configuration files..."

# Find all non-markdown files and replace placeholders
find . -type f \( -name "*.nix" -o -name "*.yaml" -o -name "*.yml" \) -not -path "./.git/*" | while read file; do
    if grep -q "YOUR_" "$file"; then
        gum style --foreground 250 "Updating $file"
        sed -i.bak \
            -e "s/YOUR_GITHUB_ORG/$GITHUB_ORG/g" \
            -e "s/YOUR_GITHUB_REPO/$GITHUB_REPO/g" \
            -e "s/YOUR_EMAIL/$EMAIL/g" \
            -e "s/YOUR_DOMAIN/$DOMAIN/g" \
            -e "s/YOUR_SSH_PUBLIC_KEY/$SSH_PUBLIC_KEY/g" \
            -e "s/YOUR_GITHUB_ACTION_SSH_PUBLIC_KEY/$SSH_PUBLIC_KEY/g" \
            -e "s/TS_KEY_GOES_HERE/$TS_AUTH_KEY/g" \
            "$file"
        rm "$file.bak"
    fi
done

gum style --foreground 46 "✅ Configuration files updated"

# Upload GitHub secrets
echo
gum style --foreground 99 --bold "🔐 Uploading GitHub secrets..."

secrets=(
    "VPS_IP:$VPS_IP"
    "VPS_SSH_PRIVATE_KEY:$SSH_PRIVATE_KEY"
    "GRAFANA_ADMIN_PASSWORD:$GRAFANA_PASSWORD"
    "TS_OAUTH_CLIENT_ID:$TS_OAUTH_CLIENT_ID"
    "TS_OAUTH_SECRET:$TS_OAUTH_SECRET"
)

for secret in "${secrets[@]}"; do
    key=$(echo $secret | cut -d':' -f1)
    value=$(echo $secret | cut -d':' -f2-)
    gum spin --spinner dot --title "Uploading secret $key..." -- gh secret set "$key" --body "$value"
done

gum style --foreground 46 "✅ GitHub secrets uploaded"

# Clean up private key
rm -f "$SSH_KEY_PATH"
gum style --foreground 46 "✅ Private key cleaned up"

# NixOS Infect confirmation
echo
gum style \
    --border double \
    --margin "1" \
    --padding "1 2" \
    --border-foreground 196 \
    --foreground 196 \
    --bold \
    "⚠️  DANGER ZONE ⚠️" \
    "" \
    "The next step will COMPLETELY WIPE your VPS" \
    "and install NixOS. This is IRREVERSIBLE!" \
    "" \
    "Make sure you have backups of anything important!"

if ! gum confirm --default=false "Are you absolutely sure you want to proceed with NixOS infect?"; then
    gum style --foreground 250 "Setup paused. Run this script again when ready."
    exit 0
fi

# NixOS Infect
echo
gum style --foreground 99 --bold "🚀 Installing NixOS on VPS..."

INFECT_CMD='curl https://raw.githubusercontent.com/elitak/nixos-infect/master/nixos-infect | PROVIDER=hetznercloud NIX_CHANNEL=nixos-25.05 bash 2>&1 | tee /tmp/infect.log'

gum spin --spinner dot --title "Running NixOS infect (this will take several minutes)..." -- ssh root@$VPS_IP "$INFECT_CMD"

if [ $? -eq 0 ]; then
    gum style --foreground 46 "✅ NixOS infect completed successfully"
else
    gum style --foreground 196 "❌ NixOS infect failed"
    exit 1
fi

# Wait for reboot
gum style --foreground 250 "Waiting for VPS to reboot..."
sleep 30

# Test new connection
gum spin --spinner dot --title "Testing connection to NixOS..." -- sleep 5
until ssh -o BatchMode=yes -o ConnectTimeout=5 root@$VPS_IP exit 2>/dev/null; do
    gum spin --spinner dot --title "Waiting for VPS to come back online..." -- sleep 10
done

gum style --foreground 46 "✅ VPS is back online with NixOS"

# Download configs
echo
gum style --foreground 99 --bold "📥 Downloading NixOS configurations..."

mkdir -p infra/vps-0

gum spin --spinner dot --title "Downloading hardware-configuration.nix..." -- scp root@$VPS_IP:/etc/nixos/hardware-configuration.nix ./infra/vps-0/
gum spin --spinner dot --title "Downloading networking.nix..." -- scp root@$VPS_IP:/etc/nixos/networking.nix ./infra/vps-0/

gum style --foreground 46 "✅ Configurations downloaded"

# Deploy new config
echo
gum style --foreground 99 --bold "🚀 Deploying NixOS configuration..."

gum spin --spinner dot --title "Running make deploy..." -- make deploy

if [ $? -eq 0 ]; then
    gum style --foreground 46 "✅ Deployment successful"
else
    gum style --foreground 196 "❌ Deployment failed"
    exit 1
fi

# Clean up public key
rm -f "$SSH_KEY_PATH.pub"

# Commit and push
echo
gum style --foreground 99 --bold "📤 Committing and pushing changes..."

git add .
git commit -m "feat: configure VPS template with user-specific settings

- Updated configuration files with domain: $DOMAIN
- Added SSH keys and secrets
- Ready for deployment"

git push origin main

gum style --foreground 46 "✅ Changes committed and pushed"

# Final success message
echo
gum style \
    --border double \
    --margin "1" \
    --padding "1 2" \
    --border-foreground 46 \
    --foreground 46 \
    --bold \
    "🎉 Setup Complete!" \
    "" \
    "Your VPS is now configured with:" \
    "• NixOS with your custom configuration" \
    "• GitHub Actions secrets uploaded" \
    "• Tailscale integration ready" \
    "• Monitoring stack configured" \
    "" \
    "Next steps:" \
    "• Check GitHub Actions for deployment status" \
    "• Access Grafana at: https://grafana.$DOMAIN" \
    "• Your app will be at: https://$DOMAIN" \
    "" \
    "Grafana admin password: $GRAFANA_PASSWORD"

echo
gum style --foreground 212 "Happy coding! 🚀"
