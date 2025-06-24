# VPS with NixOS

This sets up a VPS ready to build your app in with NixOS, IAC fundamentals and a basic monitoring stack.

## Requirements

- A brand new VPS e.g. Hetzner
- A Tailscale account
- An SSH key from your machine for access
- A domain pointing to the VPS's IP address

## Guide

### 1. Create a new VPS

I recommend Hetzner, spin up a VPS with any spec, make it Ubuntu and give it an SSH okay

SSH into the box, via the public IP provided via hetzner

```bash
curl https://raw.githubusercontent.com/elitak/nixos-infect/master/nixos-infect | PROVIDER=hetznercloud NIX_CHANNEL=nixos-25.05 bash 2>&1 | tee /tmp/infect.log
```

This will convert the VPS to nixos and reboot

### 2. Prepare the repo

Replace the variables with your own, here is a command to replace them all:

- `YOUR_GITHUB_ORG` - The organization name for the container registry e.g. `your-github-org`
- `YOUR_GITHUB_REPO` - The repository name for the container registry e.g. `my-repo`
- `YOUR_EMAIL` - The email for the ACME certificate e.g. `your@email.com`
- `YOUR_DOMAIN` - The domain name for the VPS e.g. `your-domain.com`
- `YOUR_SSH_PUBLIC_KEY` - Your PUBLIC SSH key e.g. `ssh-ed25519 AAAAC3NzaC...`

### 3. Prepare your Github Actions secrets

Before doing this, you'll need to generate a new SSH key pair, and add the private key to your Github Actions secrets.

run the following command to generate a new SSH key pair

```bash
ssh-keygen -t ed25519 -f ./vps-key
```

Now make the following secrets in your Github Actions:

- `VPS_IP` - The IP address of the VPS e.g. `100.124.231.64`
- `VPS_SSH_PRIVATE_KEY` - Your PRIVATE SSH key e.g. `ssh-ed25519 AAAAC3NzaC...`
- `GRAFANA_ADMIN_PASSWORD` - The password for the Grafana admin user e.g. `your-password`, maybe generate one with `openssl rand -base64 32`

### 4. Download the NixOS config

These two files will be downloaded to your repo, and should be commited.

```bash
scp -r root@VPS_IP:/etc/nixos/hardware-configuration.nix ./infra/vps-0/hardware-configuration.nix
scp -r root@VPS_IP:/etc/nixos/networking.nix ./infra/vps-0/networking.nix
```

### 5. Deploy the NixOS config

You should now be able to run `make deploy` to deploy the NixOS config to the VPS.

This will set up the whole VPS with everything you need.
