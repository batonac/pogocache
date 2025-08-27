# Example NixOS configuration using pogocache
{ config, pkgs, ... }:
{
  # Import the pogocache flake module
  imports = [
    # Assuming pogocache is available as a flake input
    # inputs.pogocache.nixosModules.default
  ];

  # Basic pogocache setup
  services.pogocache.servers."" = {
    enable = true;
    bind = "127.0.0.1";
    port = 9401;
    verbosity = 1; # Enable verbose logging
    
    # Performance settings
    threads = 4;
    maxMemory = "2GB";
    evict = true;
    maxConnections = 1024;
    
    # Enable persistence
    persistence.enable = true;
    persistence.file = "/var/lib/pogocache/dump.dat";
    
    # Security settings
    auth.enable = true;
    auth.passwordFile = "/run/secrets/pogocache-password";
    
    # Advanced tuning
    advanced = {
      shards = 1024;
      loadFactor = 75;
      uring = true;
      tcpNoDelay = true;
      compareAndStore = false;
    };
  };

  # Create the password file (in production, use a secret management solution)
  environment.etc."pogocache-password" = {
    text = "your-secret-password-here";
    mode = "0600";
    user = "pogocache";
    group = "pogocache";
  };
  
  # Use the password file from /etc
  services.pogocache.servers."".auth.passwordFile = "/etc/pogocache-password";
  
  # Optional: Open firewall for external access
  # services.pogocache.servers."".openFirewall = true;
}