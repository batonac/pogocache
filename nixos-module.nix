{ config, lib, pkgs, ... }:

let
  cfg = config.services.pogocache;

  pogocacheName = name: "pogocache" + lib.optionalString (name != "") ("-" + name);
  enabledServers = lib.filterAttrs (name: conf: conf.enable) config.services.pogocache.servers;

  boolToYesNo = value: if value then "yes" else "no";

  # Generate command line arguments for pogocache
  mkArgs = serverCfg: [
    # Basic options
    "--host" serverCfg.bind
    "--port" (toString serverCfg.port)
  ] ++ lib.optionals (serverCfg.unixSocket != null) [
    "--unixsock" serverCfg.unixSocket
  ] ++ lib.optionals (serverCfg.verbosity > 0) [
    (lib.concatStrings (lib.genList (_: "-v") serverCfg.verbosity))
  ] ++ [
    # Performance options
    "--threads" (toString serverCfg.threads)
    "--maxmemory" serverCfg.maxMemory
    "--evict" (boolToYesNo serverCfg.evict)
    "--maxconns" (toString serverCfg.maxConnections)
  ] ++ lib.optionals (serverCfg.persistence.enable) [
    "--persist" serverCfg.persistence.file
  ] ++ [
    # Security options
  ] ++ lib.optionals (serverCfg.auth.enable && serverCfg.auth.password != null) [
    "--auth" serverCfg.auth.password
  ] ++ lib.optionals (serverCfg.tls.enable) [
    "--tlsport" (toString serverCfg.tls.port)
    "--tlscert" serverCfg.tls.certFile
    "--tlskey" serverCfg.tls.keyFile
  ] ++ lib.optionals (serverCfg.tls.enable && serverCfg.tls.caCertFile != null) [
    "--tlscacert" serverCfg.tls.caCertFile
  ] ++ [
    # Advanced options
    "--shards" (toString serverCfg.advanced.shards)
    "--backlog" (toString serverCfg.advanced.backlog)
    "--queuesize" (toString serverCfg.advanced.queueSize)
    "--reuseport" (boolToYesNo serverCfg.advanced.reusePort)
    "--tcpnodelay" (boolToYesNo serverCfg.advanced.tcpNoDelay)
    "--quickack" (boolToYesNo serverCfg.advanced.quickAck)
    "--uring" (boolToYesNo serverCfg.advanced.uring)
    "--loadfactor" (toString serverCfg.advanced.loadFactor)
    "--keysixpack" (boolToYesNo serverCfg.advanced.keySixpack)
    "--cas" (boolToYesNo serverCfg.advanced.compareAndStore)
  ];

