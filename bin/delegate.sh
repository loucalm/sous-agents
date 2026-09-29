#!/usr/bin/env bash
# Délègue une tâche à un sous-agent CLI gratuit. Fonctionne sous macOS, Linux et Windows (Git Bash).
#   delegate.sh coder    <dossier-tâche> <projet-git>               -> OpenCode (modèles gratuits en cascade), secours Codex
#   delegate.sh reviewer <dossier-tâche> <projet-git>               -> Codex, lecture seule, effort élevé
#   delegate.sh bigctx   <dossier-tâche> <projet-git> [fichier...]  -> Antigravity, lecture seule (view_file)
# Le dossier-tâche contient BRIEF.md ; le script y écrit RESULT.md (réponse) et, pour coder, RESULT.diff (à appliquer avec git apply).
#   delegate.sh allow|deny|status <projet-git>                      -> accord de l'utilisateur pour ce projet (mémorisé)
# Les agents travaillent sur une copie propre du projet : fichiers suivis + non suivis non ignorés, jamais les fichiers ignorés.
# Rien ne part sans accord : projet autorisé (allow) ou accord ponctuel (SOUS_AGENTS_OK=1).

set -u
abs() { (cd "$1" && { pwd -W 2>/dev/null || pwd; }); }  # pwd -W : chemin C:/... sous Git Bash, pour les .exe Windows
ROOT=$(abs "$(dirname "$0")/..")
export PATH="$HOME/.opencode/bin:$HOME/.local/bin:$PATH"
CONSENT=$HOME/.config/sous-agents/projets   # lignes "ok <chemin>" ou "non <chemin>"
toplevel() { git -C "$1" rev-parse --show-toplevel 2>/dev/null || { echo "$1 n'est pas un dépôt git" >&2; exit 1; }; }
case "${1:-}" in allow|deny|status)
  [ $# -eq 2 ] || { echo "usage : delegate.sh $1 <projet-git>" >&2; exit 1; }
  top=$(toplevel "$2") || exit 1; mkdir -p "$(dirname "$CONSENT")"; touch "$CONSENT"
  if [ "$1" = status ]; then
    grep -xF -e "ok $top" -e "non $top" "$CONSENT" | cut -d' ' -f1 | grep . || echo "non demandé"; exit 0
  fi
  grep -vxF -e "ok $top" -e "non $top" "$CONSENT" > "$CONSENT.tmp"; mv "$CONSENT.tmp" "$CONSENT"
  [ "$1" = allow ] && echo "ok $top" >> "$CONSENT" || echo "non $top" >> "$CONSENT"
  echo "$1 : $top"; exit 0
esac
[ $# -ge 3 ] || { sed -n '2,7p' "$0" >&2; exit 1; }
role=$1 task=$(abs "$2") proj=$3; shift 3
[ -f "$task/BRIEF.md" ] || { echo "BRIEF.md introuvable dans $task" >&2; exit 1; }
out=$task/RESULT.md
rm -f "$out" "$task/RESULT.diff"

# Modèles OpenCode essayés dans l'ordre (les gratuits changent souvent : `opencode models` pour la liste à jour)
CODER_MODELS="opencode/big-pickle opencode/nemotron-3-ultra-free opencode/mimo-v2.6-flash-free"

SECRET_RE='(^|[/\\])(\.env[^/\\]*|[^/\\]*\.(pem|key|p12|pfx)|id_(rsa|ed25519)[^/\\]*|\.npmrc|[^/\\]*(secret|credential)[^/\\]*)$'
check_secrets() {  # $1 = liste de chemins ; appel direct, jamais derrière un | (sinon exit ne stoppe pas le script)
  found=$(printf '%s\n' "$1" | grep -iE "$SECRET_RE" | grep -v '\.env\.example$')
  [ -z "$found" ] && return
  case "${SOUS_AGENTS_SENSIBLES:-}" in   # choix explicite de l'utilisateur, pour cet appel seulement
    exclure)  printf 'Fichiers sensibles exclus de la copie :\n%s\n' "$found" >&2; EXCLUDED=$found ;;
    envoyer)  printf 'ATTENTION : fichiers sensibles envoyés (accord de l'"'"'utilisateur) :\n%s\n' "$found" >&2 ;;
    *) printf 'SENSIBLES : rien n'"'"'est envoyé. Demander à l'"'"'utilisateur, puis relancer avec\nSOUS_AGENTS_SENSIBLES=exclure (sans ces fichiers) ou SOUS_AGENTS_SENSIBLES=envoyer (tels quels) :\n%s\n' "$found" >&2; exit 5 ;;
  esac
}
EXCLUDED=

