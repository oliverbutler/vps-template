#!/bin/bash
set -e

SERVER_IP="vps-0"
SSH_USER="root"
CONFIG_DIR="infra/vps-0"

# Ensure we're in the repo root
REPO_ROOT=$(git rev-parse --show-toplevel 2>/dev/null || pwd)
cd "$REPO_ROOT"

# Check if configuration files exist
if [ ! -f "$CONFIG_DIR/configuration.nix" ] || [ ! -f "$CONFIG_DIR/networking.nix" ]; then
  echo "Error: Configuration files not found in $CONFIG_DIR"
  exit 1
fi

echo "Cleaning up old configuration on $SERVER_IP..."
ssh "$SSH_USER@$SERVER_IP" "rm -rf /etc/nixos/*"

echo "Copying configuration to $SERVER_IP..."
scp -O -r "$CONFIG_DIR"/* "$SSH_USER@$SERVER_IP:/etc/nixos/"

echo "Rebuilding NixOS on $SERVER_IP..."
ssh "$SSH_USER@$SERVER_IP" "nixos-rebuild switch"

echo "Deployment complete!" 
