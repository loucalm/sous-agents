#!/bin/zsh
# Délègue une tâche à un sous-agent CLI gratuit.
#   delegate.sh coder    <dossier-tâche> <dossier-projet>          -> OpenCode (modèles gratuits en cascade), secours Codex
#   delegate.sh reviewer <dossier-tâche> <dossier-projet>          -> Codex, lecture seule, effort élevé
#   delegate.sh bigctx   <dossier-tâche> <fichier> [fichier...]    -> Antigravity, texte seul (contenu des fichiers dans le prompt)
# Le dossier-tâche contient BRIEF.md ; le script écrit RESULT.md (réponse de l'agent) à côté.

set -u
ROOT=${0:A:h:h}
role=$1 task=${2:A}; shift 2
[[ -f $task/BRIEF.md ]] || { echo "BRIEF.md introuvable dans $task" >&2; exit 1; }
out=$task/RESULT.md

# Modèles OpenCode essayés dans l'ordre (les gratuits changent souvent : `opencode models` pour la liste à jour)
CODER_MODELS=(opencode/big-pickle opencode/nemotron-3-ultra-free opencode/mimo-v2.6-flash-free)

# Garde-fou confidentialité : les fournisseurs gratuits peuvent entraîner sur les données.
secrets() {
  find "$@" \( -name node_modules -o -name .git \) -prune -o -type f \
    \( -name '.env*' -o -name '*.pem' -o -name '*.key' -o -name '*.p12' -o -name 'id_rsa*' \
       -o -iname '*secret*' -o -iname '*credential*' -o -name '.npmrc' \) -print 2>/dev/null \
    | grep -v '\.env\.example$'
}
found=$(secrets "$@")
[[ -n $found ]] && { echo "REFUS : fichiers sensibles présents, rien n'est envoyé :\n$found" >&2; exit 2; }

prompt="$(cat $ROOT/roles/$role.md)

---
$(cat $task/BRIEF.md)"

case $role in
  coder)
    cd $1
    for m in $CODER_MODELS; do
      echo "→ opencode $m" >&2
      ~/.opencode/bin/opencode run --auto -m $m "$prompt" </dev/null >$out 2>&1 && [[ -s $out ]] && exit 0
    done
    echo "→ secours : codex" >&2
    codex exec --skip-git-repo-check -s workspace-write -o $out "$prompt" </dev/null >/dev/null 2>&1 ;;
  reviewer)
    codex exec --skip-git-repo-check -C $1 -s read-only -c model_reasoning_effort=high -o $out "$prompt" </dev/null >/dev/null 2>&1 ;;
  bigctx)
    files=""; for f in "$@"; do files+="
=== $f ===
$(cat -n $f)"; done
    agy -p "$prompt

IMPORTANT : n'utilise aucun outil, tout le contenu utile est ci-dessous.
$files" --print-timeout 600s </dev/null >$out 2>/dev/null ;;
  *) echo "Rôle inconnu : $role (coder | reviewer | bigctx)" >&2; exit 1 ;;
esac
