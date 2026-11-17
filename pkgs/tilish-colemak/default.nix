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
    rev = "218aee6317adb29001dbe2e577a80de5b3c80997";
    sha256 = "sha256-mN4ZHrPlfQLQJbDAVnGzha6M6bB0ixhjIjX+7HbxeIk=";
  };

  meta = with lib; {
    homepage = "https://github.com/marnas/tmux-tilish-colemak";
    description = "Colemak version of tmux tilish";
    license = licenses.mit;
    platforms = platforms.unix;
    maintainers = with maintainers; [ marnas ];
  };
}
