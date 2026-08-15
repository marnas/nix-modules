# nix-modules

Reusable [home-manager](https://github.com/nix-community/home-manager) modules,
packages, and overlays powering my NixOS and macOS (nix-darwin) machines.
My neovim setup lives in its own flake: [nvim-flake](https://github.com/marnas/nvim-flake).

## What's here

- **`homeManagerModules`**
  - `cli` — fish, tmux (tilish + agent-indicator + usage widget), starship, bat, eza, yazi, zsh
  - `wayland` — Hyprland (split-monitor-workspaces), waybar, tofi, mako, swayidle
  - `firefox` — [arkenfox](https://github.com/arkenfox/user.js)-hardened profile with telemetry off, privacy extensions preinstalled
  - `alacritty`, `ghostty`, `kitty`, `gtk`, `qt`
- **`packages`** — `tilish-colemak` (Colemak fork of tmux-tilish), `tmux-agent-indicator`, `claude-usage` (Claude usage-window widget for the tmux status bar)
- **`overlays`** — `additions` (the packages above), `stable-packages` (`pkgs.stable.*` escape hatch)

## Usage

```nix
{
  inputs.nix-modules.url = "github:marnas/nix-modules";

  # in a homeManagerConfiguration's modules:
  modules = [
    { nixpkgs.overlays = [ inputs.nix-modules.overlays.additions ]; }
    inputs.nix-modules.homeManagerModules.cli
    inputs.nix-modules.homeManagerModules.firefox
  ];
}
```

`tmux` needs `overlays.additions` (its plugins); `gtk` needs `overlays.stable-packages`.
Modules are cross-platform unless noted; platform conditionals use `pkgs.stdenv.hostPlatform.isDarwin`.

A full composition example is in `homeConfigurations.demo` in [flake.nix](./flake.nix):

```sh
nix build .#homeConfigurations.demo.activationPackage --no-link
```
