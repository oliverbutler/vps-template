# VPS with NixOS

This template sets up a production-ready VPS with NixOS, complete with infrastructure as code, automated deployment, and a comprehensive monitoring stack.

## ✨ Features

- **Automated Setup**: One-command setup script handles everything
- **NixOS Configuration**: Declarative, reproducible system configuration
- **GitHub Actions**: Automated CI/CD pipeline
- **Monitoring Stack**: Grafana, Prometheus, Loki, and Tempo
- **Secure by Default**: Hardened SSH, Fail2ban, and firewall configuration
- **Tailscale Integration**: Secure VPN access to your VPS
- **Docker Support**: Container orchestration with automatic rollouts

## 🚀 Quick Start

### Prerequisites

1. **Clone this repository**:

   ```bash
   git clone https://github.com/YOUR_USERNAME/vps-template.git
   cd vps-template
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

### Automated Setup

Run the setup script and follow the interactive prompts:

```bash
./setup.sh
```

The script will:

- ✅ Auto-detect your GitHub repository
- ✅ Collect your email, domain, and VPS IP
- ✅ Verify DNS resolution and VPS connectivity
- ✅ Guide you through Tailscale OAuth setup
- ✅ Generate SSH keys and Grafana passwords
- ✅ Upload all GitHub Actions secrets
- ✅ Replace configuration placeholders
- ✅ Install NixOS on your VPS (with confirmation)
- ✅ Deploy your custom configuration
- ✅ Commit and push changes

### Access Your Services

After setup completes:

- **Your app**: `https://your-domain.com`
- **Grafana**: `https://grafana.your-domain.com`
- **GitHub Actions**: Check the Actions tab for deployment status

## 📋 What You'll Need

- A fresh VPS (any provider, Ubuntu recommended)
- A domain name pointing to your VPS
- Tailscale account for secure access
- GitHub CLI and Gum installed locally

## 🔧 Manual Setup (Advanced Users)

<details>
<summary>Click to expand manual setup instructions</summary>

If you prefer to set things up manually or need to troubleshoot:

### 1. Create a VPS

Spin up a VPS with Ubuntu and SSH access. For NixOS installation:

```bash
curl https://raw.githubusercontent.com/elitak/nixos-infect/master/nixos-infect | PROVIDER=hetznercloud NIX_CHANNEL=nixos-25.05 bash 2>&1 | tee /tmp/infect.log
```

### 2. Configure Variables

Replace these placeholders in the configuration files:

- `YOUR_GITHUB_ORG` - Your GitHub organization/username
- `YOUR_GITHUB_REPO` - Your repository name
- `YOUR_EMAIL` - Email for ACME certificates
- `YOUR_DOMAIN` - Your domain name
- `YOUR_SSH_PUBLIC_KEY` - Your SSH public key

### 3. GitHub Actions Secrets

Create these secrets in your GitHub repository:

- `VPS_IP` - Your VPS IP address
- `VPS_SSH_PRIVATE_KEY` - SSH private key for deployment
- `GRAFANA_ADMIN_PASSWORD` - Grafana admin password
- `TS_OAUTH_CLIENT_ID` - Tailscale OAuth client ID
- `TS_OAUTH_SECRET` - Tailscale OAuth secret

### 4. Deploy Configuration

```bash
# Download NixOS configs
scp root@VPS_IP:/etc/nixos/hardware-configuration.nix ./infra/vps-0/
scp root@VPS_IP:/etc/nixos/networking.nix ./infra/vps-0/

# Deploy
make deploy
```

</details>

## 🏗️ Architecture

- **VPS**: NixOS with hardened security configuration
- **Containers**: Docker with automatic rollout deployments
- **Monitoring**: Full observability stack (metrics, logs, traces)
- **Networking**: Traefik reverse proxy with automatic HTTPS
- **VPN**: Tailscale for secure access

## 🔐 Security Features

- Hardened SSH configuration (key-based auth only)
- Fail2ban for intrusion detection
- Automatic security updates
- Firewall configuration
- Secure container defaults

## 📊 Monitoring

Access your monitoring dashboard at `https://grafana.your-domain.com`:

- Application metrics and performance
- System resource usage
- Log aggregation and search
- Distributed tracing
- Alerting and notifications

## 🚀 Deployment

Every push to `main` triggers:

1. Automated testing
2. Docker image build and push
3. Zero-downtime deployment to VPS
4. Health checks and rollback if needed

## 🤝 Contributing

1. Fork the repository
2. Create a feature branch
3. Make your changes
4. Test thoroughly
5. Submit a pull request

## 📝 License

This project is licensed under the MIT License - see the LICENSE file for details.

---

**Happy coding!** 🎉 If you run into issues, check the GitHub Actions logs or open an issue.
