#!/bin/sh
# setup-plugins.sh - install the Claude Code plugin set used with this project.
#
# WHY THIS SCRIPT EXISTS
# ----------------------
# Claude Code deliberately refuses to auto-install plugins that are declared
# only by a git-tracked settings file. Its debug log says so explicitly:
#
#   Skipped auto-recording <plugin> - enabled only by repo-authored settings
#
# Internally the gate is `fromOwnConfig`, which is true only for user-scope
# settings or a *non-git-tracked* .claude/settings.local.json. This is a
# security boundary, not a bug: a repository does not get to install software
# on your machine. Checking in .claude/settings.json therefore declares intent
# and registers the marketplaces, but it can never install anything.
#
# This script is the deliberate, human-run counterpart to that file. You run
# it; the repo does not run it for you.
#
# USAGE
#   .claude/setup-plugins.sh [user|project|local]
#
#   user     (default) install for every project you open. This is the durable,
#            self-healing layer - it survives a wiped ~/.claude/plugins.
#   project  install for this repository only; writes .claude/settings.json.
#   local    install for this repository only; writes the gitignored
#            .claude/settings.local.json and leaves your global config alone.
#
# Safe to re-run at any time: every step is idempotent and exits 0 when the
# work is already done.

set -u

SCOPE="${1:-user}"

case "$SCOPE" in
  user|project|local) ;;
  -h|--help|help)
    awk 'NR>1 && /^#/ { sub(/^# ?/, ""); print; next } NR>1 { exit }' "$0"
    exit 0 ;;
  *)
    printf 'error: unknown scope "%s" (expected user, project or local)\n' "$SCOPE" >&2
    exit 2 ;;
esac

# Marketplaces must all be registered before any plugin is installed.
MARKETPLACES='anthropics/claude-code obra/superpowers-marketplace thedotmack/claude-mem'

# One plugin per `claude plugin install` invocation. Passing several to a
# single call installs ONLY THE FIRST and still exits 0 - the CLI's usage
# string is `<plugin>`, singular. Do not collapse these into one command.
PLUGINS='superpowers@superpowers-marketplace
        frontend-design@claude-code-plugins
        code-review@claude-code-plugins
        pr-review-toolkit@claude-code-plugins
        security-guidance@claude-code-plugins
        claude-mem@thedotmack'

FAILED=0

# Run a step, keeping its output so a failure can be explained. The CLI's
# errors are actionable ("could not read Username for 'https://github.com'"),
# so they are printed rather than swallowed.
run_step() {
  _label="$1"
  shift
  if _out=$("$@" </dev/null 2>&1); then
    printf '  ok    %s\n' "$_label"
  else
    _rc=$?
    printf '  FAIL  %s (exit %s)\n' "$_label" "$_rc" >&2
    printf '%s\n' "$_out" | sed 's/^/        /' >&2
    FAILED=$((FAILED + 1))
  fi
}

if ! command -v claude >/dev/null 2>&1; then
  cat >&2 <<'MSG'
error: the `claude` CLI is not on your PATH.

Install Claude Code first: https://claude.com/claude-code
MSG
  exit 1
fi

# project/local scope record the repository path, so run from the repo root.
REPO_ROOT=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)
cd "$REPO_ROOT" || exit 1

printf 'Claude Code plugin setup\n'
printf '  repo:  %s\n' "$REPO_ROOT"
printf '  scope: %s\n' "$SCOPE"
printf '  cli:   %s\n\n' "$(claude --version 2>/dev/null || echo unknown)"

# Marketplace registration is always user scope: that is what makes it
# "own config" and therefore durable. Each add clones a git repository and
# carries its own 120s deadline, so this is the slow part on a cold machine.
printf 'Registering marketplaces (first run clones them; ~10-15s)\n'
for m in $MARKETPLACES; do
  run_step "$m" claude plugin marketplace add "$m" --scope user
done

# No -y. Without it you are shown any marketplace-declared command before it
# runs on your machine, which is exactly the moment a human should see.
printf '\nInstalling plugins (scope: %s)\n' "$SCOPE"
for p in $PLUGINS; do
  run_step "$p" claude plugin install "$p" --scope "$SCOPE"
done

printf '\nInstalled:\n'
claude plugin list 2>&1 | sed 's/^/  /'

cat <<'MSG'

Plugins load at session start, so restart Claude Code (or open a new session)
before they become available. To remove one:  claude plugin uninstall <name>
MSG

if [ "$FAILED" -ne 0 ]; then
  printf '\n%s step(s) failed - see the messages above.\n' "$FAILED" >&2
  exit 1
fi
