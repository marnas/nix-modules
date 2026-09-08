# Custom packages, nixpkgs-style. Build with 'nix build .#<name>'.
{
  pkgs ? import <nixpkgs> { },
}:
{
  claude-tasks = pkgs.callPackage ./claude-tasks { };
  claude-usage = pkgs.callPackage ./claude-usage { };
  tilish-colemak = pkgs.callPackage ./tilish-colemak { };
  tmux-agent-indicator = pkgs.callPackage ./tmux-agent-indicator { };
}
