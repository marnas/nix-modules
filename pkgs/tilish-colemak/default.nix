{
  tmuxPlugins,
  fetchFromGitHub,
  lib,
}:
tmuxPlugins.mkTmuxPlugin {
  pluginName = "tilish-colemak";
  rtpFilePath = "tilish.tmux";
  version = "unstable-2023-05-12";
  src = fetchFromGitHub {
    owner = "marnas";
    repo = "tmux-tilish-colemak";
    rev = "304206474734db2d5b1e773697f83d40a449b833";
    sha256 = "sha256-PIANPBgiABHFYhQ9crB2a3pqsVhSf9hzVWINQWzvTCE=";
  };

  meta = with lib; {
    homepage = "https://github.com/marnas/tmux-tilish-colemak";
    description = "Colemak version of tmux tilish";
    license = licenses.mit;
    platforms = platforms.unix;
    maintainers = with maintainers; [ marnas ];
  };
}
