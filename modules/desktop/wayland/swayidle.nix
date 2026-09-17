{ pkgs, ... }:
let
  swaylock = "${pkgs.swaylock-effects}/bin/swaylock";
  pgrep = "${pkgs.procps}/bin/pgrep";

  # pgrep -x matches the 15-char comm field, so pass the bare name, not the store path
  isLocked = "${pgrep} -x swaylock";
  # Never start a second swaylock. It grabs its screenshots via wlr-screencopy
  # *before* locking, and a DPMS-off output never renders, so the copy never
  # completes and swaylock blocks forever. swayidle runs with -w and waits on
  # it, so the whole idle loop wedges: no resume, no dpms on, black screens
  # until reboot. Happens whenever the lock timer re-fires while already
  # locked + DPMS off (woke the screen but didn't unlock, or before-sleep).
  lockCommand = pkgs.writeShellScript "lock" ''
    ${isLocked} >/dev/null && exit 0
    exec ${swaylock} --screenshots --effect-blur 7x5 --fade-in 0.2 --font Roboto --font-size 20 -f
  '';
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
in
{
  services.swayidle = {
    enable = true;
    timeouts = [
      {
        timeout = 600;
        command = "${lockCommand}";
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
      # `loginctl lock-session` (control-center Lock button, swaync.nix)
      lock = "${lockCommand}";
      before-sleep = "${lockCommand}";
      after-resume = "${dpmsOn}";
    };
  };
}