top=$(toplevel "$proj") || exit 1   # $( ) = sous-shell : son exit ne suffit pas
if grep -qxF "non $top" "$CONSENT" 2>/dev/null; then
  echo "REFUS : l'utilisateur a refusé les sous-agents pour $top" >&2; exit 4
elif ! grep -qxF "ok $top" "$CONSENT" 2>/dev/null && [ "${SOUS_AGENTS_OK:-}" != 1 ]; then
  echo "ACCORD REQUIS : demander à l'utilisateur, puis 'delegate.sh allow $top' (toujours) ou SOUS_AGENTS_OK=1 (cette fois)" >&2; exit 4
fi

# Copie propre du projet dans $work, avec un commit de base pour mesurer le diff
files=$(git -C "$proj" -c core.quotepath=off ls-files -co --exclude-standard)
check_secrets "$files
$(printf '%s\n' "$@")"
work=$(abs "$(mktemp -d)")
printf '%s\n' "$files" | grep -vxF -e "${EXCLUDED:-/nonexistent/}" | grep . | (cd "$proj" && tar -T - -cf -) | tar -xf - -C "$work"
git -C "$work" init -q
printf '%s\n' __pycache__/ '*.pyc' node_modules/ .DS_Store dist/ build/ .venv/ > "$work/.git/info/exclude"  # déchets générés par l'agent
git -C "$work" add -A && git -C "$work" -c user.name=x -c user.email=x -c core.autocrlf=false commit -qm base
cd "$work"

prompt="$(cat "$ROOT/roles/$role.md" 2>/dev/null)

---
$(cat "$task/BRIEF.md")"

case $role in
  coder)
    ok=
    for m in $CODER_MODELS; do
      echo "→ opencode $m" >&2
      opencode run --auto -m "$m" "$prompt" </dev/null >"$out" 2>&1 && [ -s "$out" ] && ok=1 && break
    done
    [ -n "$ok" ] || { echo "→ secours : codex" >&2
      codex exec --skip-git-repo-check -s workspace-write -o "$out" "$prompt" </dev/null >/dev/null 2>&1; }
    git add -A && git diff --cached --binary > "$task/RESULT.diff"
    echo "Diff : $task/RESULT.diff" >&2 ;;
  reviewer)
    # le changement à relire = état actuel du projet vs HEAD (sans les fichiers exclus)
    ex=(); while IFS= read -r f; do [ -n "$f" ] && ex+=(":(exclude,literal)$f"); done <<< "$EXCLUDED"
    git -C "$proj" diff HEAD -- . ${ex[@]+"${ex[@]}"} > .changes.diff
    codex exec --skip-git-repo-check -s read-only -c model_reasoning_effort=high -o "$out" "$prompt

Le changement à relire (diff vs HEAD) est dans .changes.diff." </dev/null >/dev/null 2>&1 ;;
  bigctx)
    agy --print-timeout 600s -p "$prompt

Fichiers à lire : ${*:-tout le projet}
Lis-les avec l'outil view_file uniquement (jamais run_command) ; ne modifie rien." </dev/null >"$out" 2>/dev/null ;;
  *) echo "Rôle inconnu : $role (coder | reviewer | bigctx)" >&2; exit 1 ;;
esac
[ -s "$out" ] || { echo "Échec : aucune réponse de l'agent" >&2; exit 3; }
