{
  pkgs,
  nixModulesInputs,
  lib,
  ...
}:

{
  programs.browserpass.enable = true;
  programs.firefox = {
    enable = true;
    # On macOS, Firefox is installed via Homebrew cask (hosts/macos/brew.nix);
    # the nixpkgs package isn't cached for aarch64-darwin and would build from
    # source. null lets home-manager manage the profile/policies only.
    package = lib.mkIf pkgs.stdenv.isDarwin null;
    configPath =
      if pkgs.stdenv.isDarwin then "Library/Application Support/Firefox" else ".mozilla/firefox";

    # Enable arkenfox privacy and security settings
    arkenfox = {
      enable = true;
      version = "master";
    };

    profiles.marnas = {
      # Enable arkenfox for this profile
      arkenfox = {
        enable = true;
        # Enable all sections for comprehensive privacy protection
        # You can disable specific sections if needed
        "0000".enable = true; # FASTFOX
        "0100".enable = true; # STARTUP
        "0200".enable = true; # GEOLOCATION
        "0300".enable = true; # QUIETER FOX
        "0400".enable = true; # SAFE BROWSING
        "0600".enable = true; # BLOCK IMPLICIT OUTBOUND
        "0700".enable = true; # DNS / DoH / PROXY / SOCKS
        "0800".enable = true; # LOCATION BAR / SEARCH BAR / SUGGESTIONS
        "0900".enable = true; # PASSWORDS
        "1000".enable = true; # DISK AVOIDANCE
        "1200".enable = true; # HTTPS (SSL/TLS / OCSP / CERTS / HPKP)
        "1600".enable = true; # REFERERS
        "1700".enable = true; # CONTAINERS
        "2000".enable = true; # PLUGINS / MEDIA / WEBRTC
        "2400".enable = true; # DOM (DOCUMENT OBJECT MODEL)
        "2600".enable = true; # MISCELLANEOUS
        "2700".enable = true; # ETP (ENHANCED TRACKING PROTECTION)
        "4500".enable = true; # RFP (RESIST FINGERPRINTING)
        "5000".enable = true; # OPTIONAL OPSEC
        "5500".enable = true; # OPTIONAL HARDENING
        "6000".enable = true; # DON'T TOUCH
        "7000".enable = true; # DON'T BOTHER
        "8000".enable = true; # DON'T BOTHER: FINGERPRINTING
        "9000".enable = true; # NON-PROJECT RELATED
      };

      search = {
        force = true;
        default = "ddg";
        privateDefault = "ddg";
        order = [ "ddg" ];
        engines = {
          bing.metaData.hidden = true;
        };
      };
      extensions.packages =
        with nixModulesInputs.firefox-addons.packages.${pkgs.stdenv.hostPlatform.system}; [
          canvasblocker
          decentraleyes
          floccus
          istilldontcareaboutcookies
          libredirect
          multi-account-containers
          privacy-badger
          return-youtube-dislikes
          skip-redirect
          sponsorblock
          temporary-containers
          # translate-web-pages removed: TWP injects translated text nodes next to the
          # originals, which doubles every label/amount on dynamic apps
          # when the translation equals the source. Firefox's built-in local translator
          # covers the use case without cloud calls.
          ublock-origin
          vimium
        ];
      settings = {
        # "browser.startup.homepage" = "about:blank";
        "browser.startup.homepage" = lib.mkForce "about:home";
        "browser.startup.page" = lib.mkForce 1; # 1 = homepage (overrides arkenfox which sets 0 = blank)
        "general.autoScroll" = true;

        # Built-in translator: keep available on demand, but never offer/translate
        # automatically (auto-translation mangles dynamic web apps).
        "browser.translations.automaticallyPopup" = false;

        # GTK emoji picker (Firefox 150+) grabs Ctrl+. in text fields,
        # shadowing the 1Password quick-access shortcut.
        "widget.gtk.native-emoji-dialog" = false;

        # Performance optimizations
        "gfx.webrender.all" = true;
        "media.ffmpeg.vaapi.enabled" = true;
        "media.hardware-video-decoding.enabled" = true;
        "layers.acceleration.force-enabled" = true;
        # "browser.cache.disk.enable" = true;
        # "browser.cache.memory.enable" = true;
        "browser.sessionhistory.max_total_viewers" = 4;
        "network.http.pipelining" = true;
        "network.http.proxy.pipelining" = true;

        # Disable irritating first-run stuff
        "browser.disableResetPrompt" = true;
        "browser.download.panel.shown" = true;
        "browser.feeds.showFirstRunUI" = false;
        "browser.messaging-system.whatsNewPanel.enabled" = false;
        "browser.rights.3.shown" = true;
        "browser.shell.checkDefaultBrowser" = false;
        "browser.shell.defaultBrowserCheckCount" = 1;
        "browser.startup.homepage_override.mstone" = "ignore";
        "browser.uitour.enabled" = false;
        "startup.homepage_override_url" = "";
        "startup.homepage_welcome_url" = "about:blank";
        "trailhead.firstrun.didSeeAboutWelcome" = true;
        "browser.bookmarks.restore_default_bookmarks" = false;
        "browser.bookmarks.addedImportButton" = true;

        # Don't ask for download dir
        "browser.download.useDownloadDir" = false;

        # Disable crappy home activity stream page
        "browser.newtabpage.activity-stream.feeds.topsites" = false;
        "browser.newtabpage.activity-stream.showSponsoredTopSites" = false;
        "browser.newtabpage.activity-stream.improvesearch.topSiteSearchShortcuts" = false;
        "browser.newtabpage.blocked" = lib.genAttrs [
          # Youtube
          "26UbzFJ7qT9/4DhodHKA1Q=="
          # Facebook
          "4gPpjkxgZzXPVtuEoAL9Ig=="
          # Wikipedia
          "eV8/WsSLxHadrTL1gAxhug=="
          # Reddit
          "gLv0ja2RYVgxKdp0I5qwvA=="
          # Amazon
          "K00ILysCaEq8+bEqV/3nuw=="
          # Twitter
          "T9nJot5PurhJSy8n038xGA=="
        ] (_: 1);

        # Disable some telemetry
        "app.shield.optoutstudies.enabled" = false;
        "browser.discovery.enabled" = false;
        "browser.newtabpage.activity-stream.feeds.telemetry" = false;
        "browser.newtabpage.activity-stream.telemetry" = false;
        "browser.ping-centre.telemetry" = false;
        "datareporting.healthreport.service.enabled" = false;
        "datareporting.healthreport.uploadEnabled" = false;
        "datareporting.policy.dataSubmissionEnabled" = false;
        "datareporting.sessions.current.clean" = true;
        "devtools.onboarding.telemetry.logged" = false;
        "toolkit.telemetry.archive.enabled" = false;
        "toolkit.telemetry.bhrPing.enabled" = false;
        "toolkit.telemetry.enabled" = false;
        "toolkit.telemetry.firstShutdownPing.enabled" = false;
        "toolkit.telemetry.hybridContent.enabled" = false;
        "toolkit.telemetry.newProfilePing.enabled" = false;
        "toolkit.telemetry.prompted" = 2;
        "toolkit.telemetry.rejected" = true;
        "toolkit.telemetry.reportingpolicy.firstRun" = false;
        "toolkit.telemetry.server" = "";
        "toolkit.telemetry.shutdownPingSender.enabled" = false;
        "toolkit.telemetry.unified" = false;
        "toolkit.telemetry.unifiedIsOptIn" = false;
        "toolkit.telemetry.updatePing.enabled" = false;

        "extensions.openPopupWithoutUserGesture.enabled" = true;

        # Disable fx accounts
        "identity.fxaccounts.enabled" = false;
        # Disable "save password" prompt
        "signon.rememberSignons" = false;
        # Harden
        "privacy.trackingprotection.enabled" = true;
        "dom.security.https_only_mode" = true;
        # Layout
        "browser.uidensity" = 1;
        "browser.uiCustomization.state" = builtins.toJSON {
          currentVersion = 20;
          newElementCount = 5;
          dirtyAreaCache = [
            "nav-bar"
            "PersonalToolbar"
            "toolbar-menubar"
            "TabsToolbar"
            "widget-overflow-fixed-list"
          ];
          placements = {
            PersonalToolbar = [ "personal-bookmarks" ];
            TabsToolbar = [
              "tabbrowser-tabs"
              "new-tab-button"
            ];
            nav-bar = [
              "back-button"
              "forward-button"
              "vertical-spacer"
              "stop-reload-button"
              "urlbar-container"
              "downloads-button"
              "ublock0_raymondhill_net-browser-action"
              "_d634138d-c276-4fc8-924b-40a0ea21d284_-browser-action"
              # "unified-extensions-button"
            ];
            toolbar-menubar = [ "menubar-items" ];
            unified-extensions-area = [ ];
            widget-overflow-fixed-list = [ ];
          };
          seen = [
            "save-to-pocket-button"
            "developer-button"
            "ublock0_raymondhill_net-browser-action"
            "_testpilot-containers-browser-action"
          ];
        };
      };
    };
  };
}
