#!/bin/bash
# Installs the agent configuration in this repository by symlinking it into the
# locations that Claude Code and Codex read.
#
#   AGENTS.md       -> ~/.claude/CLAUDE.md, ~/.codex/AGENTS.md
#   skills/<name>/  -> ~/.claude/skills/<name>, ~/.agents/skills/<name>
#
# Existing symlinks are replaced. Existing regular files or directories are left
# untouched and reported, so that nothing is overwritten silently.

set -eu

readonly repo_dir="$(cd -- "$(dirname -- "$0")" && pwd)"
failed=0

link() {
  local src="$1"
  local dst="$2"
  if [[ -e "${dst}" && ! -L "${dst}" ]]; then
    echo "SKIP: ${dst} exists and is not a symlink" >&2
    failed=1
    return
  fi
  mkdir -p -- "$(dirname -- "${dst}")"
  ln -sfn -- "${src}" "${dst}"
  echo "${dst} -> ${src}"
}

link "${repo_dir}/AGENTS.md" "${HOME}/.claude/CLAUDE.md"
link "${repo_dir}/AGENTS.md" "${HOME}/.codex/AGENTS.md"

for skill_dir in "${repo_dir}"/skills/*/; do
  name="$(basename -- "${skill_dir}")"
  link "${skill_dir%/}" "${HOME}/.claude/skills/${name}"
  link "${skill_dir%/}" "${HOME}/.agents/skills/${name}"
done

exit "${failed}"
