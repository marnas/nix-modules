{
  pkgs,
  lib,
  config,
  ...
}:
let
  inherit (lib) mkIf;
  packageNames = map (p: p.pname or p.name or null) config.home.packages;
  hasPackage = name: lib.any (x: x == name) packageNames;
  hasBat = hasPackage "bat";
  hasEza = hasPackage "eza";
  hasGit = hasPackage "git";
  hasKubectl = hasPackage "kubectl";
  hasTerraform = hasPackage "terraform";
in
{
  programs.fish = {
    enable = true;
    shellAbbrs = {

      n = "nix";
      nd = "nix develop -c $SHELL";
      ns = "nix shell";
      nsn = "nix shell nixpkgs#";
      nb = "nix build";
      nbn = "nix build nixpkgs#";
      nf = "nix flake";

      # Git abbreviations
      ga = mkIf hasGit "git add";
      gc = mkIf hasGit "git commit -m";
      gd = mkIf hasGit "git diff";

    };
    shellAliases = {
      # Clear screen and scrollback
      cls = "printf '\\033[2J\\033[3J\\033[1;1H'";

      cat = mkIf hasBat "bat";
      ls = mkIf hasEza "eza";
      k = mkIf hasKubectl "kubectl";
      tf = mkIf hasTerraform "terraform";

      # Claude
      c = "claude";
      ca = "claude --permission-mode auto";
      cr = "claude --resume";

      # Git aliases
      g = mkIf hasGit "git";
      gst = mkIf hasGit "git status";
      gcm = mkIf hasGit "git checkout main";
      gdf = mkIf hasGit "git diff :!flake.lock";

    };
    plugins = [
      {
        name = "z";
        src = pkgs.fishPlugins.z.src;
      }
    ];
    functions = {
      # Disable greeting
      fish_greeting = "";

      # Delete all local branches except main/master
      gbclean = ''
        set -l keep (git branch --format '%(refname:short)' | string match -r '^(main|master)$' | head -n1)
        if test -z "$keep"
          echo "gbclean: no main or master branch found" >&2
          return 1
        end
        git branch --format '%(refname:short)' | string match -v $keep | while read -l branch
          git branch -D $branch
        end
      '';
    };
    interactiveShellInit = ''
      bind \ey edit_command_buffer
      fish_vi_key_bindings
      set fish_cursor_default block blink
      set fish_cursor_insert block blink
      set fish_cursor_replace_one underscore
      set fish_cursor_visual block
      # Fish syntax highlighting colors (mirrored from Linux)
      set -g fish_color_autosuggestion brblack
      set -g fish_color_cancel -r
      set -g fish_color_command blue
      set -g fish_color_comment red
      set -g fish_color_cwd green
      set -g fish_color_cwd_root red
      set -g fish_color_end green
      set -g fish_color_error brred
      set -g fish_color_escape brcyan
      set -g fish_color_history_current --bold
      set -g fish_color_host normal
      set -g fish_color_host_remote yellow
      set -g fish_color_normal normal
      set -g fish_color_operator brcyan
      set -g fish_color_param cyan
      set -g fish_color_quote yellow
      set -g fish_color_redirection cyan --bold
      set -g fish_color_search_match white --background=brblack
      set -g fish_color_selection white --bold --background=brblack
      set -g fish_color_status red
      set -g fish_color_user brgreen
      set -g fish_color_valid_path --underline
      # TODO: Remove sed workaround once atuin fixes fish 4.0+ compatibility (deprecated -k flag)
      if command -q atuin
        atuin init fish | sed 's/-k up/up/' | source
      end
    '';
  };
}
