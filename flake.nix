{
  description = "Reusable home-manager modules, packages, and overlays (NixOS + darwin)";

  inputs = {
    nixpkgs.url = "nixpkgs/nixos-unstable";
    nixpkgs-stable.url = "github:nixos/nixpkgs/nixos-25.11";

    home-manager = {
      url = "github:nix-community/home-manager/master";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    # Tracks main, locked to one commit: bump it with the other inputs, or point
    # `ref=` at a tag once one exists that builds on nix (v0.56.2 shipped with a
    # glaze-7 CMake requirement against a glaze-8 nixpkgs and needed a
    # months-old nixpkgs pin that also froze mesa). If such a pin is ever
    # needed again, treat it as temporary and try to bump or drop it on every
    # input update.
    # Do NOT set inputs.nixpkgs.follows: it forces a source rebuild and loses
    # the hyprland.cachix.org binary cache (upstream warns against it).
    hyprland.url = "git+https://github.com/hyprwm/Hyprland?submodules=1";

    split-monitor-workspaces = {
      url = "github:zjeffer/split-monitor-workspaces?ref=refs/tags/v0.56.2";
      inputs.hyprland.follows = "hyprland";
    };

    firefox-addons = {
      url = "gitlab:rycee/nur-expressions?dir=pkgs/firefox-addons";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    arkenfox-nixos = {
      url = "github:dwarfmaster/arkenfox-nixos";
      inputs.nixpkgs.follows = "nixpkgs";
    };
  };

  outputs =
    {
      self,
      nixpkgs,
      home-manager,
      ...
    }@inputs:
    let
      systems = [
        "x86_64-linux"
        "aarch64-linux"
        "x86_64-darwin"
        "aarch64-darwin"
      ];
      forAllSystems = nixpkgs.lib.genAttrs systems;

      overlays = import ./overlays { inherit inputs; };

      # Injects this flake's inputs into modules that need them (firefox,
      # wayland). The `key` deduplicates the module when several wrapped
      # modules are imported into the same configuration.
      flakeArgs = {
        key = "marnas/nix-modules/flake-args";
        config._module.args.nixModulesInputs = inputs;
      };
    in
    {
      inherit overlays;

      packages = forAllSystems (system: import ./pkgs { pkgs = nixpkgs.legacyPackages.${system}; });

      homeManagerModules = rec {
        # cli
        bat = ./modules/cli/bat.nix;
        eza = ./modules/cli/eza.nix;
        fish = ./modules/cli/fish.nix;
        starship = ./modules/cli/starship.nix;
        tmux = ./modules/cli/tmux.nix; # needs overlays.additions (tmux plugins)
        zsh = ./modules/cli/zsh.nix;
        # All cli modules in one import.
        cli = {
          imports = [
            bat
            eza
            fish
            starship
            tmux
            zsh
          ];
        };

        # desktop
        alacritty = ./modules/desktop/alacritty.nix;
        fusion360 = ./modules/desktop/fusion360.nix; # needs overlays.additions (Linux only)
        ghostty = ./modules/desktop/ghostty.nix;
        gtk = ./modules/desktop/gtk.nix; # needs overlays.stable-packages
        kitty = ./modules/desktop/kitty.nix;
        qt = ./modules/desktop/qt.nix;
        vlc = ./modules/desktop/vlc.nix;
        firefox = {
          imports = [
            inputs.arkenfox-nixos.hmModules.default
            flakeArgs
            ./modules/desktop/firefox.nix
          ];
        };
        # Hyprland + waybar + tofi + mako + swayidle (Linux only).
        wayland = {
          imports = [
            flakeArgs
            ./modules/desktop/wayland
          ];
        };
      };

      # Demo configuration: proves the flake evaluates standalone and shows
      # how the pieces compose. Not meant to be activated as-is.
      homeConfigurations.demo = home-manager.lib.homeManagerConfiguration {
        pkgs = nixpkgs.legacyPackages.x86_64-linux;
        modules = [
          {
            nixpkgs.overlays = [
              overlays.additions
              overlays.stable-packages
            ];
            nixpkgs.config.allowUnfree = true;
            home = {
              username = "demo";
              homeDirectory = "/home/demo";
              stateVersion = "26.05";
            };
            programs.home-manager.enable = true;
          }
          self.homeManagerModules.cli
          self.homeManagerModules.alacritty
          self.homeManagerModules.ghostty
          self.homeManagerModules.kitty
          self.homeManagerModules.gtk
          self.homeManagerModules.qt
          self.homeManagerModules.vlc
          self.homeManagerModules.firefox
          self.homeManagerModules.fusion360
          self.homeManagerModules.wayland
        ];
      };
    };
}
