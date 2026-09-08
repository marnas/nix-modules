{
  writeShellApplication,
  jq,
  ncurses,
}:
# Live, full-length view of Claude Code's task list (the TaskCreate/TaskUpdate
# checklist stored as ~/.claude/tasks/<list>/N.json). Claude Code's own Ctrl+T
# view caps at five rows and folds completed items into "+N completed"; this
# renders every task — completed struck through, in-progress bold with its
# spinner text, pending with open blockers — and redraws on change, so it
# works as a tmux side pane (see the prefix+T binding in modules/cli/tmux.nix).
# Session auto-selection picks the list with the most recently changed task;
# pass a session id or CLAUDE_CODE_TASK_LIST_ID name to pin one.
writeShellApplication {
  name = "claude-tasks";
  runtimeInputs = [
    jq
    ncurses # tput
  ];
  runtimeEnv.RENDER_JQ = ./render.jq;
  text = builtins.readFile ./claude-tasks.sh;
}
