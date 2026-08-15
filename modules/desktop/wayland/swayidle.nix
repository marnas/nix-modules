{ pkgs, ... }:
let
  swaylock = "${pkgs.swaylock-effects}/bin/swaylock";
  pgrep = "${pkgs.procps}/bin/pgrep";

  lockCommand = "${swaylock} --screenshots --effect-blur 7x5 --fade-in 0.2 --font Roboto --font-size 20 -f";
  dpmsOff = "${pkgs.hyprland}/bin/hyprctl dispatch dpms off";
  dpmsOn = "${pkgs.hyprland}/bin/hyprctl dispatch dpms on";
  isLocked = "${pgrep} -x ${swaylock}";
in
{
  services.swayidle = {
    enable = true;
    timeouts = [
      {
        timeout = 600;
        command = lockCommand;
      }
      {
        timeout = 620;
        command = dpmsOff;
        resumeCommand = dpmsOn;
      }
      # Fires within the lock-to-dpms window if the session was locked manually
      {
        timeout = 20;
        command = "${isLocked} && ${dpmsOff}";
        resumeCommand = dpmsOn;
      }
    ];
    events = {
      before-sleep = lockCommand;
      after-resume = dpmsOn;
    };
  };
}
