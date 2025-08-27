# Example production NixOS configuration with TLS and multiple instances
{ config, pkgs, ... }:
{
  imports = [
    # inputs.pogocache.nixosModules.default
  ];

  services.pogocache.servers = {
    # Main production cache
    "main" = {
      enable = true;
      bind = "0.0.0.0";
      port = 9401;
      openFirewall = true;
      
      # High performance settings
      threads = 16;
      maxMemory = "8GB";
      maxConnections = 4096;
      
      # Security
      auth.enable = true;
      auth.passwordFile = "/run/secrets/pogocache-main-password";
      
      # TLS configuration
      tls.enable = true;
      tls.port = 9402;
      tls.certFile = "/etc/ssl/certs/pogocache.crt";
      tls.keyFile = "/etc/ssl/private/pogocache.key";
      tls.caCertFile = "/etc/ssl/certs/ca.crt";
      
      # Persistence for durability
      persistence.enable = true;
      persistence.file = "/var/lib/pogocache/main.dat";
      
      # Production tuning
      advanced = {
        shards = 4096;
        backlog = 2048;
        queueSize = 256;
        reusePort = true;
        uring = true;
        loadFactor = 80;
        compareAndStore = true;
      };
    };
    
    # Session cache (no persistence, unix socket only)
    "sessions" = {
      enable = true;
      port = 0; # Disable TCP
      unixSocket = "/run/pogocache/sessions.sock";
      unixSocketPerm = 660;
      
      # Optimized for sessions
      maxMemory = "1GB";
      evict = true;
      
      # Fast settings
      advanced = {
        shards = 512;
        keySixpack = false; # Disable compression for speed
        tcpNoDelay = true;
        quickAck = true;
      };
    };
    
    # Development cache (minimal security)
    "dev" = {
      enable = true;
      bind = "127.0.0.1";
      port = 9403;
      
      # Development settings
      verbosity = 2; # Verbose logging
      maxMemory = "512MB";
      threads = 2;
      
      # No auth for development
      auth.enable = false;
      
      # Basic settings
      advanced = {
        shards = 128;
        compareAndStore = true; # Enable for testing
      };
    };
  };

  # Systemd timer for periodic backup of main cache
  systemd.services."pogocache-backup" = {
    description = "Backup Pogocache main instance";
    serviceConfig = {
      Type = "oneshot";
      User = "pogocache-main";
      ExecStart = pkgs.writeShellScript "backup-pogocache" ''
        # Use pogocache SAVE command to create snapshot
        echo "SAVE" | ''${pkgs.socat}/bin/socat - UNIX-CONNECT:/run/pogocache-main/pogocache-main.sock
        
        # Copy the dump file with timestamp
        cp /var/lib/pogocache-main/main.dat /var/backups/pogocache-main-$(date +%Y%m%d-%H%M%S).dat
        
        # Keep only last 7 days of backups
        find /var/backups -name "pogocache-main-*.dat" -mtime +7 -delete
      '';
    };
  };

  systemd.timers."pogocache-backup" = {
    description = "Backup Pogocache main instance daily";
    wantedBy = [ "timers.target" ];
    timerConfig = {
      OnCalendar = "daily";
      Persistent = true;
    };
  };

  # Create backup directory
  systemd.tmpfiles.rules = [
    "d /var/backups 0755 root root -"
  ];

  # Monitoring with Prometheus (optional)
  services.prometheus.exporters.node = {
    enable = true;
    enabledCollectors = [ "systemd" ];
  };

  # Log rotation for pogocache logs
  services.logrotate.extraConfig = ''
    /var/log/pogocache/*.log {
      daily
      missingok
      rotate 30
      compress
      delaycompress
      copytruncate
      notifempty
      create 644 root root
    }
  '';
}