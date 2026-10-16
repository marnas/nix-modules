{ wineWow64Packages }:
# Wine for Fusion only; the system Wine is untouched. Fusion needs Wine >= 11.1,
# and from 11.11 on an unpatched Wine renders a black 3D canvas (symcrypt), so
# the plain nixpkgs package is not an option either way. Vanilla (non-staging)
# is what upstream's fusion-wine-build runtime is built from.
#
# Patches come from the actively maintained Lolig4 fork of the cryinkfly
# installer (files/setup/data/fusion-patches/, MIT), commit 7da442d6
# (2026-09-22). Inventor-only patches are left out.
wineWow64Packages.unstableFull.overrideAttrs (old: {
  patches = (old.patches or [ ]) ++ [
    # Fusion's docked palettes are owned WS_EX_TOOLWINDOW popups; managed, the
    # WM stacks them with the main window instead of above every other app.
    ./wine/winex11-owned-tool-windows.patch
    # Tooltip glyphs rasterized at the wrong size when the ribbon already cached
    # them in another rendering mode.
    ./wine/dwrite-glyph-cache-rendering-mode.patch
    # DXVK viewport (a child window, hence an offscreen surface): wait for the
    # Vulkan present before the blit, or the canvas lags one frame behind.
    ./wine/win32u-vulkan-wait-for-present.patch
    # RSA public exponent 1 (Fusion imports such a key); wrong private exponent
    # left the 3D subsystem uninitialised -> black canvas since Wine 11.11.
    ./wine/symcrypt-rsa-exponent1.patch
  ];
  passthru = (old.passthru or { }) // {
    fusionPatched = true;
  };
})
