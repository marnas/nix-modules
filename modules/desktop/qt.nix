{
  qt = {
    enable = true;
    # qt6gtk2 was removed from nixpkgs (gtk2); gtk3 is built into qtbase.
    platformTheme.name = "gtk3";
  };
}
