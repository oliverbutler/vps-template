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
while true; do
    gum spin --spinner dot --title "Checking if domain resolves to VPS IP..." -- sleep 1
    RESOLVED_IP=$(dig +short $DOMAIN | tail -n1)
    if [ "$RESOLVED_IP" != "$VPS_IP" ]; then
        gum style --foreground 196 "⚠️  Warning: Domain $DOMAIN resolves to $RESOLVED_IP, but VPS IP is $VPS_IP"
        CHOICE=$(gum choose --header "What would you like to do?" "Try again" "Continue anyway" "Exit")
        case $CHOICE in
            "Try again")
                continue
                ;;
            "Continue anyway")
                break
                ;;
            "Exit")
                exit 1
                ;;
        esac
    else
        gum style --foreground 46 "✅ Domain resolves correctly"
        break
    fi
done


# Test SSH connection (skip ping as many providers block ICMP)
gum style --foreground 250 "🔑 Testing SSH connectivity..."
while true; do
    gum style --foreground 250 "Attempting SSH connection to root@$VPS_IP..."
    
    # Test SSH connection with timeout
    if timeout 10 ssh -o BatchMode=yes -o ConnectTimeout=5 -o StrictHostKeyChecking=no root@$VPS_IP exit 2>/dev/null; then
        gum style --foreground 46 "✅ SSH connection successful"
        break
    else
        gum style --foreground 196 "❌ Cannot SSH to VPS"
        gum style --foreground 250 "Make sure you can SSH as root with key-based authentication."
        gum style --foreground 250 "Try: ssh root@$VPS_IP"
        
        CHOICE=$(gum choose --header "What would you like to do?" "Try again" "Continue anyway" "Exit")
        case $CHOICE in
            "Try again")
                continue
                ;;
            "Continue anyway")
                gum style --foreground 250 "⚠️  Continuing without SSH verification - you'll need working SSH for deployment"
                break
                ;;
            "Exit")
                exit 1
                ;;
        esac
    fi
done

# Tailscale setup
echo
gum style --foreground 99 --bold "🔧 Tailscale Setup"
gum style --foreground 250 "You need to set up Tailscale OAuth for GitHub Actions."
gum style --foreground 250 "1. Go to: https://login.tailscale.com/admin/settings/oauth"
gum style --foreground 250 "2. Generate OAuth client with 'auth-keys' permission"
gum style --foreground 250 "3. IMPORTANT: Tag it (e.g., create a tag for your project)"
gum style --foreground 250 "   This limits GitHub Actions access to only your app's devices"
gum style --foreground 250 "4. Copy the Client ID and Client Secret"

if ! gum confirm "Have you created the Tailscale OAuth client?"; then
    gum style --foreground 196 "Please create the OAuth client first, then run this script again."
    exit 1
fi

TS_OAUTH_CLIENT_ID=$(gum input --placeholder "Enter Tailscale OAuth Client ID")
TS_OAUTH_SECRET=$(gum input --password --placeholder "Enter Tailscale OAuth Client Secret")

gum style --foreground 250 "Now you need a Tailscale auth key for the VPS."
gum style --foreground 250 "Go to: https://login.tailscale.com/admin/settings/keys"
TS_AUTH_KEY=$(gum input --password --placeholder "Enter Tailscale Auth Key")

# Select user's personal SSH key
echo
gum style --foreground 99 --bold "🔑 Select your personal SSH key"
gum style --foreground 250 "Choose your personal SSH key for VPS access:"

# Find available SSH public keys
SSH_KEYS=()
if [ -d "$HOME/.ssh" ]; then
    while IFS= read -r -d '' file; do
        if [[ "$file" == *.pub ]]; then
            key_name=$(basename "$file" .pub)
            key_type=$(ssh-keygen -l -f "$file" 2>/dev/null | awk '{print $4}' || echo "unknown")
            SSH_KEYS+=("$key_name ($key_type)")
        fi
    done < <(find "$HOME/.ssh" -name "*.pub" -print0)
fi

