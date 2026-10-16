{
  lib,
  writeShellApplication,
  common,
  wine,
  winetricks,
  curl,
  dxvk,
}:
# Prefix recipe: the Lolig4 installer's September 2026 steps (winetricks verbs,
# registry overrides, WebView2, DeviceSettingsProvider fix), done the way the
# lukasl-dev flake does them - resumable per-step markers, DXVK from nixpkgs
# instead of a download, and Fusion's options file edited in place rather than
# replaced (upstream's copy also switches TLS verification off).
writeShellApplication {
  name = "fusion360-install";
  runtimeInputs = common.runtimeInputs ++ [
    winetricks
    curl
  ];
  text =
    common.text
    # bash
    + ''
      usage() {
        cat <<'EOF'
      Usage: fusion360 install [--graphics dxvk|opengl] [--installer FILE]
             fusion360 update [--installer FILE] [--no-backup]

      Installs Fusion from Autodesk's own installer into a dedicated Wine prefix.
      A fresh install defaults to DXVK for the viewport (OpenGL for Qt and
      Chromium). Update backs up the stopped prefix first. Sign-in is interactive.
      EOF
      }

      # Nixpkgs' full Wine is a shell wrapper; winetricks would otherwise take it
      # for an unknown architecture and look for a wine64 binary.
      export WINE64="$WINE"
      if [[ -x "${wine}/bin/.wine" ]]; then
        export WINE_BIN="${wine}/bin/.wine"
      fi

      operation="''${1:-install}"
      shift || true
      backend="''${FUSION360_GRAPHICS:-}"
      installer=""
      backup=true

      while (( $# )); do
        case "$1" in
          --help | -h)
            usage
            exit 0
            ;;
          --graphics)
            (( $# >= 2 )) || fail "--graphics requires a backend."
            backend="$2"
            shift 2
            ;;
          --installer)
            (( $# >= 2 )) || fail "--installer requires a file."
            installer="$(realpath -e "$2")"
            shift 2
            ;;
          --no-backup)
            backup=false
            shift
            ;;
          *) fail "Unknown install option: $1" ;;
        esac
      done

      case "$operation" in
        install | update) ;;
        *) fail "Unknown operation: $operation" ;;
      esac

      # An update keeps the prefix's backend unless told otherwise.
      if [[ -z "$backend" && -f "$data_dir/graphics" ]]; then
        backend="$(cat "$data_dir/graphics")"
      fi
      backend="''${backend:-dxvk}"
      case "$backend" in
        dxvk | opengl) ;;
        *) fail "Graphics must be dxvk or opengl." ;;
      esac

      require_display
      lock_prefix --exclusive
      if [[ -f "$data_dir/setup/prefix" && ! -f "$WINEPREFIX/system.reg" ]]; then
        fail "Setup markers exist but the Wine prefix is missing. Restore the prefix or use a fresh FUSION360_DATA_HOME."
      fi

      if [[ -f "$data_dir/installation.json" && "$operation" == install ]]; then
        compgen -G "$WINEPREFIX/drive_c/Program Files/Autodesk/webdeploy/production/*/Fusion360.exe" >/dev/null \
          || fail "Installation metadata exists but Fusion is missing. Use 'fusion360 update' to repair it."
        echo "Fusion is already installed. Use 'fusion360 update' to update it."
        exit 0
      fi
      if [[ "$operation" == update && ! -f "$data_dir/installation.json" ]]; then
        fail "Fusion is not installed. Use 'fusion360 install' first."
      fi

      mkdir -p "$cache_dir" "$state_dir" "$data_dir/setup"
      umask 077
      log="$state_dir/$operation-$(date +%Y%m%dT%H%M%S)-$$.log"
      echo "Installation log: $log"
      exec > >(tee -a "$log") 2>&1

      report_failure() {
        local rc=$?
        if (( rc != 0 )); then
          echo "Installation stopped (exit $rc). See $log; rerun to resume." >&2
        fi
      }
      trap report_failure EXIT

      if [[ -f "$WINEPREFIX/system.reg" ]]; then
        require_stopped_prefix
      fi

      if [[ "$operation" == update && "$backup" == true ]]; then
        snapshot="$data_dir/backups/$(date +%Y%m%dT%H%M%S)-$$"
        echo "Backing up the stopped prefix to $snapshot"
        mkdir -p "$snapshot"
        cp --archive --reflink=auto "$WINEPREFIX" "$snapshot/prefix"
        cp "$data_dir/installation.json" "$snapshot/installation.json"
        cp "$data_dir/graphics" "$snapshot/graphics"
      fi

      download() {
        local url="$1" destination="$2"
        curl --fail --location --retry 3 --connect-timeout 30 --silent --show-error \
          --proto '=https' --proto-redir '=https' "$url" --output "$destination.part"
        mv "$destination.part" "$destination"
      }

      if [[ ! -f "$data_dir/setup/prefix" ]]; then
        ${wine}/bin/wineboot --init
        "$WINESERVER" -w
        touch "$data_dir/setup/prefix"
      fi

      # Drop the Z: drive and the profile folders' links into $HOME, so the
      # Windows installers cannot write outside the prefix.
      if [[ ! -f "$data_dir/setup/sandbox" ]]; then
        winetricks -q sandbox
        "$WINESERVER" -w
        touch "$data_dir/setup/sandbox"
      fi
      # Without Z: a Unix path is unreachable from Windows; expose the download
      # cache as C:\fusion-cache instead.
      ln -sfn "$cache_dir" "$WINEPREFIX/drive_c/fusion-cache"

      # Each verb is recorded only after it succeeded, so a failed download resumes.
      # gdiplus/arial/verdana/dotnet48/fontsmooth/winhttp: upstream's lean set
      # (the full corefonts+cjkfonts pack is only needed for CJK locales).
      # d3dcompiler_47: Wine's HLSL compiler cannot build Fusion Electronics' shaders.
      if [[ ! -f "$data_dir/setup/dependencies-v1" ]]; then
        for verb in gdiplus arial verdana dotnet48 fontsmooth=rgb winhttp d3dcompiler_47; do
          marker="$data_dir/setup/verb-''${verb//=/-}"
          [[ ! -f "$marker" ]] || continue
          echo "Installing Wine dependency: $verb"
          winetricks -q "$verb"
          "$WINESERVER" -w
          touch "$marker"
        done
        touch "$data_dir/setup/dependencies-v1"
      fi

      # Some verbs reset the Windows version; set it last.
      winetricks -q win11

      reg() { "$WINE" reg add "$@" /f >/dev/null; }
      # Autodesk's telemetry service never starts.
      reg 'HKCU\Software\Wine\DllOverrides' /v adpclientservice.exe /d native
      # The navigation bar only works with Wine's builtin browser host.
      reg 'HKCU\Software\Wine\DllOverrides' /v AdCefWebBrowser.exe /d builtin
      # Wine's msvcp140 lacks std::get_new_handler and Fusion aborts at start;
      # use the redistributable Fusion bundles.
      reg 'HKCU\Software\Wine\DllOverrides' /v msvcp140 /d native,builtin
      # Login breaks with Wine's bcp47langs stub loaded.
      reg 'HKCU\Software\Wine\DllOverrides' /v bcp47langs /d ""
      reg 'HKCU\Software\Wine\X11 Driver' /v Managed /d Y
      reg 'HKCU\Software\Wine\X11 Driver' /v Decorated /d Y

      if [[ ! -f "$data_dir/setup/webview2" ]]; then
        webview="$cache_dir/MicrosoftEdgeWebView2RuntimeInstallerX64.exe"
        [[ -f "$webview" ]] || download 'https://go.microsoft.com/fwlink/?linkid=2124701' "$webview"
        "$WINE" 'C:\fusion-cache\MicrosoftEdgeWebView2RuntimeInstallerX64.exe' /silent /install
        # The offline installer leaves its updater resident; stop only that.
        "$WINE" taskkill /IM MicrosoftEdgeUpdate.exe /F >/dev/null 2>&1 || true
        "$WINESERVER" -w
        touch "$data_dir/setup/webview2"
      fi

      # DXVK from nixpkgs: only the D3D11/DXGI pair, D3D9 stays builtin.
      for arch in x64 x32; do
        target=system32
        [[ "$arch" != x32 ]] || target=syswow64
        for dll in d3d10core d3d11 dxgi; do
          install -m 644 "${lib.getBin dxvk}/$arch/$dll.dll" "$WINEPREFIX/drive_c/windows/$target/$dll.dll"
        done
      done
      configure_graphics "$backend"
      "$WINESERVER" -w

      if [[ -z "$installer" ]]; then
        installer="$cache_dir/Fusion Admin Install.exe"
        # Mutable URL: the installed bytes are recorded, not a pretend version pin.
        download 'https://dl.appstreaming.autodesk.com/production/installers/Fusion%20Admin%20Install.exe' "$installer"
      elif [[ "$installer" != "$cache_dir/Fusion Admin Install.exe" ]]; then
        install -m 644 "$installer" "$cache_dir/Fusion Admin Install.exe"
      fi
      [[ "$(head -c 2 "$cache_dir/Fusion Admin Install.exe")" == MZ ]] || fail "Not a Windows executable: $installer"

      echo "Running Autodesk's installer ($operation)..."
      arguments=(--quiet)
      [[ "$operation" != update ]] || arguments+=(--process update)
      rc=0
      timeout 30m "$WINE" 'C:\fusion-cache\Fusion Admin Install.exe' "''${arguments[@]}" || rc=$?
      (( rc == 0 || rc == 124 )) || echo "Autodesk installer exited with $rc; checking what it left behind."
      "$WINE" taskkill /IM MicrosoftEdgeUpdate.exe /F >/dev/null 2>&1 || true

      # Ask the Windows session to end so service-only processes release the
      # prefix; nothing is force-killed.
      "$WINE" wineboot --end-session --shutdown
      "$WINESERVER" -w

      # Fusion loads DeviceSettingsProvider.dll one level above ADPCER/, where
      # the installer puts it; missing, every start pops a crash-report dialog.
      production="$WINEPREFIX/drive_c/Program Files/Autodesk/webdeploy/production"
      while IFS= read -r dll; do
        expected="$(dirname "$(dirname "$dll")")/DeviceSettingsProvider.dll"
        [[ -e "$expected" ]] || ln -s "$dll" "$expected"
      done < <(find "$production" -path '*/ADPCER/DeviceSettingsProvider.dll' 2>/dev/null)

      configure_graphics "$backend"
      "$WINESERVER" -w

      echo "Checking installed files..."
      executable="$(resolve_executable Fusion360.exe)"
      identity="$(resolve_executable AdskIdentityManager.exe)"
      echo "Active Fusion: $executable"
      echo "Identity Manager: $identity"

      ${common.python}/bin/python3 ${common.pythonSource}/deployment.py record \
        "$WINEPREFIX" "$data_dir" "$cache_dir/Fusion Admin Install.exe" "${wine.version}"
      echo "Installation completed. Run 'fusion360' and sign in with your Autodesk account."
    '';
}
