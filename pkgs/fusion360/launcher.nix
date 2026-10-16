{
  writeShellApplication,
  common,
  installer,
  wine,
  xdg-utils,
  mesa-demos,
  vulkan-tools,
}:
writeShellApplication {
  name = "fusion360";
  runtimeInputs = common.runtimeInputs ++ [
    xdg-utils
    mesa-demos
    vulkan-tools
  ];
  text =
    common.text
    # bash
    + ''
      start_identity_manager() {
        # Fusion signs in through Identity Manager; starting it first and waiting
        # for its "SSO Server is ready" avoids the IDSDK_E_SERVER_PROCESS_NOT_READY
        # race ("Unable to sign in") that a cold start otherwise hits.
        local identity
        identity="$(resolve_executable AdskIdentityManager.exe)"
        ${common.python}/bin/python3 ${common.pythonSource}/identity.py \
          "$WINEPREFIX" "$WINE" "$identity" "$log" "$desktop_size"
      }

      usage() {
        cat <<'EOF'
      Autodesk Fusion through Wine

      Usage: fusion360 [COMMAND] [OPTIONS]

      Commands:
        run [--virtual-desktop WIDTHxHEIGHT] [FILES...]
                               Launch Fusion (default); optionally in a Wine desktop
        install [OPTIONS...]    Install from Autodesk's installer (see install --help)
        update [OPTIONS...]     Update, backing up the stopped prefix first
        uninstall [--yes]       Delete the prefix, downloads and logs
        login URL               Deliver an adskidmgr: browser sign-in callback
        stop                    Gracefully end the Fusion Wine session
        graphics BACKEND [CHROMIUM]
                               Viewport dxvk|opengl; optional Chromium vulkan|opengles|gl
        doctor                  Wine, graphics, installation and login diagnostics

      State (XDG_*_HOME respected; FUSION360_{DATA,CACHE,STATE}_HOME override):
        ~/.local/share/fusion360   Wine prefix and update backups
        ~/.cache/fusion360         Downloaded installers, winetricks cache
        ~/.local/state/fusion360   Logs

      Qt WebEngine's sandbox is disabled for Wine compatibility;
      FUSION360_WEBENGINE_SANDBOX=1 opts out.
      EOF
      }

      command="''${1:-run}"
      (( $# == 0 )) || shift

      case "$command" in
        --help | -h | help)
          usage
          exit 0
          ;;
        install | update) exec ${installer}/bin/fusion360-install "$command" "$@" ;;
        run | login | stop | graphics | doctor | uninstall) ;;
        *) fail "Unknown command: $command. Use 'fusion360 --help'." ;;
      esac

      case "$command" in
        doctor)
          (( $# == 0 )) || fail "doctor takes no arguments."
          echo "Wine: $($WINE --version)"
          echo "Wine package: ${wine}"
          echo "Prefix: $WINEPREFIX"
          echo "Cache: $cache_dir"
          echo "Logs: $state_dir"
          echo "DISPLAY: ''${DISPLAY:-unset}"
          echo "WAYLAND_DISPLAY: ''${WAYLAND_DISPLAY:-unset} (Xwayland is used)"
          echo "Graphics: $(cat "$data_dir/graphics" 2>/dev/null || echo 'dxvk (fresh-install default)')"
          echo "Qt WebEngine sandbox: $([[ -v QTWEBENGINE_DISABLE_SANDBOX ]] && echo 'disabled (Wine compatibility workaround)' || echo 'enabled (explicit opt-in)')"
          echo "Graphics drivers: $(readlink -f /run/opengl-driver 2>/dev/null || echo missing)"
          echo "Login handler: $(xdg-mime query default x-scheme-handler/adskidmgr || true)"
          echo "Fusion executable: $(resolve_executable Fusion360.exe || true)"
          echo "Identity Manager: $(resolve_executable AdskIdentityManager.exe || true)"
          if [[ -n "''${DISPLAY:-}" ]]; then
            glxinfo -B || true
            vulkaninfo --summary || true
          fi
          if [[ -f "$data_dir/installation.json" ]]; then
            cat "$data_dir/installation.json"
          fi
          ;;
        stop)
          (( $# == 0 )) || fail "stop takes no arguments."
          [[ -f "$WINEPREFIX/system.reg" ]] || fail "Install Fusion first."
          require_display
          # The launcher holds a shared lock until Wine exits; exclusive here
          # would refuse to stop the very session that owns it.
          lock_prefix --shared
          echo "Requesting graceful shutdown. Save and close any Fusion documents first."
          "$WINE" wineboot --end-session --shutdown
          timeout 15 "$WINESERVER" -w || fail "Wine did not stop. Close remaining Windows applications; nothing was force-killed."
          echo "Fusion Wine session stopped."
          ;;
        graphics)
          (( $# == 1 || $# == 2 )) || fail "Usage: fusion360 graphics dxvk|opengl [vulkan|opengles|gl]"
          [[ -f "$WINEPREFIX/system.reg" ]] || fail "Install Fusion first."
          require_display
          lock_prefix --exclusive
          require_stopped_prefix
          configure_graphics "$1" "''${2:-}"
          # Registry writes start Wine services even with no application open.
          "$WINE" wineboot --end-session --shutdown
          timeout 15 "$WINESERVER" -w || fail "Graphics changed, but Wine did not stop. Nothing was force-killed."
          echo "Viewport backend set to $1; Qt uses OpenGL."
          [[ -z "''${2:-}" ]] || echo "Chromium backend set to $2."
          ;;
        login)
          (( $# == 1 )) || fail "Usage: fusion360 login 'adskidmgr:/login?code=…'"
          # The URL carries a short-lived credential: no eval, no logging.
          [[ "$1" == adskidmgr:/login\?* || "$1" == adskidmgr://login\?* ]] || fail "Expected an adskidmgr: login callback."
          require_display
          lock_prefix --shared
          executable="$(resolve_executable AdskIdentityManager.exe)"
          cd "$(dirname "$executable")"
          WINEDEBUG=-all "$WINE" "$executable" "$1" >/dev/null 2>&1
          echo "Login callback delivered to Autodesk Identity Manager."
          ;;
        uninstall)
          yes=false
          [[ "''${1:-}" != --yes ]] || yes=true
          if [[ -f "$WINEPREFIX/system.reg" ]]; then
            lock_prefix --exclusive
            require_stopped_prefix
          fi
          echo "This deletes everything under:"
          printf '  %s\n' "$data_dir" "$cache_dir" "$state_dir"
          if [[ "$yes" != true ]]; then
            read -r -p "Continue? [y/N] " answer
            [[ "$answer" == [Yy]* ]] || fail "Aborted."
          fi
          exec 9>&-
          rm -rf "$data_dir" "$cache_dir" "$state_dir"
          echo "Fusion state removed. Desktop entries are declarative; remove the package to drop them."
          ;;
        run)
          desktop_size=""
          if [[ "''${1:-}" == --virtual-desktop ]]; then
            (( $# >= 2 )) || fail "Usage: fusion360 run --virtual-desktop WIDTHxHEIGHT [FILES...]"
            desktop_size="$2"
            [[ "$desktop_size" =~ ^[1-9][0-9]{2,3}x[1-9][0-9]{2,3}$ ]] || fail "Virtual desktop size must be WIDTHxHEIGHT."
            shift 2
          fi

          require_display
          lock_prefix --shared
          executable="$(resolve_executable Fusion360.exe)"
          mkdir -p "$state_dir"
          umask 077
          log="$state_dir/run-$(date +%Y%m%dT%H%M%S)-$$.log"
          echo "Launching Fusion. Log: $log"

          # Convert file arguments before changing into Fusion's directory.
          files=()
          for argument in "$@"; do
            file="$(realpath -e "$argument")"
            files+=("$($WINE winepath -w "$file" | tr -d '\r')")
          done

          start_identity_manager
          cd "$(dirname "$executable")"

          rc=0
          if [[ -n "$desktop_size" ]]; then
            windows_executable="$($WINE winepath -w "$executable" | tr -d '\r')"
            "$WINE" explorer "/desktop=Fusion360,$desktop_size" "$windows_executable" "''${files[@]}" >>"$log" 2>&1 || rc=$?
          else
            "$WINE" "$executable" "''${files[@]}" >>"$log" 2>&1 || rc=$?
          fi

          # Keep the shared lock while GUI children live. Never kill wineserver
          # here: that could abort a sign-in or an unsaved document.
          "$WINESERVER" -w
          exit "$rc"
          ;;
      esac
    '';
}