if [ ${#SSH_KEYS[@]} -eq 0 ]; then
    gum style --foreground 196 "❌ No SSH public keys found in ~/.ssh/"
    gum style --foreground 250 "Please generate an SSH key first:"
    gum style --foreground 250 "  ssh-keygen -t ed25519 -C \"your-email@example.com\""
    exit 1
fi

SSH_KEYS+=("Generate new key")

SELECTED_KEY=$(gum choose --header "Select SSH key for personal VPS access:" "${SSH_KEYS[@]}")

if [ "$SELECTED_KEY" = "Generate new key" ]; then
    gum style --foreground 250 "Generating new SSH key for personal use..."
    PERSONAL_KEY_PATH="$HOME/.ssh/vps-personal-$(date +%s)"
    ssh-keygen -t ed25519 -f "$PERSONAL_KEY_PATH" -C "vps-personal-$(date +%s)"
    USER_SSH_PUBLIC_KEY=$(cat "$PERSONAL_KEY_PATH.pub")
    gum style --foreground 46 "✅ New personal SSH key generated: $(basename $PERSONAL_KEY_PATH)"
else
    # Extract key name from selection
    KEY_NAME=$(echo "$SELECTED_KEY" | sed 's/ (.*//')
    USER_SSH_PUBLIC_KEY=$(cat "$HOME/.ssh/$KEY_NAME.pub")
    gum style --foreground 46 "✅ Selected personal SSH key: $KEY_NAME"
fi

# Generate GitHub Actions SSH key
echo
gum style --foreground 99 --bold "🔑 Generating GitHub Actions SSH key..."
gum style --foreground 250 "This key will be used for automated deployments."

SSH_KEY_PATH="/tmp/vps-github-actions-key"
if [ -f "$SSH_KEY_PATH" ]; then
    if gum confirm "GitHub Actions SSH key already exists. Regenerate?"; then
        rm -f "$SSH_KEY_PATH" "$SSH_KEY_PATH.pub"
    fi
fi

if [ ! -f "$SSH_KEY_PATH" ]; then
    gum spin --spinner dot --title "Generating GitHub Actions SSH key pair..." -- ssh-keygen -t ed25519 -f "$SSH_KEY_PATH" -N "" -C "vps-github-actions-key-$(date +%s)"
    gum style --foreground 46 "✅ GitHub Actions SSH key generated"
fi

GITHUB_ACTIONS_SSH_PUBLIC_KEY=$(cat "$SSH_KEY_PATH.pub")
SSH_PRIVATE_KEY=$(cat "$SSH_KEY_PATH")

# Generate Grafana password
GRAFANA_PASSWORD=$(openssl rand -base64 32)
gum style --foreground 46 "✅ Generated Grafana admin password"

# Replace placeholders in files
echo
gum style --foreground 99 --bold "📝 Updating configuration files..."

# Find all non-markdown files and replace placeholders
find . -maxdepth 1 -type f ! -name "setup.sh" | while read file; do
    if grep -q "YOUR_" "$file"; then
        gum style --foreground 250 "Updating $file"
        sed -i.bak \
            -e "s/YOUR_GITHUB_ORG/$GITHUB_ORG/g" \
            -e "s/YOUR_GITHUB_REPO/$GITHUB_REPO/g" \
            -e "s/YOUR_EMAIL/$EMAIL/g" \
            -e "s/YOUR_DOMAIN/$DOMAIN/g" \
            -e "s|YOUR_SSH_PUBLIC_KEY|$USER_SSH_PUBLIC_KEY|g" \
            -e "s|YOUR_GITHUB_ACTION_SSH_PUBLIC_KEY|$GITHUB_ACTIONS_SSH_PUBLIC_KEY|g" \
            -e "s/TS_KEY_GOES_HERE/$TS_AUTH_KEY/g" \
            -e "s/YOUR_VPS_IP/$VPS_IP/g" \
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

# Setup complete - now provide manual instructions
echo
gum style \
    --border double \
    --margin "1" \
    --padding "1 2" \
    --border-foreground 46 \
    --foreground 46 \
    --bold \
    "🎉 Setup Phase Complete!" \
    "" \
    "✅ What was completed:" \
    "• Selected/generated personal SSH key for VPS access" \
    "• Generated GitHub Actions SSH key for automated deployments" \
    "• Updated configuration files with your settings:" \
    "  - Domain: $DOMAIN" \
    "  - Email: $EMAIL" \
    "  - Personal and GitHub Actions SSH keys configured" \
    "• Uploaded GitHub Actions secrets:" \
    "  - VPS_IP" \
    "  - VPS_SSH_PRIVATE_KEY" \
    "  - GRAFANA_ADMIN_PASSWORD" \
    "  - TS_OAUTH_CLIENT_ID" \
    "  - TS_OAUTH_SECRET" \
    "• Verified domain DNS and SSH connectivity"

echo
gum style --foreground 212 "Grafana password: $GRAFANA_PASSWORD"
echo

echo
gum style --foreground 46 "Ready for manual steps! 🚀"

# Clean up public key
rm -f "$SSH_KEY_PATH.pub"
