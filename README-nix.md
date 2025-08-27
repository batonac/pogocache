# Pogocache Nix Flake and NixOS Module

This flake provides:
1. A Nix package for building pogocache
2. A NixOS module for running pogocache as a systemd service

## Usage

### Building the package

```bash
nix build
```

### Using the NixOS module

Add to your NixOS configuration:

```nix
{
  inputs.pogocache.url = "github:batonac/pogocache";
  
  outputs = { self, nixpkgs, pogocache }: {
    nixosConfigurations.myhost = nixpkgs.lib.nixosSystem {
      system = "x86_64-linux";
      modules = [
        pogocache.nixosModules.default
        {
          services.pogocache.servers."" = {
            enable = true;
            bind = "127.0.0.1";
            port = 9401;
            maxMemory = "80%";
            auth.enable = true;
            auth.passwordFile = "/run/secrets/pogocache-password";
          };
        }
      ];
    };
  };
}
```

### Configuration Examples

#### Basic setup with default options:
```nix
services.pogocache.servers."" = {
  enable = true;
};
```

#### Production setup with authentication and TLS:
```nix
services.pogocache.servers."" = {
  enable = true;
  bind = "0.0.0.0";
  port = 9401;
  openFirewall = true;
  
  # Performance tuning
  threads = 8;
  maxMemory = "4GB";
  maxConnections = 2048;
  
  # Security
  auth.enable = true;
  auth.passwordFile = "/run/secrets/pogocache-password";
  
  tls.enable = true;
  tls.port = 9402;
  tls.certFile = "/path/to/cert.pem";
  tls.keyFile = "/path/to/key.pem";
  tls.caCertFile = "/path/to/ca.pem";
  
  # Persistence
  persistence.enable = true;
  persistence.file = "/var/lib/pogocache/dump.dat";
  
  # Advanced options
  advanced.shards = 1024;
  advanced.uring = true;
  advanced.compareAndStore = true;
};
```

#### Multiple instances:
```nix
services.pogocache.servers = {
  # Main instance
  "" = {
    enable = true;
    port = 9401;
  };
  
  # Cache for application A
  "app-a" = {
    enable = true;
    port = 9402;
    maxMemory = "2GB";
    persistence.enable = true;
    persistence.file = "/var/lib/pogocache/app-a.dat";
  };
  
  # Cache for application B
  "app-b" = {
    enable = true;
    port = 9403;
    maxMemory = "1GB";
    unixSocket = "/run/pogocache/app-b.sock";
  };
};
```

## Configuration Options

### Basic Options
- `bind`: IP address to bind to (default: "127.0.0.1")
- `port`: TCP port (default: 9401 for main instance, 0 for named instances)
- `unixSocket`: Unix socket path (default: auto-generated)
- `verbosity`: Logging verbosity level 0-3 (default: 0)

### Performance Options
- `threads`: Number of threads (default: 0 = auto-detect)
- `maxMemory`: Memory limit as percentage or absolute value (default: "80%")
- `evict`: Enable key eviction when memory limit reached (default: true)
- `maxConnections`: Maximum client connections (default: 1024)

### Persistence Options
- `persistence.enable`: Enable persistence to disk (default: false)
- `persistence.file`: Path to persistence file

### Security Options
- `auth.enable`: Enable authentication (default: false)
- `auth.password`: Password (plain text, not recommended)
- `auth.passwordFile`: Path to file containing password (recommended)
- `tls.enable`: Enable TLS (default: false)
- `tls.port`: TLS port (default: 9402)
- `tls.certFile`: Path to TLS certificate
- `tls.keyFile`: Path to TLS private key
- `tls.caCertFile`: Path to CA certificate (optional)

### Advanced Options
- `advanced.shards`: Number of hash map shards (default: 512)
- `advanced.backlog`: TCP accept backlog (default: 1024)
- `advanced.queueSize`: Event queue size (default: 128)
- `advanced.reusePort`: Enable SO_REUSEPORT (default: false)
- `advanced.tcpNoDelay`: Disable Nagle's algorithm (default: true)
- `advanced.quickAck`: Enable TCP quick ACK (default: false)
- `advanced.uring`: Enable io_uring support (default: true)
- `advanced.loadFactor`: Hash map load factor 55-95% (default: 75)
- `advanced.keySixpack`: Enable sixpack key compression (default: true)
- `advanced.compareAndStore`: Enable CAS functionality (default: false)

## Security

The NixOS module includes security hardening:
- Runs as dedicated user with minimal privileges
- Uses systemd security features like `ProtectSystem`, `NoNewPrivileges`
- Restricts system calls and capabilities
- Uses private /tmp and protects sensitive directories

## Compatibility

This module is designed to be compatible with the official NixOS Redis module patterns and conventions.