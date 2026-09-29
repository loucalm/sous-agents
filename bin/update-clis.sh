#!/bin/zsh
# Hook SessionStart : met à jour OpenCode, Codex et Antigravity au plus une fois par jour.
# Rend la main tout de suite (le travail tourne en arrière-plan) ; journal dans ~/.cache/agents-cli/update.log
# Chaque commande de mise à jour vérifie elle-même la dernière version et ne fait rien si on est à jour.

DIR=~/.cache/agents-cli
STAMP=$DIR/last-check
LOG=$DIR/update.log
mkdir -p $DIR

[[ "$(cat $STAMP 2>/dev/null)" == "$(date +%F)" ]] && exit 0
date +%F > $STAMP

{
  echo "== $(date '+%F %T')"
  # nom | commande de version | commande de mise à jour (adaptée au mode d'installation détecté)
  for line in \
    "opencode|$HOME/.opencode/bin/opencode --version|$HOME/.opencode/bin/opencode upgrade --method curl" \
    "codex|$HOME/.local/bin/codex --version|$HOME/.local/bin/codex update" \
    "agy|$HOME/.local/bin/agy --version|$HOME/.local/bin/agy update"
  do
    IFS='|' read name ver upd <<< "$line"
    before=$(eval $ver 2>/dev/null | tail -1)
    eval $upd </dev/null >/dev/null 2>&1 || echo "$name : échec de la mise à jour"
    after=$(eval $ver 2>/dev/null | tail -1)
    [[ "$before" == "$after" ]] && echo "$name : à jour ($after)" || echo "$name : $before -> $after"
  done
} >> $LOG 2>&1 &!

exit 0
