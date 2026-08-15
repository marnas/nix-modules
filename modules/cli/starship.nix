{ lib, ... }:
{
  programs.starship = {
    enable = true;
    enableFishIntegration = true;
    settings = {
      format = lib.concatStrings [
        "$username"
        "$hostname"
        "$directory"
        "$git_branch"
        "$git_status"
        "$aws"
        "$kubernetes"
        "$line_break"
        "$status"
        "$shell"
        "$character"
      ];
      kubernetes = {
        disabled = false;
        format = "[$symbol$context( )]($style) ";
        symbol = " ";
        style = "bold blue";
        contexts = [
          {
            context_pattern = "cdk-eks-prod";
            style = "red bold";
          }
          {
            context_pattern = "cdk-gke-prod";
            style = "red bold";
          }
        ];
      };
      aws = {
        disabled = false;
        format = "[$symbol$profile]($style) ";
        style = "bold yellow";
        symbol = "󰅟 ";
      };
    };
  };
}
