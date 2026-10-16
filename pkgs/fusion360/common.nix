{
  wine,
  cacert,
  python3,
  coreutils,
  findutils,
  gnugrep,
  gnused,
  util-linux,
  systemd,
}:
# Shell prelude shared by the installer and the launcher: state paths, Wine
# environment, the prefix lock and the graphics policy.
let
  python = python3.withPackages (ps: [ ps.pylnk3 ]);
  pythonSource = ./python;
in
{
  inherit python pythonSource;

  runtimeInputs = [
    wine
    python
    coreutils
    findutils
    gnugrep
    gnused
    util-linux
    systemd
  ];

  text = # bash
    ''
      data_dir="''${FUSION360_DATA_HOME:-''${XDG_DATA_HOME:-$HOME/.local/share}/fusion360}"
      cache_dir="''${FUSION360_CACHE_HOME:-''${XDG_CACHE_HOME:-$HOME/.cache}/fusion360}"
      state_dir="''${FUSION360_STATE_HOME:-''${XDG_STATE_HOME:-$HOME/.local/state}/fusion360}"

      for directory in "$data_dir" "$cache_dir" "$state_dir"; do
        if [[ "$directory" != /* || "$directory" == / ]]; then
          echo "Fusion paths must be absolute, non-root directories: $directory" >&2
          exit 2
        fi
      done

      export WINEPREFIX="$data_dir/prefix"
      export WINE=${wine}/bin/wine
      export WINESERVER=${wine}/bin/wineserver
      export WINEARCH=win64
      export WINEDEBUG="''${WINEDEBUG:--all,+err}"
      export W_CACHE="$cache_dir/winetricks"
      export NIX_SSL_CERT_FILE="''${NIX_SSL_CERT_FILE:-${cacert}/etc/ssl/certs/ca-bundle.crt}"
      export DXVK_LOG_LEVEL=none

      # The packaged desktop entries own Linux integration.
      export WINEDLLOVERRIDES="winemenubuilder.exe=d''${WINEDLLOVERRIDES:+;$WINEDLLOVERRIDES}"

      # Wine maps Unix file names through LC_CTYPE; a non-UTF-8 locale mangles them.
      case "''${LC_ALL:-''${LC_CTYPE:-''${LANG:-}}}" in
        *[Uu][Tt][Ff]-8* | *[Uu][Tt][Ff]8*) ;;
        *) export LC_CTYPE=C.UTF-8 ;;
      esac

      # Fusion bundles Windows Qt; the Linux desktop's Qt platform/theme/plugin
      # variables must not reach it.
      unset QT_QPA_PLATFORM QT_QPA_PLATFORMTHEME QT_STYLE_OVERRIDE
      unset QT_PLUGIN_PATH QT_QPA_PLATFORM_PLUGIN_PATH QML2_IMPORT_PATH QML_IMPORT_PATH
      unset QT_WAYLAND_DISABLE_WINDOWDECORATION

      # Chromium's sandbox does not survive Wine's CreateDesktop handling and
      # leaves the Data Panel blank. Qt only checks that the variable exists, so
      # opting back in has to unset it rather than set it to 0.
      case "''${FUSION360_WEBENGINE_SANDBOX:-0}" in
        0) export QTWEBENGINE_DISABLE_SANDBOX=1 ;;
        1) unset QTWEBENGINE_DISABLE_SANDBOX ;;
        *)
          echo "FUSION360_WEBENGINE_SANDBOX must be 0 or 1." >&2
          exit 2
          ;;
      esac

      fail() {
        echo "fusion360: $*" >&2
        exit 1
      }

      require_display() {
        # Wine runs on X11 (Xwayland). A browser-spawned login handler may lack
        # DISPLAY: read the local one from the systemd user session, never over SSH.
        if [[ -z "''${DISPLAY:-}" && -z "''${SSH_CONNECTION:-}" && -z "''${SSH_TTY:-}" ]]; then
          local key value
          while IFS='=' read -r key value; do
            if [[ "$key" == DISPLAY && "$value" =~ ^:[0-9]+(\.[0-9]+)?$ ]]; then
              export DISPLAY="$value"
              break
            fi
          done < <(timeout 2 systemctl --user show-environment 2>/dev/null || true)
        fi
        [[ -n "''${DISPLAY:-}" ]] || fail "No X11 display. Run from your desktop session (Xwayland on Wayland)."
      }

      lock_prefix() {
        umask 077
        mkdir -p "$data_dir" "$state_dir"
        exec 9>"$data_dir/prefix.lock"
        flock "$1" --nonblock 9 || fail "Fusion is running, or an installation is in progress. Close Fusion; 'fusion360 stop' ends leftover Wine services."
      }

      require_stopped_prefix() {
        # Never kill Wine to make an update succeed: that can abort a sign-in.
        timeout 5 "$WINESERVER" -w || fail "Wine is still running in this prefix. Close Fusion and run 'fusion360 stop' first."
      }

      resolve_executable() {
        ${python}/bin/python3 ${pythonSource}/deployment.py resolve "$WINEPREFIX" "$1"
      }

      configure_graphics() {
        local backend="$1"
        local chromium="''${2:-}"

        case "$backend" in
          dxvk | opengl) ;;
          *) fail "Graphics must be dxvk or opengl." ;;
        esac
        case "$chromium" in
          "" | vulkan | opengles | gl) ;;
          *) fail "Chromium graphics must be vulkan, opengles, or gl." ;;
        esac

        # X11 stays explicit on a Wayland desktop. DXVK only ever covers the
        # viewport (D3D11); the navigation cube/bar need Wine's builtin D3D9.
        "$WINE" reg add 'HKCU\Software\Wine\Drivers' /v Graphics /d x11 /f >/dev/null
        "$WINE" reg add 'HKCU\Software\Wine\DllOverrides' /v d3d9 /d builtin /f >/dev/null

        local dll override=builtin
        [[ "$backend" != dxvk ]] || override=native
        for dll in d3d11 dxgi d3d10core; do
          "$WINE" reg add 'HKCU\Software\Wine\DllOverrides' /v "$dll" /d "$override" /f >/dev/null
        done
        ${python}/bin/python3 ${pythonSource}/graphics.py "$WINEPREFIX" "$backend" "$chromium"
        printf '%s\n' "$backend" > "$data_dir/graphics"
      }
    '';
}
