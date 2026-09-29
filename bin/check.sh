#!/usr/bin/env bash
# Diagnostic à lancer une fois sur un nouvel ordinateur : bash ~/.claude/skills/sous-agents/bin/check.sh
# Vérifie les outils de base et que chaque CLI répond en mode non interactif (≈ 30 s).

export PATH="$HOME/.opencode/bin:$HOME/.local/bin:$PATH"
ok() { printf '  OK   %s\n' "$1"; }
ko() { printf '  --   %s\n' "$1"; }

echo "Outils de base"
for t in git tar mktemp; do command -v $t >/dev/null && ok $t || ko "$t manquant"; done

echo "Sous-agents (une CLI absente = rôle indisponible, les autres marchent quand même)"
ping() {  # $1 nom, reste = commande ; réussit si la réponse contient PONG
  n=$1; shift
  command -v "$1" >/dev/null || { ko "$n : non installé"; return; }
  r=$("$@" </dev/null 2>&1 | tail -5)
  case "$r" in *PONG*) ok "$n" ;; *) ko "$n : installé mais ne répond pas (connexion ?) → $(echo "$r" | tail -1 | cut -c1-120)" ;; esac
}
d=$(mktemp -d); cd "$d" || exit 1
ping "OpenCode (coder)"      opencode run -m opencode/big-pickle "Réponds uniquement: PONG"
ping "Codex (reviewer)"      codex exec --skip-git-repo-check -s read-only "Réponds uniquement: PONG"
ping "Antigravity (bigctx)"  agy --print-timeout 120s -p "Réponds uniquement: PONG"
