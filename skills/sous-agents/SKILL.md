---
name: sous-agents
description: Déléguer du travail mécanique à des CLI gratuites (OpenCode = codeur, Codex = relecteur, Antigravity = analyse gros contexte) puis valider leur travail. À utiliser quand l'utilisateur dit « délègue », « sous-agent », « fais-le faire par OpenCode/Codex/Antigravity », « économise mon quota », « 2ᵉ avis / relecture indépendante », ou de soi-même pour une tâche de code volumineuse, répétitive et entièrement spécifiable, dans un dépôt git non confidentiel.
---

# Sous-agents CLI gratuits

Claude garde la conception et la validation ; les sous-agents font l'exécution mécanique.
Script : `bash ~/.claude/skills/sous-agents/bin/delegate.sh` (macOS, Linux, Windows via Git Bash) — rôles et pièges détaillés dans `~/.claude/skills/sous-agents/README.md`.

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

## Transparence et accord (obligatoire)

L'utilisateur doit toujours savoir quand un sous-agent travaille sur son projet.

- **Proposer dès le début** : quand le contexte de session contient `[sous-agents] Accord pas encore demandé`, poser la question
  au début de la première réponse, même si la demande du moment ne s'y prête pas. Idem juste après avoir créé un nouveau projet (`git init`).
- **Accord par projet**, avant toute délégation : `delegate.sh status <projet>`.
  - `ok` → autorisé, on peut déléguer.
  - `non` → refusé : ne pas redemander, faire la tâche soi-même.
  - `non demandé` → demander avec AskUserQuestion : « Autoriser les sous-agents gratuits (OpenCode, Codex, Antigravity)
    sur <projet> ? Le code envoyé peut servir à entraîner leurs modèles. » Trois options :
    **Oui pour ce projet** → `delegate.sh allow <projet>` ; **Juste cette fois** → lancer avec `SOUS_AGENTS_OK=1` ;
    **Non** → `delegate.sh deny <projet>`.
  - Si l'utilisateur demande lui-même la délégation dans son message, c'est un accord pour cette fois (`SOUS_AGENTS_OK=1`) ;
    proposer ensuite de l'enregistrer pour le projet.
  - Ne jamais lancer `allow` ou `SOUS_AGENTS_OK=1` sans réponse explicite de l'utilisateur. Code 4 = accord manquant ou refusé.
- **Annoncer avant** chaque lancement, en une ligne : quel agent, pour quelle tâche (ex. « Je confie la correction de X à OpenCode »).
- **Récapituler après** : dans la réponse finale, lister ce qui a été délégué, à quel agent, et le verdict (accepté / corrigé / refusé).

## Déroulé

1. **Brief** : `T=~/.cache/sous-agents/tasks/<projet>-<AAAA-MM-JJ>-<nom-court>` ; écrire `$T/BRIEF.md` d'après `~/.claude/skills/sous-agents/roles/brief-modele.md`.
   Court, précis, fichiers à toucher nommés, critère « Terminé quand » exécutable. Aucun secret dans le brief.
2. **Lancer** (en arrière-plan, ça prend 1 à 3 min) :
   `bash ~/.claude/skills/sous-agents/bin/delegate.sh <rôle> "$T" <projet-git> [fichiers pour bigctx]`
   Code 3 = aucune réponse de l'agent.
   Code 5 = fichiers sensibles **suivis par git** (`.env`, clés…) : ne jamais contourner seul. Demander avec AskUserQuestion
   en citant la liste des fichiers : **Exclure ces fichiers** (recommandé → `SOUS_AGENTS_SENSIBLES=exclure`) /
   **Les envoyer quand même** (→ `SOUS_AGENTS_SENSIBLES=envoyer`) / **Ne pas déléguer**. Valable pour cet appel seulement.
   Signaler aussi qu'un `.env` suivi par git est un risque en soi (proposer de l'ajouter à `.gitignore`).
   Code 4 = accord manquant ou refusé (voir ci-dessus).
3. **Valider** — jamais sur la parole de l'agent :
   - `coder` : lire `$T/RESULT.diff` en entier ; `git apply --check` puis `git apply` dans le projet ; exécuter les critères « Terminé quand ».
     Le diff ne doit toucher que ce que demande le brief.
   - `reviewer` : chaque bug signalé est une piste à vérifier (faux positifs fréquents), pas un verdict.
   - `bigctx` : vérifier les `fichier:ligne` cités avant de s'en servir.
4. **Refus** : un seul aller-retour avec un brief corrigé ; sinon Claude termine lui-même.
5. Ajouter en bas de `$T/RESULT.md` : `Verdict : accepté | corrigé | refusé — <raison>`.
6. Si un modèle, une commande ou un piège a changé : mettre à jour `README.md` / `bin/delegate.sh`, committer et pousser dans `~/.claude/skills/sous-agents`.
