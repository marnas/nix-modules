{ inputs, ... }:
{
  # Bring the custom packages from ./pkgs into pkgs.*
  additions = final: _prev: import ../pkgs { pkgs = final; };

  # Expose the stable nixpkgs set as pkgs.stable.* (used e.g. by the gtk
  # module while a package is broken on unstable).
  stable-packages = final: _prev: {
    stable = import inputs.nixpkgs-stable {
      system = final.stdenv.hostPlatform.system;
      config.allowUnfree = true;
    };
  };
}
