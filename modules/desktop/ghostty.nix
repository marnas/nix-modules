{
  lib,
  pkgs,
  ...
}:
{

  programs.ghostty = {
    enable = true;
    enableFishIntegration = true;

    # The source `ghostty` package is unavailable on darwin; use the official
    # binary repack there.
    package = if pkgs.stdenv.isDarwin then pkgs.ghostty-bin else pkgs.ghostty;

    settings = {
      # Font configuration
      font-family = "FiraCode Nerd Font";
      font-size = 11;

      # Use fish as the default shell
      command = "${pkgs.fish}/bin/fish";

      # Scrollback
      scrollback-limit = 10000;

      # macOS specific
      macos-option-as-alt = lib.mkIf pkgs.stdenv.hostPlatform.isDarwin "left";
      # Hide titlebar but keep rounded corners + native borders (so JankyBorders' round style aligns).
      macos-titlebar-style = lib.mkIf pkgs.stdenv.hostPlatform.isDarwin "hidden";

      # Alacritty default theme colors
      foreground = "d8d8d8";
      background = "181818";
      cursor-color = "d8d8d8";
      cursor-style-blink = true;

      # Black
      palette = [
        "0=#181818"
        "8=#6b6b6b"
        # Red
        "1=#ac4242"
        "9=#c55555"
        # Green
        "2=#90a959"
        "10=#aac474"
        # Yellow
        "3=#f4bf75"
        "11=#feca88"
        # Blue
        "4=#6a9fb5"
        "12=#82b8c8"
        # Magenta
        "5=#aa759f"
        "13=#c28cb8"
        # Cyan
        "6=#75b5aa"
        "14=#93d3c3"
        # White
        "7=#d8d8d8"
        "15=#f8f8f8"
      ];

      # Disable bottom toast notifications
      app-notifications = false;

      # URL handling - Ctrl+click to open URLs in default browser
      link-url = true;

      # Keybindings
      keybind = [
        "ctrl+tab=text:⌐"
        "ctrl+shift+tab=text:¬"
      ];
    };
  };

}
