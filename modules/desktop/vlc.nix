{
  config,
  lib,
  pkgs,
  ...
}:
let
  inherit (pkgs.stdenv.hostPlatform) isDarwin;
  cfg = config.nixModules.vlc;

  # VLC records the first-run privacy answer in vlcrc, so without a declared
  # one every fresh or non-persistent home re-prompts. Read-only nix-store
  # symlink: VLC leaves a read-only vlcrc alone (src/config/file.c), so
  # preferences changed in the GUI don't stick - set them here instead
  # (option names: `vlc -H --advanced`).
  vlcrc = ''
    [qt]
    qt-privacy-ask=0

    [core]
    # Don't send media names/tags to third-party services for art and
    # metadata lookups.
    metadata-network-access=0
    # Plain Left/Right (and Alt+Left/Right) seek by this many seconds.
    short-jump-size=3
  '';
in
{
  options.nixModules.vlc.package = lib.mkOption {
    type = lib.types.nullOr lib.types.package;
    default = if isDarwin then pkgs.vlc-bin-universal else pkgs.vlc;
    defaultText = lib.literalExpression "if isDarwin then pkgs.vlc-bin-universal else pkgs.vlc";
    description = ''
      VLC package to install. null keeps only the config (vlcrc) side, for
      hosts that install VLC another way (Homebrew cask on macOS, where the
      cask tracks VideoLAN releases ahead of nixpkgs' vlc-bin).
    '';
  };

  config = lib.mkMerge [
    {
      home.packages = lib.optional (cfg.package != null) cfg.package;
    }
    # VLC 3's config dir: XDG on Linux, ~/Library/Preferences/<bundle id> on
    # macOS (src/darwin/dirs.c).
    (lib.mkIf isDarwin {
      home.file."Library/Preferences/org.videolan.vlc/vlcrc".text = vlcrc;
    })
    (lib.mkIf (!isDarwin) {
      xdg.configFile."vlc/vlcrc".text = vlcrc;
    })
  ];
}
