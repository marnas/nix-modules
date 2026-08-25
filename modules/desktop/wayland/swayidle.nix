{ pkgs, ... }:
let
  swaylock = "${pkgs.swaylock-effects}/bin/swaylock";
  pgrep = "${pkgs.procps}/bin/pgrep";

  lockCommand = "${swaylock} --screenshots --effect-blur 7x5 --fade-in 0.2 --font Roboto --font-size 20 -f";
  # With configType = "lua", `hyprctl dispatch` evaluates its argument as a
  # Lua dispatcher expression — the old hyprlang `dpms off` syntax is a Lua
  # syntax error. Wrapped in scripts so the quoting survives escapeShellArgs
  # + systemd ExecStart parsing + swayidle's `sh -c`.
  dpmsOff = pkgs.writeShellScript "dpms-off" ''
    exec ${pkgs.hyprland}/bin/hyprctl dispatch 'hl.dsp.dpms({ action = "off" })'
  '';
  dpmsOn = pkgs.writeShellScript "dpms-on" ''
    exec ${pkgs.hyprland}/bin/hyprctl dispatch 'hl.dsp.dpms({ action = "on" })'
  '';
  # pgrep -x matches the 15-char comm field, so pass the bare name, not the store path
  isLocked = "${pgrep} -x swaylock";
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
        command = "${dpmsOff}";
        resumeCommand = "${dpmsOn}";
      }
      # Fires within the lock-to-dpms window if the session was locked manually
      {
        timeout = 20;
        command = "${isLocked} && ${dpmsOff}";
        resumeCommand = "${dpmsOn}";
      }
    ];
    events = {
      before-sleep = lockCommand;
      after-resume = "${dpmsOn}";
    };
  };
}
