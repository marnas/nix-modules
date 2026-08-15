{ pkgs, ... }:
{
  home.pointerCursor = {
    enable = true;
    gtk.enable = true;
    name = "macOS";
    package = pkgs.apple-cursor;
    size = 24;
  };

  gtk = {
    enable = true;
    cursorTheme = {
      package = pkgs.apple-cursor;
      name = "macOS";
      size = 24;
    };

    # font.name = "TeX Gyre Adventor 10";
    # Removed from unstable along with gtk-engine-murrine; still in 25.11.
    theme = {
      name = "Andromeda";
      package = pkgs.stable.andromeda-gtk-theme;
    };
    gtk4.theme = {
      name = "Andromeda";
      package = pkgs.stable.andromeda-gtk-theme;
    };
    # iconTheme = {
    #   name = "Kora";
    #   package = pkgs.kora-icon-theme;
    # };
  };

  qt.enable = true;
}
