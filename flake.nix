{
  description = "Pogocache - Fast caching software with low latency and CPU efficiency";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
    flake-utils.url = "github:numtide/flake-utils";
  };

  outputs = { self, nixpkgs, flake-utils }:
    flake-utils.lib.eachDefaultSystem (system:
      let
        pkgs = nixpkgs.legacyPackages.${system};
        
        pogocache = pkgs.stdenv.mkDerivation rec {
          pname = "pogocache";
          version = "0.1.0";

          src = ./.;

          nativeBuildInputs = with pkgs; [
            gcc
            gnumake
            pkg-config
            wget
            tar
            gzip
          ];

          buildInputs = with pkgs; [
            liburing
            openssl
          ];

          # Set environment variables for system libraries
          env = {
            NIX_CFLAGS_COMPILE = "-I${pkgs.openssl.dev}/include -I${pkgs.liburing.dev}/include";
            NIX_LDFLAGS = "-L${pkgs.openssl.out}/lib -L${pkgs.liburing.out}/lib";
          };

          # Patch the Makefile to use system libraries instead of building from source
          postPatch = ''
            # For Linux builds, modify the Makefile to use system liburing
            if [ "$(uname -s)" = "Linux" ]; then
              substituteInPlace src/Makefile \
                --replace 'ifdef NOURING' 'ifdef DISABLED_NOURING' \
                --replace '../deps/liburing/src/liburing.a:' 'skip-liburing-build:' \
                --replace $'\t../deps/build-uring.sh' $'\t# Using system liburing' \
                --replace 'DEPS += ../deps/liburing/src/liburing.a' '' \
                --replace 'CLIBS += ../deps/liburing/src/liburing.a' 'CLIBS += -luring'
            else
              # On non-Linux, disable uring
              substituteInPlace src/Makefile \
                --replace 'ifdef NOURING' 'ifndef NEVER_TRUE'
            fi

            # Handle OpenSSL - use system libraries
            substituteInPlace src/Makefile \
              --replace 'ifdef NOOPENSSL' 'ifdef DISABLED_NOOPENSSL' \
              --replace '../deps/openssl/libssl.a:' 'skip-openssl-build:' \
              --replace $'\t../deps/build-openssl.sh' $'\t# Using system openssl' \
              --replace 'DEPS += ../deps/openssl/libssl.a' '' \
              --replace 'CLIBS += ../deps/openssl/libssl.a ../deps/openssl/libcrypto.a' 'CLIBS += -lssl -lcrypto' \
              --replace 'CFLAGS += "-I../deps/openssl/include"' ''

            # Handle git version info gracefully when not in a git repo
            substituteInPlace src/Makefile \
              --replace '$(shell git rev-parse --short HEAD)' '${version}' \
              --replace '$(shell git describe --tags | sed '\''s/^v//'\'' | xargs)' '${version}'
          '';

          buildPhase = ''
            runHook preBuild
            make clean || true
            make
            runHook postBuild
          '';

          installPhase = ''
            runHook preInstall
            mkdir -p $out/bin
            cp pogocache $out/bin/
            runHook postInstall
          '';

          meta = with pkgs.lib; {
            description = "Fast caching software built from scratch with a focus on low latency and CPU efficiency";
            homepage = "https://github.com/batonac/pogocache";
            license = licenses.agpl3Only;
            maintainers = [ ];
            platforms = platforms.linux ++ platforms.darwin;
            mainProgram = "pogocache";
          };
        };
      in
      {
        packages = {
          default = pogocache;
          pogocache = pogocache;
        };

        apps = {
          default = flake-utils.lib.mkApp {
            drv = pogocache;
          };
        };

        devShells.default = pkgs.mkShell {
          buildInputs = with pkgs; [
            gcc
            gnumake
            pkg-config
            liburing
            openssl
            gdb
            valgrind
          ];
        };
      }) // {
        nixosModules.default = import ./nixos-module.nix;
        nixosModules.pogocache = import ./nixos-module.nix;
      };
}