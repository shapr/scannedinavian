{
  description = "hakyll-nix-template";

  nixConfig = {
    allow-import-from-derivation = "true";
    bash-prompt = "[hakyll-nix]λ ";
    extra-substituters = [
      "https://cache.iog.io"
    ];
    extra-trusted-public-keys = [
      "hydra.iohk.io:f/Ea+s+dFdN+3Y/G+FDgSq+a5NEWhJGzdjvKNGv0/EQ="
    ];
  };

  inputs.nixpkgs.url = "github:NixOS/nixpkgs/nixos-24.05";
  inputs.flake-utils.url = "github:numtide/flake-utils";

  outputs = { self, nixpkgs, flake-utils }:
    flake-utils.lib.eachDefaultSystem (system:
      let
        pkgs = import nixpkgs {
          inherit system;
          # random haskell libraries are often marked as broken, probably
          # because they often are!  but let's roll the dice and hope they're
          # not broken in ways that matter to us.
          config = { allowBroken = true; };
        };

        hakyll-site = (pkgs.haskellPackages.callCabal2nix "ssg" ./ssg {
        }).overrideAttrs {
          preferLocalBuild = true;
          allowSubstitutes = false;
        };

        website = pkgs.stdenv.mkDerivation {
          name = "website";
          preferLocalBuild = true;
          allowSubstitutes = false;
          buildInputs = [];
          src = pkgs.nix-gitignore.gitignoreSourcePure [
            ./.gitignore
            ".git"
            ".github"
          ] ./.;

          # LANG and LOCALE_ARCHIVE are fixes pulled from the community:
          #   https://github.com/jaspervdj/hakyll/issues/614#issuecomment-411520691
          #   https://github.com/NixOS/nix/issues/318#issuecomment-52986702
          #   https://github.com/MaxDaten/brutal-recipes/blob/source/default.nix#L24
          LANG = "en_US.UTF-8";
          LOCALE_ARCHIVE = pkgs.lib.optionalString
            (pkgs.buildPlatform.libc == "glibc")
            "${pkgs.glibcLocales}/lib/locale/locale-archive";

          buildPhase = ''
            ${hakyll-site}/bin/hakyll-site build --verbose
            if [ ! -e dist ]; then
              echo "FAIL: hakyll produced no dist directory"
              exit 1
            fi
          '';

          installPhase = ''
            mkdir -p "$out/dist"
            cp -a dist/. "$out/dist"
          '';
        };

      in {
        apps = {
          default = flake-utils.lib.mkApp {
            drv = hakyll-site;
            exePath = "/bin/hakyll-site";
          };
          repl = {
            type = "app";
            program =
              let
                script = pkgs.writeShellApplication {
                  name = "run-it";
                  runtimeInputs = [ (pkgs.haskellPackages.ghcWithPackages (hs: [ hs.hakyll hakyll-site hs.cabal-install ])) ];
                  text = ''
                    cd ssg; cabal repl
                  '';
                };
              in
                "${script}/bin/run-it";
          };
        };

        packages = {
          inherit hakyll-site website;
          default = website;
        };

        devShells.default = pkgs.mkShell {
          packages = [  ];
        };
      }
    );
}
