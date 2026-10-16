{
  lib,
  callPackage,
  symlinkJoin,
  makeDesktopItem,
  runCommand,
}:
# Autodesk Fusion (360) on Linux through a Nix-built, Fusion-patched Wine.
#
#   fusion360 install   downloads Autodesk's installer into a dedicated prefix
#   fusion360           launches it; sign in through the browser, the
#                       adskidmgr: callback comes back via fusion360-login.desktop
#
# Unofficial: Autodesk does not support Linux. Assembled from the lukasl-dev
# fusion360.nix flake (Nix structure, Python helpers; MIT, commit 3d196a8a) and
# the Lolig4 Autodesk-Fusion-360-on-Linux installer (prefix recipe, Wine
# patches; MIT, commit 7da442d6). Icon from cryinkfly's repository (MIT).
let
  wine = callPackage ./wine.nix { };
  common = callPackage ./common.nix { inherit wine; };
  installer = callPackage ./install.nix { inherit common wine; };
  launcher = callPackage ./launcher.nix { inherit common installer wine; };

  desktop = makeDesktopItem {
    name = "fusion360";
    desktopName = "Autodesk Fusion";
    genericName = "CAD Application";
    comment = "3D modeling, CAD, CAM and PCB design (Wine)";
    exec = "${launcher}/bin/fusion360 run %F";
    icon = "fusion360";
    categories = [
      "Graphics"
      "Engineering"
    ];
    keywords = [
      "3D"
      "CAD"
      "CAM"
      "Autodesk"
    ];
    startupWMClass = "fusion360.exe";
    terminal = false;
  };
  # Browser sign-in returns through an adskidmgr: URL; the home-manager module
  # registers this entry as its handler.
  login = makeDesktopItem {
    name = "fusion360-login";
    desktopName = "Autodesk Fusion sign-in";
    exec = "${launcher}/bin/fusion360 login %u";
    mimeTypes = [ "x-scheme-handler/adskidmgr" ];
    noDisplay = true;
    terminal = false;
  };
  icon = runCommand "fusion360-icon" { } ''
    install -Dm644 ${./fusion360.svg} $out/share/icons/hicolor/scalable/apps/fusion360.svg
  '';
in
symlinkJoin {
  name = "fusion360";
  paths = [
    launcher
    installer
    desktop
    login
    icon
  ];
  passthru = {
    inherit
      wine
      common
      installer
      launcher
      ;
  };
  meta = {
    description = "Autodesk Fusion installer and launcher with a Fusion-patched Wine";
    homepage = "https://codeberg.org/Lolig4/Autodesk-Fusion-360-on-Linux";
    license = lib.licenses.mit;
    platforms = [ "x86_64-linux" ];
    mainProgram = "fusion360";
  };
}
