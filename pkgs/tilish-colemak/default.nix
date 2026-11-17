{
  tmuxPlugins,
  fetchFromGitHub,
  lib,
}:
tmuxPlugins.mkTmuxPlugin {
  pluginName = "tilish-colemak";
  rtpFilePath = "tilish.tmux";
  version = "unstable-2026-11-17";
  src = fetchFromGitHub {
    owner = "marnas";
    repo = "tmux-tilish-colemak";
    rev = "ea046d9915b33c970eb338fd334702297e16b1fe";
    sha256 = "sha256-uoTwLe+JCS+EUIBMqc+uXnnCqmuj7y6eD3euGzRlgE4=";
  };

  meta = with lib; {
    homepage = "https://github.com/marnas/tmux-tilish-colemak";
    description = "Colemak version of tmux tilish";
    license = licenses.mit;
    platforms = platforms.unix;
    maintainers = with maintainers; [ marnas ];
  };
}
