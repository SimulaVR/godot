{
  inputs = {
    nixpkgs.url = "github:nixos/nixpkgs/nixpkgs-unstable";
    systems.url = "github:nix-systems/default-linux";
    flake-parts = {
      url = "github:hercules-ci/flake-parts";
      inputs.nixpkgs-lib.follows = "nixpkgs";
    };
    treefmt-nix = {
      url = "github:numtide/treefmt-nix";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    wlroots.url = "github:SimulaVR/wlroots";
  };

  outputs =
    inputs:
    inputs.flake-parts.lib.mkFlake { inherit inputs; } {
      imports = [
        inputs.treefmt-nix.flakeModule
      ];

      systems = import inputs.systems;

      perSystem =
        {
          pkgs,
          lib,
          system,
          ...
        }:
        let
          gdwlroots = pkgs.fetchFromGitHub {
            owner = "SimulaVR";
            repo = "gdwlroots";
            rev = "88cbe52ee28219fc77194a1c87d71de3ce0be127";
            hash = "sha256-CLygKinJGAxFMQme/+UIX6smqgP1aaf5VBhPZCIbH2g=";
          };
          wlroots = inputs.wlroots.packages.${system}.default;

          godot = pkgs.stdenv.mkDerivation {
            pname = "godot";
            version = "3.x-simula";
            src = lib.cleanSource ./.;

            inherit buildInputs;
            nativeBuildInputs = tools.build ++ tools.hooks;

            outputs = [
              "out"
              "dev"
            ];

            configurePhase = ''
              echo 'Copying GitHub gdwlroots to ./modules/gdwlroots'
              cp -r ${gdwlroots} modules/gdwlroots
              chmod -R u+w modules/gdwlroots
              echo 'Generating xdg-shell-protocol.{h,c}'
              cd modules/gdwlroots
              ${pkgs.wayland-scanner.bin}/bin/wayland-scanner server-header ${pkgs.wayland-protocols}/share/wayland-protocols/stable/xdg-shell/xdg-shell.xml xdg-shell-protocol.h
              ${pkgs.wayland-scanner.bin}/bin/wayland-scanner private-code ${pkgs.wayland-protocols}/share/wayland-protocols/stable/xdg-shell/xdg-shell.xml xdg-shell-protocol.c
              cd -
            '';

            buildPhase = ''
              echo Building...
              scons platform=x11 tools=no target=release bits=64 x11_egl=yes -j $NIX_BUILD_CORES
            '';

            installPhase = ''
              # Install godot
              mkdir -p $out/bin
              cp bin/godot.x11.opt.64 $out/bin/godot

              # Install gdnative headers
              mkdir $dev
              cp -r modules/gdnative/include $dev

              # Install man
              mkdir -p $out/share/man/man6
              cp misc/dist/linux/godot.6 $out/share/man/man6

              mkdir -p $out/share/applications
              mkdir -p $out/share/icons/hicolor/scalable/apps
              cp misc/dist/linux/org.godotengine.Godot.desktop $out/share/applications
              cp icon.svg $out/share/icons/hicolor/scalable/apps/godot.svg
              cp icon.png $out/share/icons/godot.png
              substituteInPlace $out/share/applications/org.godotengine.Godot.desktop \
                --replace-warn "Exec=godot" "Exec=$out/bin/godot"
            '';

            meta = {
              homepage = "https://github.com/SimulaVR/godot";
              license = lib.licenses.mit;
              platforms = [ "x86_64-linux" ];
            };
          };

          tools.lsp = [
            pkgs.nil # Nix
            pkgs.clang-tools # C / C++
          ];
          tools.build = [
            pkgs.just
            pkgs.scons
            pkgs.pkg-config
            pkgs.wayland-scanner
          ];
          tools.hooks = [
            pkgs.autoPatchelfHook
          ];
          buildInputs = [
            pkgs.libxcb
            pkgs.libX11
            pkgs.libXcursor
            pkgs.libXinerama
            pkgs.libXext
            pkgs.libXrandr
            pkgs.libXi
            pkgs.libGLU
            pkgs.zlib

            pkgs.alsa-lib
            pkgs.libpulseaudio
            pkgs.yasm
            pkgs.systemd

            pkgs.libxkbcommon
            pkgs.wayland
            pkgs.wayland-protocols
            pkgs.pixman
            pkgs.dbus-glib
            pkgs.libdrm
            pkgs.libgbm
            pkgs.mesa

            pkgs.libxcb-errors
            wlroots
          ];
        in
        {
          _module.args.pkgs = import inputs.nixpkgs {
            inherit system;
            config.allowUnfree = true;
          };

          treefmt = {
            projectRootFile = ".editorconfig";
            programs.nixfmt.enable = true;
          };

          packages = {
            inherit godot wlroots;
            default = godot;
          };

          devShells.default = pkgs.mkShell {
            inherit buildInputs;
            nativeBuildInputs = tools.lsp ++ tools.build;
          };
        };
    };
}
