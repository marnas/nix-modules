{ ... }:
{
  programs.yazi = {
    enable = true;
    shellWrapperName = "y";
    settings = {
      opener = {
        play = [
          {
            run = ''vlc "$@"'';
            desc = "VLC";
            orphan = true;
          }
        ];
      };
      open = {
        rules = [
          {
            mime = "video/*";
            use = [
              "play"
              "reveal"
            ];
          }
        ];
      };
    };
  };
}
