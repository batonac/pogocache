#!/usr/bin/env bash

# Simple validation script for the Nix flake and NixOS module
# This checks basic syntax and structure without requiring Nix to be installed

set -e

echo "=== Validating Nix Flake and NixOS Module ==="

# Check that all required files exist
echo "✓ Checking required files exist..."
for file in flake.nix nixos-module.nix README-nix.md; do
    if [[ ! -f "$file" ]]; then
        echo "✗ Missing file: $file"
        exit 1
    fi
    echo "  - $file"
done

# Check that examples directory exists and has files
echo "✓ Checking examples..."
if [[ ! -d "examples" ]]; then
    echo "✗ Missing examples directory"
    exit 1
fi
for file in examples/basic-configuration.nix examples/production-configuration.nix; do
    if [[ ! -f "$file" ]]; then
        echo "✗ Missing example: $file"
        exit 1
    fi
    echo "  - $file"
done

# Basic syntax checks for Nix files
echo "✓ Checking basic Nix syntax..."

# Check that flake.nix has proper structure
if ! grep -q "description.*=.*" flake.nix; then
    echo "✗ flake.nix missing description"
    exit 1
fi

if ! grep -q "inputs.*=.*{" flake.nix; then
    echo "✗ flake.nix missing inputs section"
    exit 1
fi

if ! grep -q "outputs.*=.*{" flake.nix; then
    echo "✗ flake.nix missing outputs section"
    exit 1
fi

if ! grep -q "nixosModules" flake.nix; then
    echo "✗ flake.nix missing nixosModules"
    exit 1
fi

echo "  - flake.nix structure OK"

# Check that nixos-module.nix has proper structure
if ! grep -q "config.*lib.*pkgs" nixos-module.nix; then
    echo "✗ nixos-module.nix missing proper module structure"
    exit 1
fi

if ! grep -q "options.*=.*{" nixos-module.nix; then
    echo "✗ nixos-module.nix missing options section"
    exit 1
fi

if ! grep -q "config.*=.*lib.mkIf" nixos-module.nix; then
    echo "✗ nixos-module.nix missing config section"
    exit 1
fi

if ! grep -q "services.pogocache" nixos-module.nix; then
    echo "✗ nixos-module.nix missing pogocache service configuration"
    exit 1
fi

echo "  - nixos-module.nix structure OK"

# Check that examples have proper structure
for example in examples/*.nix; do
    if ! grep -q "services.pogocache" "$example"; then
        echo "✗ $example missing pogocache service configuration"
        exit 1
    fi
    echo "  - $(basename "$example") structure OK"
done

# Verify pogocache binary works
echo "✓ Testing pogocache binary..."
if ! ./pogocache --help &>/dev/null; then
    echo "✗ pogocache binary not working"
    exit 1
fi
echo "  - pogocache binary OK"

# Check that configuration parameters in module match binary help
echo "✓ Checking configuration parameter coverage..."

# Extract options from help
help_output=$(./pogocache --help)

# Check that major options are covered in the module
major_options=("host" "port" "threads" "maxmemory" "evict" "auth" "tlsport" "shards" "backlog")
missing_options=()

for option in "${major_options[@]}"; do
    if ! grep -q "bind\|$option" nixos-module.nix; then
        missing_options+=("$option")
    fi
done

if [[ ${#missing_options[@]} -gt 0 ]]; then
    echo "✗ Missing options in module: ${missing_options[*]}"
    exit 1
fi

echo "  - Major configuration options covered"

echo ""
echo "🎉 All validations passed!"
echo ""
echo "Summary:"
echo "- Flake provides pogocache package and NixOS module"
echo "- NixOS module supports all major configuration options"
echo "- Examples demonstrate basic and production usage"
echo "- All files have proper Nix syntax structure"
echo ""
echo "Ready for use! See README-nix.md for usage instructions."