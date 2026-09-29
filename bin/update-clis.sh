#!/usr/bin/env bash
# Hook SessionStart : met à jour OpenCode, Codex et Antigravity au plus une fois par jour.
# Rend la main tout de suite (travail en arrière-plan) ; journal dans ~/.cache/agents-cli/update.log
# Les CLI absentes sont ignorées. Chaque commande de mise à jour ne fait rien si la version est déjà la dernière.

export PATH="$HOME/.opencode/bin:$HOME/.local/bin:/opt/homebrew/bin:/usr/local/bin:$PATH"
DIR=$HOME/.cache/agents-cli
mkdir -p "$DIR"
[ "$(cat "$DIR/last-check" 2>/dev/null)" = "$(date +%F)" ] && exit 0
date +%F > "$DIR/last-check"

update_cmd() {  # choisit la commande selon le mode d'installation
  p=$(command -v "$1") || return 1
  real=$(readlink -f "$p" 2>/dev/null || echo "$p")
  case "$1:$real" in
    *:*/Cellar/*|*:*/homebrew/*) echo "brew upgrade $1" ;;
    codex:*/node_modules/*)      echo "npm i -g @openai/codex@latest" ;;
    opencode:*/node_modules/*)   echo "npm i -g opencode-ai@latest" ;;
    opencode:*)                  echo "opencode upgrade" ;;
    *)                           echo "$1 update" ;;
  esac
}

{
  echo "== $(date '+%F %T')"
  for c in opencode codex agy; do
    upd=$(update_cmd $c) || continue
    before=$($c --version 2>/dev/null | tail -1)
    $upd </dev/null >/dev/null 2>&1 || echo "$c : échec ($upd)"
    after=$($c --version 2>/dev/null | tail -1)
    [ "$before" = "$after" ] && echo "$c : à jour ($after)" || echo "$c : $before -> $after"
  done
} >> "$DIR/update.log" 2>&1 &
disown

exit 0
