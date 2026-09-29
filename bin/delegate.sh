#!/usr/bin/env bash
# Délègue une tâche à un sous-agent CLI gratuit.
#   delegate.sh coder    <dossier-tâche> <projet-git>            -> OpenCode (modèles gratuits en cascade), secours Codex
#   delegate.sh reviewer <dossier-tâche> <projet-git>            -> Codex, lecture seule, effort élevé
#   delegate.sh bigctx   <dossier-tâche> <fichier> [fichier...]  -> Antigravity, texte seul (fichiers numérotés dans le prompt)
# Le dossier-tâche contient BRIEF.md ; le script y écrit RESULT.md (réponse) et, pour coder, RESULT.diff (à appliquer avec git apply).
# coder/reviewer travaillent sur une copie propre du projet : fichiers suivis + non suivis non ignorés, jamais les fichiers ignorés.

set -u
ROOT=$(cd "$(dirname "$0")/.." && pwd)
export PATH="$HOME/.opencode/bin:$HOME/.local/bin:$PATH"
role=$1 task=$(cd "$2" && pwd); shift 2
[ -f "$task/BRIEF.md" ] || { echo "BRIEF.md introuvable dans $task" >&2; exit 1; }
out=$task/RESULT.md

# Modèles OpenCode essayés dans l'ordre (les gratuits changent souvent : `opencode models` pour la liste à jour)
CODER_MODELS="opencode/big-pickle opencode/nemotron-3-ultra-free opencode/mimo-v2.6-flash-free"

SECRET_RE='(^|/)(\.env[^/]*|[^/]*\.(pem|key|p12|pfx)|id_(rsa|ed25519)[^/]*|\.npmrc|[^/]*(secret|credential)[^/]*)$'
check_secrets() {  # $1 = liste de chemins (un par ligne) ; appel direct, jamais derrière un | (sinon exit ne stoppe pas)
  found=$(printf '%s\n' "$1" | grep -iE "$SECRET_RE" | grep -v '\.env\.example$')
  [ -z "$found" ] || { printf 'REFUS : fichiers sensibles, rien n'"'"'est envoyé :\n%s\n' "$found" >&2; exit 2; }
}

clean_copy() {  # copie propre du projet dans $work, avec un commit de base pour mesurer le diff
  git -C "$1" rev-parse 2>/dev/null || { echo "$1 n'est pas un dépôt git" >&2; exit 1; }
  check_secrets "$(git -C "$1" ls-files -co --exclude-standard)"
  work=$(mktemp -d)
  (cd "$1" && git ls-files -co --exclude-standard -z | rsync -a --from0 --files-from=- ./ "$work/")
  git -C "$work" init -q
  printf '%s\n' __pycache__/ '*.pyc' node_modules/ .DS_Store dist/ build/ .venv/ > "$work/.git/info/exclude"  # déchets générés par l'agent
  git -C "$work" add -A && git -C "$work" -c user.name=x -c user.email=x commit -qm base
}

prompt="$(cat "$ROOT/roles/$role.md" 2>/dev/null)

---
$(cat "$task/BRIEF.md")"

case $role in
  coder)
    clean_copy "$1"; cd "$work"
    ok=
    for m in $CODER_MODELS; do
      echo "→ opencode $m" >&2
      opencode run --auto -m "$m" "$prompt" </dev/null >"$out" 2>&1 && [ -s "$out" ] && ok=1 && break
    done
    [ -n "$ok" ] || { echo "→ secours : codex" >&2
      codex exec --skip-git-repo-check -s workspace-write -o "$out" "$prompt" </dev/null >/dev/null 2>&1; }
    git add -A && git diff --cached --binary > "$task/RESULT.diff"
    echo "Diff : $task/RESULT.diff  (copie de travail : $work)" >&2 ;;
  reviewer)
    clean_copy "$1"
    # le changement à relire = état actuel du projet vs HEAD
    git -C "$1" diff HEAD > "$work/.changes.diff"
    codex exec --skip-git-repo-check -C "$work" -s read-only -c model_reasoning_effort=high -o "$out" \
      "$prompt

Le changement à relire (diff vs HEAD) est dans .changes.diff." </dev/null >/dev/null 2>&1 ;;
  bigctx)
    check_secrets "$(printf '%s\n' "$@")"
    files=""; for f in "$@"; do files+="
=== $f ===
$(cat -n "$f")"; done
    agy -p "$prompt

IMPORTANT : n'utilise aucun outil, tout le contenu utile est ci-dessous.
$files" --print-timeout 600s </dev/null >"$out" 2>/dev/null ;;
  *) echo "Rôle inconnu : $role (coder | reviewer | bigctx)" >&2; exit 1 ;;
esac
