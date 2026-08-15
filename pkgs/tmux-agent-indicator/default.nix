{
  tmuxPlugins,
  fetchFromGitHub,
  lib,
}:
tmuxPlugins.mkTmuxPlugin {
  pluginName = "agent-indicator";
  # mkTmuxPlugin's default rtpFilePath converts hyphens in pluginName to
  # underscores; upstream ships agent-indicator.tmux so we set this explicitly.
  rtpFilePath = "agent-indicator.tmux";
  version = "unstable-2025-11-30";
  src = fetchFromGitHub {
    owner = "accessd";
    repo = "tmux-agent-indicator";
    rev = "566dda63be1f38efe40528c90c6076a589051df8";
    hash = "sha256-l5ceGR7JVKuiaGobPQyhON0jOjITf77zdWhs/sjk/uw=";
  };

  meta = with lib; {
    homepage = "https://github.com/accessd/tmux-agent-indicator";
    description = "Visual feedback for AI agent states (running / needs-input / done) in tmux";
    license = licenses.mit;
    platforms = platforms.unix;
  };
}
