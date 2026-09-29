#!/usr/bin/env bash
# Hook SessionStart : mise à jour quotidienne des CLI + rappel à Claude de l'état de l'accord sous-agents pour ce projet.
# Ce qui est affiché sur stdout est ajouté au contexte de Claude en début de session.

here=$(cd "$(dirname "$0")" && pwd)
bash "$here/update-clis.sh" >/dev/null 2>&1

dir=${CLAUDE_PROJECT_DIR:-$PWD}
case $(bash "$here/delegate.sh" status "$dir" 2>/dev/null) in
  "non demandé") echo "[sous-agents] Accord pas encore demandé pour ce projet ($dir). Au début de ta première réponse, propose à l'utilisateur d'utiliser les sous-agents gratuits sur ce projet (question avec les 3 options du skill sous-agents), puis enregistre sa réponse." ;;
  ok) echo "[sous-agents] Autorisés sur ce projet : délègue le travail mécanique selon le skill sous-agents, en l'annonçant à l'utilisateur." ;;
esac
exit 0
