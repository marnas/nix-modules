{ ... }:
{

  # Enable and config the mako notification daemon
  services.mako = {
    enable = true;
    settings = {
      actions = true;
      anchor = "top-right";
      background-color = "#2d2a2ec0";
      # border-color = "#33ccffee";
      border-size = 0;
      border-radius = 10;
      font = "Helvetica 11";
      icons = true;
      # margin = 10;
      width = 400;
      padding = 10;
      markup = true;
      default-timeout = 10000;
      ignore-timeout = false;
    };
  };
}
