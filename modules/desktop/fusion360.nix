{
  config,
  lib,
  pkgs,
  ...
}:
# Autodesk Fusion through Wine (pkgs.fusion360, needs overlays.additions).
# Linux only. After activation run `fusion360 install` once; the prefix lives in
# ~/.local/share/fusion360 (persist it on an ephemeral home).
let
  cfg = config.programs.fusion360;
in
{
  options.programs.fusion360 = {
    enable = lib.mkEnableOption "Autodesk Fusion through a Fusion-patched Wine";
    package = lib.mkPackageOption pkgs "fusion360" { };
  };

  config = lib.mkIf cfg.enable {
    home.packages = [ cfg.package ];

    # Sign-in happens in the browser and returns through an adskidmgr: URL that
    # must reach Identity Manager inside the prefix.
    xdg.mimeApps = {
      enable = true;
      defaultApplications."x-scheme-handler/adskidmgr" = "fusion360-login.desktop";
    };
  };
}