in
{
  options = {
    services.pogocache = {
      package = lib.mkPackageOption pkgs "pogocache" { };

      servers = lib.mkOption {
        type = with lib.types; attrsOf (submodule ({ config, name, ... }: {
          options = {
            enable = lib.mkEnableOption "Pogocache server";

            user = lib.mkOption {
              type = types.str;
              default = pogocacheName name;
              defaultText = lib.literalExpression ''
                if name == "" then "pogocache" else "pogocache-''${name}"
              '';
              description = ''
                User account under which this instance of pogocache runs.
                
                ::: {.note}
                If left as the default value this user will automatically be
                created on system activation, otherwise you are responsible for
                ensuring the user exists before the pogocache service starts.
                :::
              '';
            };

            group = lib.mkOption {
              type = types.str;
              default = config.user;
              defaultText = lib.literalExpression "config.user";
              description = ''
                Group account under which this instance of pogocache runs.
                
                ::: {.note}
                If left as the default value this group will automatically be
                created on system activation, otherwise you are responsible for
                ensuring the group exists before the pogocache service starts.
                :::
              '';
            };

            # Basic options
            bind = lib.mkOption {
              type = types.str;
              default = "127.0.0.1";
              description = "The IP address on which to listen for connections.";
            };

            port = lib.mkOption {
              type = types.port;
              default = if name == "" then 9401 else 0;
              defaultText = lib.literalExpression ''if name == "" then 9401 else 0'';
              description = ''
                The TCP port to accept connections.
                If port 0 is specified Pogocache will not listen on a TCP socket.
              '';
            };

            openFirewall = lib.mkOption {
              type = types.bool;
              default = false;
              description = ''
                Whether to open the port in the firewall for this server.
              '';
            };

            unixSocket = lib.mkOption {
              type = with types; nullOr path;
              default = if name == "" then "/run/pogocache/pogocache.sock" else "/run/pogocache/pogocache-${name}.sock";
              defaultText = lib.literalExpression ''
                if name == "" then "/run/pogocache/pogocache.sock" else "/run/pogocache/pogocache-''${name}.sock"
              '';
              description = "Path to the unix socket file. Set to null to disable unix socket.";
            };

            unixSocketPerm = lib.mkOption {
              type = types.int;
              default = 750;
              description = "Change permissions for the unix socket.";
            };

            verbosity = lib.mkOption {
              type = types.ints.between 0 3;
              default = 0;
              description = ''
                Verbosity level for logging.
                0 = normal, 1 = verbose, 2 = very verbose, 3 = extremely verbose.
              '';
            };

            # Performance options
            threads = lib.mkOption {
              type = types.ints.positive;
              default = 0; # 0 means auto-detect based on CPU cores
              description = ''
                Number of threads to use. 0 means auto-detect based on CPU cores.
              '';
            };

            maxMemory = lib.mkOption {
              type = types.str;
              default = "80%";
              description = ''
                Maximum memory usage. Can be specified as percentage (e.g., "80%") 
                or absolute value (e.g., "1GB", "512MB").
              '';
            };

            evict = lib.mkOption {
              type = types.bool;
              default = true;
              description = "Whether to evict keys when maxMemory is reached.";
            };

            maxConnections = lib.mkOption {
              type = types.ints.positive;
              default = 1024;
              description = "Maximum number of client connections.";
            };

            # Persistence options
            persistence = {
              enable = lib.mkOption {
                type = types.bool;
                default = false;
                description = "Whether to enable persistence to disk.";
              };

              file = lib.mkOption {
                type = types.path;
                default = if name == "" then "/var/lib/pogocache/dump.dat" else "/var/lib/pogocache/dump-${name}.dat";
                defaultText = lib.literalExpression ''
                  if name == "" then "/var/lib/pogocache/dump.dat" else "/var/lib/pogocache/dump-''${name}.dat"
                '';
                description = "Path to the persistence file.";
              };
            };

            # Security options
            auth = {
              enable = lib.mkOption {
                type = types.bool;
                default = false;
                description = "Whether to enable authentication.";
              };

              password = lib.mkOption {
                type = with types; nullOr str;
                default = null;
                description = ''
                  Password for authentication (STORED PLAIN TEXT, WORLD-READABLE IN NIX STORE).
                  Use passwordFile to store it outside of the nix store in a dedicated file.
                '';
              };

              passwordFile = lib.mkOption {
                type = with types; nullOr path;
                default = null;
                description = "File containing the password for authentication.";
              };
            };

            # TLS options
            tls = {
              enable = lib.mkOption {
                type = types.bool;
                default = false;
                description = "Whether to enable TLS support.";
              };

              port = lib.mkOption {
                type = types.port;
                default = 9402;
                description = "Port for TLS connections.";
              };

              certFile = lib.mkOption {
                type = with types; nullOr path;
                default = null;
                description = "Path to the TLS certificate file.";
              };

              keyFile = lib.mkOption {
                type = with types; nullOr path;
                default = null;
                description = "Path to the TLS private key file.";
              };

              caCertFile = lib.mkOption {
                type = with types; nullOr path;
                default = null;
                description = "Path to the TLS CA certificate file.";
              };
            };

            # Advanced options
            advanced = {
              shards = lib.mkOption {
                type = types.ints.positive;
                default = 512;
                description = "Number of shards for the hash map.";
              };

              backlog = lib.mkOption {
                type = types.ints.positive;
                default = 1024;
                description = "Accept backlog for the listening socket.";
              };

              queueSize = lib.mkOption {
                type = types.ints.positive;
                default = 128;
                description = "Event queue size.";
              };

              reusePort = lib.mkOption {
                type = types.bool;
                default = false;
                description = "Whether to enable SO_REUSEPORT for the listening socket.";
              };

              tcpNoDelay = lib.mkOption {
                type = types.bool;
                default = true;
                description = "Whether to disable Nagle's algorithm (enable TCP_NODELAY).";
              };

              quickAck = lib.mkOption {
                type = types.bool;
                default = false;
                description = "Whether to enable TCP quick ACK (Linux only).";
              };

              uring = lib.mkOption {
                type = types.bool;
                default = true;
                description = "Whether to enable io_uring support (Linux only).";
              };

              loadFactor = lib.mkOption {
                type = types.ints.between 55 95;
                default = 75;
                description = "Hash map load factor percentage.";
              };

              keySixpack = lib.mkOption {
                type = types.bool;
                default = true;
                description = "Whether to enable sixpack compression for keys.";
              };

              compareAndStore = lib.mkOption {
                type = types.bool;
                default = false;
                description = "Whether to enable compare-and-store (CAS) functionality.";
              };
            };
          };
        }));
        default = { };
        description = "Configuration for Pogocache server instances.";
      };
    };
  };

  config = lib.mkIf (enabledServers != { }) {
    users.users = lib.mapAttrs'
      (name: serverCfg: lib.nameValuePair serverCfg.user {
        description = "Pogocache server user";
        isSystemUser = true;
        group = serverCfg.group;
        home = "/var/lib/${pogocacheName name}";
        createHome = true;
      })
      enabledServers;

    users.groups = lib.mapAttrs'
      (name: serverCfg: lib.nameValuePair serverCfg.group { })
      enabledServers;

    networking.firewall = lib.mkIf (lib.any (serverCfg: serverCfg.openFirewall) (lib.attrValues enabledServers)) {
      allowedTCPPorts = lib.flatten (
        lib.mapAttrsToList
          (name: serverCfg:
            lib.optionals serverCfg.openFirewall (
              [ serverCfg.port ] ++ lib.optionals serverCfg.tls.enable [ serverCfg.tls.port ]
            )
          )
          enabledServers
      );
    };

    systemd.services = lib.mapAttrs'
      (name: serverCfg:
        let
          serviceName = pogocacheName name;
          runtimeDir = "/run/${serviceName}";
          
          # Build command arguments
          args = mkArgs serverCfg;
            
        in
        lib.nameValuePair serviceName {
          description = "Pogocache server${lib.optionalString (name != "") " (${name})"}";
          wantedBy = [ "multi-user.target" ];
          after = [ "network.target" ];

          serviceConfig = {
            Type = "exec";
            User = serverCfg.user;
            Group = serverCfg.group;
            RuntimeDirectory = serviceName;
            RuntimeDirectoryMode = "0755";
            StateDirectory = serviceName;
            StateDirectoryMode = "0700";
            ExecStart = if serverCfg.auth.enable && serverCfg.auth.passwordFile != null then
              pkgs.writeShellScript "pogocache-start" ''
                AUTH_PASSWORD="$(cat ${lib.escapeShellArg serverCfg.auth.passwordFile})"
                exec ${cfg.package}/bin/pogocache ${lib.escapeShellArgs args} --auth "$AUTH_PASSWORD"
              ''
            else
              "${cfg.package}/bin/pogocache ${lib.escapeShellArgs args}";
            Restart = "always";
            RestartSec = 5;

            # Security hardening
            NoNewPrivileges = true;
            PrivateTmp = true;
            ProtectSystem = "strict";
            ProtectHome = true;
            ProtectKernelTunables = true;
            ProtectKernelModules = true;
            ProtectControlGroups = true;
            RestrictSUIDSGID = true;
            RestrictRealtime = true;
            RestrictNamespaces = true;
            LockPersonality = true;
            MemoryDenyWriteExecute = true;
            SystemCallFilter = [ "@system-service" "~@privileged" ];
            SystemCallArchitectures = "native";
          };

          preStart = lib.optionalString (serverCfg.unixSocket != null) ''
            mkdir -p $(dirname ${serverCfg.unixSocket})
          '' + lib.optionalString serverCfg.persistence.enable ''
            mkdir -p $(dirname ${serverCfg.persistence.file})
          '';

          postStart = lib.optionalString (serverCfg.unixSocket != null) ''
            while [ ! -S ${serverCfg.unixSocket} ]; do
              sleep 0.1
            done
            chmod ${toString serverCfg.unixSocketPerm} ${serverCfg.unixSocket}
            chown ${serverCfg.user}:${serverCfg.group} ${serverCfg.unixSocket}
          '';
        }
      )
      enabledServers;

    assertions = lib.flatten (
      lib.mapAttrsToList
        (name: serverCfg: [
          {
            assertion = serverCfg.auth.password == null || serverCfg.auth.passwordFile == null;
            message = "services.pogocache.servers.${name}: Only one of auth.password or auth.passwordFile can be specified.";
          }
          {
            assertion = !serverCfg.tls.enable || (serverCfg.tls.certFile != null && serverCfg.tls.keyFile != null);
            message = "services.pogocache.servers.${name}: TLS requires both certFile and keyFile to be specified.";
          }
        ])
        enabledServers
    );
  };
}