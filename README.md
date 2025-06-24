# VPS with NixOS

This template sets up a production-ready VPS with NixOS, complete with infrastructure as code, automated deployment, and a comprehensive monitoring stack.

## ✨ Features

- **Automated Setup**: Setup script handles configuration and secrets
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

After deployment completes:

- **Your app**: `https://your-domain.com`
- **Grafana**: `https://grafana.your-domain.com` (use the password provided by setup script)
- **GitHub Actions**: Check the Actions tab for deployment status

## 📋 What You'll Need

- A fresh VPS (any provider, Ubuntu recommended)
- A domain name pointing to your VPS
- Tailscale account for secure access
- GitHub CLI and Gum installed locally

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
- Scoped Tailscale access with project tagging

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
