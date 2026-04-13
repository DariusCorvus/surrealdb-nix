{
  description = "SurrealDB CLI binary";

  inputs.nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";

  outputs = { self, nixpkgs }:
    let
      supportedSystems = [ "x86_64-linux" "aarch64-linux" "x86_64-darwin" "aarch64-darwin" ];
      forAllSystems = nixpkgs.lib.genAttrs supportedSystems;

      versions = builtins.fromJSON (builtins.readFile ./versions.json);

      archMap = {
        x86_64-linux = "linux-amd64";
        aarch64-linux = "linux-arm64";
        x86_64-darwin = "darwin-amd64";
        aarch64-darwin = "darwin-arm64";
      };

      mkSurreal = { pkgs, system, version }:
        let
          arch = archMap.${system};
          src = pkgs.fetchurl {
            url = "https://download.surrealdb.com/v${version}/surreal-v${version}.${arch}.tgz";
            hash = versions.versions.${version}.${system};
          };
          unpacked = pkgs.runCommand "surrealdb-${version}-unpacked" {} ''
            mkdir -p $out/bin
            tar -xzf ${src} -C $out/bin
            chmod +x $out/bin/surreal
          '';
        in
        if pkgs.stdenv.isLinux then
          pkgs.buildFHSEnv {
            name = "surreal";
            targetPkgs = p: with p; [ openssl libgcc glibc ];
            runScript = "${unpacked}/bin/surreal";
            meta = {
              description = "SurrealDB CLI v${version}";
              homepage = "https://surrealdb.com";
              mainProgram = "surreal";
            };
          }
        else
          pkgs.runCommand "surrealdb-${version}" { meta = { mainProgram = "surreal"; }; } ''
            mkdir -p $out/bin
            ln -s ${unpacked}/bin/surreal $out/bin/surreal
          '';

      mkPackages = system:
        let
          pkgs = nixpkgs.legacyPackages.${system};
          versionPackages = builtins.listToAttrs (map (version: {
            name = "v${builtins.replaceStrings ["."] ["-"] version}";
            value = mkSurreal { inherit pkgs system version; };
          }) (builtins.attrNames versions.versions));
          latest = mkSurreal { inherit pkgs system; version = versions.latest; };
        in
        versionPackages // { default = latest; };
    in
    {
      packages = forAllSystems mkPackages;
    };
}
