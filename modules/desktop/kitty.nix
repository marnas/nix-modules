{ lib, pkgs, ... }:
{

  programs.kitty = {
    enable = true;

    shellIntegration.enableFishIntegration = true;

    font = {
      # name = if pkgs.stdenv.hostPlatform.isDarwin then "FiraCode Nerd Font" else "DejaVu Sans Mono";
      name = "FiraCode Nerd Font";
      size = if pkgs.stdenv.hostPlatform.isDarwin then 14 else 11;
    };

    settings = {
      scrollback_lines = 10000;

      # Enable graphics protocol for album art
      allow_remote_control = true;

      # Window settings
      hide_window_decorations = lib.mkIf pkgs.stdenv.hostPlatform.isDarwin "titlebar-only";

      # macOS specific
      macos_option_as_alt = lib.mkIf pkgs.stdenv.hostPlatform.isDarwin "left";

      # Alacritty default theme colors
      foreground = "#d8d8d8";
      background = "#181818";
      cursor = "#d8d8d8";
      # Black
      color0 = "#181818";
      color8 = "#6b6b6b";
      # Red
      color1 = "#ac4242";
      color9 = "#c55555";
      # Green
      color2 = "#90a959";
      color10 = "#aac474";
      # Yellow
      color3 = "#f4bf75";
      color11 = "#feca88";
      # Blue
      color4 = "#6a9fb5";
      color12 = "#82b8c8";
      # Magenta
      color5 = "#aa759f";
      color13 = "#c28cb8";
      # Cyan
      color6 = "#75b5aa";
      color14 = "#93d3c3";
      # White
      color7 = "#d8d8d8";
      color15 = "#f8f8f8";
    };

    keybindings = {
      "ctrl+tab" = "send_text all \\u2310";
      "ctrl+shift+tab" = "send_text all \\u00AC";
    };
  };

}
