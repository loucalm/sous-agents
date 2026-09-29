# Sous-agents CLI gratuits, supervisés par Claude Code

Claude Code garde la conception et la validation. Il délègue le travail mécanique à des CLI gratuites
et relit tout ce qu'elles produisent avant de l'accepter.

## Rôles

| Rôle | Outil | Modèle / mode | Usage |
|---|---|---|---|
| `coder` | OpenCode | modèles gratuits OpenCode en cascade, secours Codex | écrire / corriger du code bien spécifié |
| `reviewer` | Codex CLI (ChatGPT Free) | lecture seule, `model_reasoning_effort=high` | 2ᵉ avis indépendant sur un changement |
| `bigctx` | Antigravity CLI (`agy`) | texte seul, fichiers numérotés injectés dans le prompt | questions sur beaucoup de fichiers à la fois |

## Utilisation

```bash
mkdir -p tasks/2026-09-29-nom-court        # 1 dossier par tâche
$EDITOR tasks/2026-09-29-nom-court/BRIEF.md # à partir de tasks/_BRIEF-modele.md
bin/delegate.sh coder    tasks/2026-09-29-nom-court ~/chemin/du/projet
bin/delegate.sh reviewer tasks/2026-09-29-nom-court ~/chemin/du/projet
bin/delegate.sh bigctx   tasks/2026-09-29-nom-court fichier1 fichier2 ...
```

L'agent écrit sa réponse dans `RESULT.md`, à côté du brief. Claude ajoute ensuite une ligne `Verdict : accepté / refusé / corrigé`
en bas du `RESULT.md`.

## Critères d'acceptation (appliqués par Claude)

1. Le diff (`git diff`) ne touche que ce que demande le brief, sans fichier en trop.
2. Les critères « Terminé quand » du brief sont vérifiés en les **exécutant** (tests, commande, build), pas en lisant le résumé de l'agent.
3. Le style est cohérent avec le code existant, sans dépendance ajoutée sans accord.
4. Chaque remarque du relecteur est vérifiée avant d'être crue (il se trompe parfois, voir plus bas).
5. Sinon, on refuse et on renvoie un brief corrigé (un seul aller-retour), ou bien Claude corrige lui-même si c'est plus court.

## Confidentialité, règles strictes

Les offres gratuites (OpenCode Zen `-free`, ChatGPT Free, Antigravity) peuvent utiliser les données pour entraîner leurs modèles.
- Aucun secret : `delegate.sh` **refuse** de partir si le projet contient `.env*`, `*.pem`, `*.key`, `*secret*`, `*credential*`, etc.
- Pas de code client ou sous contrat de confidentialité. En cas de doute, Claude fait la tâche lui-même.
- Le codeur ne travaille que dans un dépôt git (pour pouvoir voir et annuler son diff).

## Pièges connus (vérifiés le 29/09/2026)

- **stdin** : `codex exec` lit stdin s'il est ouvert et attend indéfiniment. Il faut toujours ajouter `</dev/null` (c'est fait dans le script).
- **Codex** : l'effort de raisonnement par défaut vaut `none`, et le relecteur rate alors un bug évident. Il faut `-c model_reasoning_effort=high`.
- **Antigravity** : en mode `-p`, toute action (même lire un fichier) passe par l'outil « command », refusé en headless.
  D'où le mode texte seul. Le mode `--dangerously-skip-permissions` n'est pas utilisé.
- **OpenCode** : les modèles `-free` changent souvent. Vérifier avec `opencode models`, puis mettre à jour `CODER_MODELS` dans `bin/delegate.sh`.
  Les clés Groq / Cerebras / OpenRouter (`opencode auth login`) ne servent que de secours supplémentaire.

## Banc d'essai du 29/09/2026

Tâche : module timecode avec drop-frame 29,97/59,94 (piégeux), notée par 15 tests cachés.

| Agent | Score | Durée | Remarque |
|---|---|---|---|
| OpenCode `big-pickle` | 15/15 | 146 s | code le plus verbeux (105 lignes) |
| Codex (gpt-6-luna) | 15/15 | 48 s | le plus concis (55 lignes) |
| Antigravity (texte seul) | 15/15 | 70 s | 85 lignes |

Relecture d'un bug volontaire (off-by-one) par Codex : raté avec l'effort par défaut, trouvé avec l'effort `high`,
mais avec **un faux positif** (valeur attendue fausse). Conclusion : le relecteur donne des pistes, pas des verdicts.

## Mise à jour automatique

`bin/update-clis.sh` est branché en hook `SessionStart` dans `~/.claude/settings.json`. Il tourne au plus une fois par jour
(horodatage dans `~/.cache/agents-cli/last-check`), en arrière-plan, et ne bloque jamais le démarrage.
Journal : `~/.cache/agents-cli/update.log`.

| Outil | Installation détectée | Commande de mise à jour |
|---|---|---|
| OpenCode | script curl (`~/.opencode/bin`) | `opencode upgrade --method curl` |
| Codex | installeur autonome (`~/.codex/packages/standalone`) | `codex update` |
| Antigravity | binaire autonome (`~/.local/bin/agy`) | `agy update` |

Pour forcer une vérification : `rm ~/.cache/agents-cli/last-check`.
