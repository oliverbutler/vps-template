{ config, lib, pkgs, ... }: {
  imports = [
    ./hardware-configuration.nix
    ./networking.nix # generated at runtime by nixos-infect
  ];

  boot.tmp.cleanOnBoot = true;
  zramSwap.enable = true;
  networking.hostName = "vps-0";
  networking.domain = "";
  
  # Security settings
  services.openssh = {
    enable = true;
    allowSFTP = false;
    ports = [22];

    # https://infosec.mozilla.org/guidelines/openssh#modern-openssh-67
    settings = {
      LogLevel = "VERBOSE";
      PermitRootLogin = "prohibit-password";
      PasswordAuthentication = false;
      KbdInteractiveAuthentication = true;

      KexAlgorithms = [
        "curve25519-sha256@libssh.org"
        "ecdh-sha2-nistp521"
        "ecdh-sha2-nistp384"
        "ecdh-sha2-nistp256"
        "diffie-hellman-group-exchange-sha256"
      ];
      Ciphers = [
        "chacha20-poly1305@openssh.com"
        "aes256-gcm@openssh.com"
        "aes128-gcm@openssh.com"
        "aes256-ctr"
        "aes192-ctr"
        "aes128-ctr"
      ];
      Macs = [
        "hmac-sha2-512-etm@openssh.com"
        "hmac-sha2-256-etm@openssh.com"
        "umac-128-etm@openssh.com"
        "hmac-sha2-512"
        "hmac-sha2-256"
        "umac-128@openssh.com"
      ];
    };

    extraConfig = ''
      ClientAliveCountMax 0
      ClientAliveInterval 300

      AllowTcpForwarding no
      AllowAgentForwarding no
      MaxAuthTries 3
      MaxSessions 2
      TCPKeepAlive no
    '';

  };

  services.fail2ban = {
    enable = true;
    maxretry = 10;
    bantime-increment.enable = true;
  };
  
  # System packages
  environment.systemPackages = with pkgs; [
    curl
    gitMinimal
    btop
    vim
    tailscale
    lazydocker
  ];
  
  # Docker setup
  virtualisation.docker = {
    enable = true;
    daemon.settings = {
      log-driver = "json-file";
      log-opts = {
        max-size = "10m";
        max-file = "3";
      };
    };
  };
  
  # Tailscale setup
  services.tailscale.enable = true;
  
  # Automatic Tailscale connection
  systemd.services.tailscale-autoconnect = {
    description = "Automatic connection to Tailscale";
    after = [ "network-pre.target" "tailscale.service" ];
    wants = [ "network-pre.target" "tailscale.service" ];
    wantedBy = [ "multi-user.target" ];
    serviceConfig.Type = "oneshot";
    script = with pkgs; ''
      # wait for tailscaled to settle
      sleep 2

      # check if we are already authenticated to tailscale
      status="$(${tailscale}/bin/tailscale status -json | ${jq}/bin/jq -r .BackendState)"
      if [ $status = "Running" ]; then # if so, then do nothing
        exit 0
      fi

      # otherwise authenticate with tailscale (generated at https://login.tailscale.com/admin/settings/keys?refreshed=true)
      ${tailscale}/bin/tailscale up -authkey TS_KEY_GOES_HERE
    '';
  };

  # Automatic docker-rollout installation for user
  systemd.services.docker-rollout-setup = {
    description = "Setup docker-rollout CLI plugin for user";
    after = [ "multi-user.target" ];
    wants = [ "multi-user.target" ];
    wantedBy = [ "multi-user.target" ];
    serviceConfig = {
      Type = "oneshot";
      RemainAfterExit = true;
      User = "user";
    };
    script = with pkgs; ''
      # Create Docker CLI plugins directory
      mkdir -p /home/user/.docker/cli-plugins
      
      # Check if docker-rollout already exists
      if [ -f /home/user/.docker/cli-plugins/docker-rollout ]; then
        echo "docker-rollout already installed"
        exit 0
      fi
      
      # Download docker-rollout
      ${curl}/bin/curl -L https://raw.githubusercontent.com/wowu/docker-rollout/main/docker-rollout \
        -o /home/user/.docker/cli-plugins/docker-rollout
      
      # Make executable
      chmod +x /home/user/.docker/cli-plugins/docker-rollout
      
      echo "docker-rollout installed successfully"
    '';
  };
  
  # Firewall configuration not present, was pointless as Docker is able to holepunch through our firewall - so using Hetzner's firewall instead
  
  # User accounts
  users.users.root.openssh.authorizedKeys.keys = [
    "YOUR_SSH_KEY"
  ];
  
  users.users.user = {
    isNormalUser = true;
    extraGroups = [ "wheel" "docker" ];
    openssh.authorizedKeys.keys = [
      "YOUR_SSH_KEY"
    ];
  };
  
  # For system stability
  system.stateVersion = "25.05";
}
