# VPS with NixOS

This template sets up a production-ready VPS with NixOS, complete with infrastructure as code, automated deployment, and a comprehensive monitoring stack.

Rather than running something like Coolify, you can just use this template to start your own setup with sensible, dumb, fundamentals.

## ✨ Features

- **NixOS**: It's a very different OS, it's one thats entirely defined by a declarative configuration file, which makes it super simple to deploy and manage - no poking around in the terminal.
- **Grafana Stack**: Grafana, Prometheus, Loki, and Tempo
- **Secure Services**: Hardened SSH, Fail2ban, and firewall configuration.
- **Tailscale Integration**: Secure VPN access to your VPS, no public access to your services.
- **Zero-Downtime Deployment**: Docker rollout, no downtime.

## 🚀 Quick Start

### 📋 What You'll Need

- A fresh VPS (any provider, Ubuntu recommended)
  - Note, you MUST enable the VPS provider firewall for 22 and 443, once you're setup with tailscale you can remove 22 - otherwise docker may expose your services to the public internet.
- A domain name pointing to your VPS
  - This can be a subdomain of a larger domain, or a completely separate domain.
- Tailscale account for secure access
  - You'll also need a "tag" setup e.g. "tag:my-vps", allowing us to restrict Github Actions to only access this VPS, and the VPS to not access your network.
- GitHub CLI and Gum installed locally (for the setup script)

### Prerequisites

1. **Clone this repository**:

   ```bash
   git clone https://github.com/YOUR_GITHUB_ORG/YOUR_GITHUB_REPO.git
   cd YOUR_GITHUB_REPO
   ```

2. **Install required tools**:

   ```bash
   # macOS
   brew install gum gh

   # Or visit the installation pages:
   # Gum: https://github.com/charmbracelet/gum#installation
   # GitHub CLI: https://cli.github.com/
   ```

3. **Authenticate with GitHub**:

   ```bash
   gh auth login
   ```

4. **Prepare your infrastructure**:
   - Get a fresh VPS (Ubuntu recommended) - try [Hetzner](https://www.hetzner.com/)
   - Register a domain and point it to your VPS IP
   - Create a [Tailscale account](https://tailscale.com/)
   - Make sure you can SSH to your VPS as root

### Tailscale ACLs

In tailscale, you'll need to create an ACL to allow your VPS to be accessed by your devices - and importantly this will prevent the VPS from accessing your network.

```json
{
  "acls": [
    // Allow you full access
    {
      "action": "accept",
      "src": ["YOUR_EMAIL"],
      "dst": ["*:*"]
    },

    // Allow your-vps-tagged devices (e.g. GH/GI runners) to reach only the VPS
    {
      "action": "accept",
      "src": ["tag:your-vps"],
      "dst": ["YOUR_TAILSCALE_VPS_IP:*"]
    }
  ],

  "tagOwners": {
    "tag:your-vps": ["YOUR_EMAIL"]
  }
}
```

### Setup Process

#### Step 1: Run Automated Setup

Run the setup script and follow the interactive prompts:

```bash
./setup.sh
```

The script will automatically:

- ✅ Auto-detect your GitHub repository
- ✅ Collect your email, domain, and VPS IP
- ✅ Verify DNS resolution and VPS connectivity
- ✅ Guide you through Tailscale OAuth setup (with 'auth-keys' permission and tagging)
- ✅ Generate SSH keys and Grafana passwords
- ✅ Upload all GitHub Actions secrets
- ✅ Update configuration files with your settings

#### Step 2: Manual VPS Configuration

After the setup script completes, you'll need to manually complete these steps:

1. **Install NixOS on your VPS** (⚠️ **DESTRUCTIVE** - will wipe your VPS):

Run the following command on your VPS:

```bash
curl https://raw.githubusercontent.com/elitak/nixos-infect/master/nixos-infect | \
PROVIDER=hetznercloud NIX_CHANNEL=nixos-25.05 bash 2>&1 | tee /tmp/infect.log
```

2. **Wait for reboot** (1-5 minutes)

You'll know if worked if when you ssh back in the root@vps-0 prompt appears red and non-ubuntu.

3. **Download NixOS configuration files**:

   ```bash
   scp root@YOUR_VPS_IP:/etc/nixos/hardware-configuration.nix ./infra/vps-0/hardware-configuration.nix
   scp root@YOUR_VPS_IP:/etc/nixos/networking.nix ./infra/vps-0/networking.nix
   ```

4. **Deploy your configuration**:

   ```bash
   make deploy
   ```

5. **Commit and push changes**:
   ```bash
   git add .
   git commit -m "feat: add VPS hardware configs and deploy"
   git push origin main
   ```

### Access Your Services

It may take a while to deploy the docker stack, so check the Actions tab for deployment status.

- **Your app**: `https://your-domain.com`
- **Grafana**: `https://grafana.your-domain.com` (use the password provided by setup script, or if you've lost it, find it inside the VPS in `~/docker/.env`)
- **Traefik**: `tailsale-ip:8080` used to check the health of the load balancing/cert provisioning
