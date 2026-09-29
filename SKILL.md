---
name: sous-agents
description: Déléguer du travail mécanique à des CLI gratuites (OpenCode = codeur, Codex = relecteur, Antigravity = analyse gros contexte) puis valider leur travail. À utiliser quand l'utilisateur dit « délègue », « sous-agent », « fais-le faire par OpenCode/Codex/Antigravity », « économise mon quota », « 2ᵉ avis / relecture indépendante », ou de soi-même pour une tâche de code volumineuse, répétitive et entièrement spécifiable, dans un dépôt git non confidentiel.
---

# Sous-agents CLI gratuits

Claude garde la conception et la validation ; les sous-agents font l'exécution mécanique.
Script : `bash ~/.claude/skills/sous-agents/bin/delegate.sh` (macOS, Linux, Windows via Git Bash) — rôles et pièges détaillés dans `README.md` du même dossier.

## Déléguer ou pas ?

Déléguer seulement si **tout** est vrai :
- la tâche est mécanique et se spécifie entièrement en un brief court (sinon plus rapide de la faire soi-même) ;
- le projet est un dépôt git **non confidentiel** (pas de code client, pas de NDA) — les offres gratuites peuvent entraîner sur les données ;
- le résultat se vérifie objectivement (tests, commande, build).

| Besoin | Rôle |
|---|---|
| écrire / corriger du code bien spécifié | `coder` |
| 2ᵉ avis sur un changement non commité | `reviewer` |
| question sur beaucoup de fichiers (ne modifie rien) | `bigctx` |

## Déroulé

1. **Brief** : `T=~/.cache/sous-agents/tasks/<projet>-<AAAA-MM-JJ>-<nom-court>` ; écrire `$T/BRIEF.md` d'après `roles/brief-modele.md`.
   Court, précis, fichiers à toucher nommés, critère « Terminé quand » exécutable. Aucun secret dans le brief.
2. **Lancer** (en arrière-plan, ça prend 1 à 3 min) :
   `bash ~/.claude/skills/sous-agents/bin/delegate.sh <rôle> "$T" <projet-git> [fichiers pour bigctx]`
   Code 2 = fichiers sensibles détectés → ne pas contourner, faire la tâche soi-même. Code 3 = aucune réponse de l'agent.
3. **Valider** — jamais sur la parole de l'agent :
   - `coder` : lire `$T/RESULT.diff` en entier ; `git apply --check` puis `git apply` dans le projet ; exécuter les critères « Terminé quand ».
     Le diff ne doit toucher que ce que demande le brief.
   - `reviewer` : chaque bug signalé est une piste à vérifier (faux positifs fréquents), pas un verdict.
   - `bigctx` : vérifier les `fichier:ligne` cités avant de s'en servir.
4. **Refus** : un seul aller-retour avec un brief corrigé ; sinon Claude termine lui-même.
5. Ajouter en bas de `$T/RESULT.md` : `Verdict : accepté | corrigé | refusé — <raison>`.
6. Si un modèle, une commande ou un piège a changé : mettre à jour `README.md` / `bin/delegate.sh` et committer dans `~/.claude/skills/sous-agents`.
