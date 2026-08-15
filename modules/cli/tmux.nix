{ pkgs, ... }:
let
  terminal = if pkgs.stdenv.hostPlatform.isDarwin then "xterm-256color" else "alacritty";
  # System-clipboard copy command for copy-mode yanks (absolute path so it
  # resolves inside tmux's copy-pipe shell regardless of PATH).
  clipCmd =
    if pkgs.stdenv.hostPlatform.isDarwin then "pbcopy" else "${pkgs.wl-clipboard}/bin/wl-copy";
  tuiApps = [
    "jellyfin-tui"
    "yazi"
    "lazygit"
    "btop"
    "htop"
    "ssh"
    "man"
  ];
  tuiAppsRegex = builtins.concatStringsSep "|" tuiApps;
in
{
  programs.tmux = {
    enable = true;
    mouse = true;
    escapeTime = 10;
    baseIndex = 1;
    keyMode = "vi";
    sensibleOnTop = if pkgs.stdenv.hostPlatform.isDarwin then false else true;
    terminal = "tmux-256color";
    historyLimit = 100000;
    plugins = with pkgs; [
      {
        plugin = tilish-colemak;
        extraConfig = ''
          set -g @tilish-default 'main-vertical'
          set -g @tilish-colemak 'on'
          set -g @tilish-navigator 'on'
        '';
      }
      tmuxPlugins.better-mouse-mode
      tmuxPlugins.vim-tmux-navigator
      # Nord color scheme (matches the agent-indicator demo aesthetic).
      tmuxPlugins.nord
      {
        plugin = tmux-agent-indicator;
        extraConfig = ''
          # No full-width status-bar flash on transitions; the pane border +
          # animated indicator is signal enough.
          set -g @agent-indicator-notification-enabled off
          # Spinner on the @agent_indicator token while an agent is running.
          set -g @agent-indicator-animation-enabled on

          # Status format MUST be set here, before agent-indicator loads, so its
          # token-substitution pass rewrites #{agent_*} into the script calls.
          # If set inside minimal-tmux-status's extraConfig it lands too late.
          # The #(...) usage widget (Claude 5h-block % + reset, shared across all
          # panes) is left untouched by that pass and evaluated by tmux itself on
          # each status redraw — see pkgs/claude-usage.
          set -g @minimal-tmux-status-right '#{agent_session_dots} #{agent_indicator} #[fg=#EBCB8B]#(${pkgs.claude-usage}/bin/claude-usage)#[default] #[bold]#h  '
        '';
      }
      # Minimal status bar that consumes @agent_indicator / @agent_session_dots.
      # Loaded after agent-indicator so token substitution has already happened.
      {
        plugin = tmuxPlugins.minimal-tmux-status;
        extraConfig = ''
          set -g @minimal-tmux-justify 'left'
        '';
      }
    ];
    extraConfig = ''
      bind -n S-Up resize-pane -U 5
      bind -n S-Down resize-pane -D 5
      bind -n S-Left resize-pane -L 5
      bind -n S-Right resize-pane -R 5

      # Prefix-less copy-mode (tilish is all Alt). vim-style visual selection:
      # M-Space to enter, v/V/C-v to select, motions to extend, y to yank
      # straight to the system clipboard and exit.
      bind -n M-Space copy-mode
      bind -T copy-mode-vi v   send -X begin-selection
      bind -T copy-mode-vi C-v send -X rectangle-toggle
      bind -T copy-mode-vi y   send -X copy-pipe-and-cancel "${clipCmd}"
      bind -T copy-mode-vi Y   send -X copy-line-and-cancel  "${clipCmd}"

      # Mouse drag-release: copy to clipboard without cancelling copy-mode. The
      # default MouseDragEnd1Pane binding is copy-pipe-and-cancel, and leaving
      # copy-mode snaps the view back to the live bottom — annoying when you've
      # scrolled up to grab text. copy-pipe keeps scroll position; q/Esc exits.
      bind -T copy-mode-vi MouseDragEnd1Pane send -X copy-pipe "${clipCmd}"

      set-option -g focus-events on

      set-option -ga terminal-overrides ",${terminal}:Tc"

      # Window names reflect the active pane's cwd basename (e.g. ".dotfiles")
      # instead of the current command. allow-rename off blocks OSC 0/2 escapes
      # so TUIs like Claude can't freeze the name by setting a title.
      set -g allow-rename off
      set -g automatic-rename-format '#{?#{m/r:^(${tuiAppsRegex})$,#{pane_current_command}},#{pane_current_command},#{b:pane_current_path}}'

      # Pane borders: nord palette, heavy lines, bold red active border.
      set -g pane-border-style 'fg=#4C566A'
      set -g pane-active-border-style 'fg=#BF616A,bold'
      set -g pane-border-lines heavy
      set -g pane-border-indicators arrows

      # status-right is overridden by minimal-tmux-status via
      # @minimal-tmux-status-right (see plugin block below). Refresh it on an
      # interval so the embedded claude-usage widget (block % + reset
      # countdown) updates; these redraws are also what triggers its
      # self-refresh of the usage cache. Minute-granularity data, 15s is ample.
      set -g status-interval 15

      # minimal-tmux-status never sets status-right-length, so tmux's default of
      # 40 applies — too short once the ~31-char usage widget renders, which
      # truncates the rightmost field (the hostname). Give it ample room for
      # agent dots + indicator + usage + host.
      set -g status-right-length 150

      # new shortcut to clean terminal
      bind -n C-p send-keys C-l
        
      # to forward Ctrl-Tab
      # set -g extended-keys on
    '';
  };
}
