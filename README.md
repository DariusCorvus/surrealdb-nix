# surrealdb-nix

A Nix flake that packages precompiled [SurrealDB](https://surrealdb.com) CLI binaries — every stable release, ready in seconds instead of an hour-long source build.

Read more about why this exists: [Why I Packaged SurrealDB for Nix Myself](https://darius.codes/writing/surrealdb-nix)

## The problem

The official nixpkgs SurrealDB package compiles from source with no cached binaries, taking an hour or longer. It also only provides a single pinned version — but SurrealDB CLI and database versions must match exactly for safe imports and exports. If you work across multiple projects on different SurrealDB versions, the official package doesn't cut it.

## What this does

- Wraps precompiled binaries from SurrealDB's download server — no compilation
- Every stable release available as a separate package (70+ versions, from 1.0.0 to 3.0.5)
- Verified SHA256 hashes for reproducibility
- Supports `x86_64-linux`, `aarch64-linux`, `x86_64-darwin`, and `aarch64-darwin`

## Usage

### Run directly

```sh
# latest version
nix run github:DariusCorvus/surrealdb-nix

# specific version
nix run github:DariusCorvus/surrealdb-nix#v3-0-5
nix run github:DariusCorvus/surrealdb-nix#v2-6-4
nix run github:DariusCorvus/surrealdb-nix#v1-0-0
```

### Temporary shell

```sh
nix shell github:DariusCorvus/surrealdb-nix
surreal version
```

### As a flake input

```nix
{
  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
    surrealdb.url = "github:DariusCorvus/surrealdb-nix";
  };

  outputs = { nixpkgs, surrealdb, ... }: {
    # use surrealdb.packages.${system}.default for latest
    # use surrealdb.packages.${system}.v3-0-5 for a specific version
  };
}
```

### In a devShell

```nix
devShells.default = pkgs.mkShell {
  packages = [
    surrealdb.packages.${system}.default    # latest
    # surrealdb.packages.${system}.v2-6-4   # or pin a version
  ];
};
```

## Version naming

Versions are exposed as package attributes with dots replaced by dashes:

| SurrealDB version | Attribute |
|---|---|
| 3.0.5 | `v3-0-5` |
| 2.6.4 | `v2-6-4` |
| 1.0.0 | `v1-0-0` |

The `default` package always points to the latest version.

## Updating versions

```sh
# add the latest release
./update.sh

# add a specific version
./update.sh 3.0.2

# add all stable releases from GitHub
./update.sh --all
```

The script downloads each binary, computes SRI hashes, and writes them to `versions.json`.
