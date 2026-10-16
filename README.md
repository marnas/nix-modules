# nix-modules

Reusable [home-manager](https://github.com/nix-community/home-manager) modules,
packages, and overlays powering my NixOS and macOS (nix-darwin) machines.
My neovim setup lives in its own flake: [nvim-flake](https://github.com/marnas/nvim-flake).

## What's here

- **`homeManagerModules`**
  - `cli` — fish, tmux (tilish + agent-indicator + usage widget), starship, bat, eza, yazi, zsh
  - `wayland` — Hyprland (split-monitor-workspaces), waybar, tofi, swaync, swayidle
  - `firefox` — [arkenfox](https://github.com/arkenfox/user.js)-hardened profile with telemetry off, privacy extensions preinstalled
  - `vlc` — no first-run privacy prompt, network metadata lookups off, 3s arrow-key seeks
  - `fusion360` — Autodesk Fusion through a Fusion-patched Wine (`pkgs.fusion360`: installer, launcher, browser sign-in handler; Linux only)
  - `alacritty`, `ghostty`, `kitty`, `gtk`, `qt`
- **`packages`** — `tilish-colemak` (Colemak fork of tmux-tilish), `tmux-agent-indicator`, `claude-usage` (Claude usage-window widget for the tmux status bar), `claude-tasks` (live full-length view of Claude Code's task list, for a tmux side pane), `tailscale-exit` (Tailscale exit-node status/toggle/picker behind the waybar `custom/tailscale` module), `fusion360` (Autodesk Fusion on a Nix-built Wine with the Lolig4 Fusion patches: `fusion360 install`, then `fusion360`)
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
