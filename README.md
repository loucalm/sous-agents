# Sous-agents CLI gratuits, supervisés par Claude Code

Claude Code garde la conception et la validation. Il délègue le travail mécanique à des CLI gratuites
et relit tout ce qu'elles produisent avant de l'accepter.

## Rôles

| Rôle | Outil | Modèle / mode | Usage |
|---|---|---|---|
| `coder` | OpenCode | modèles gratuits OpenCode en cascade, secours Codex | écrire / corriger du code bien spécifié |
| `reviewer` | Codex CLI (ChatGPT Free) | lecture seule, `model_reasoning_effort=high` | 2ᵉ avis indépendant sur un changement |
| `bigctx` | Antigravity CLI (`agy`) | texte seul, fichiers numérotés injectés dans le prompt | questions sur beaucoup de fichiers à la fois |

## Installation (sur chaque ordinateur, macOS ou Linux)

C'est un plugin Claude Code chargé automatiquement depuis `~/.claude/skills/sous-agents` :

```bash
git clone <url-du-dépôt> ~/.claude/skills/sous-agents
```

Ensuite : installer et connecter les CLI voulues (`opencode`, `codex login`, `agy`). Celles qui manquent sont ignorées.
Mise à jour du système : `git -C ~/.claude/skills/sous-agents pull`.
Windows : les scripts sont en bash, il faut donc passer par WSL ou Git Bash (non testé).

Contenu : `SKILL.md` (quand et comment Claude délègue), `bin/` (scripts), `roles/` (prompts de rôle + modèle de brief),
`hooks/hooks.json` (mise à jour quotidienne des CLI).

## Utilisation (faite par Claude, d'après SKILL.md)

```bash
T=~/.cache/sous-agents/tasks/<projet>-<date>-<nom>   # 1 dossier par tâche, hors du projet
# écrire $T/BRIEF.md d'après roles/brief-modele.md, puis :
bin/delegate.sh coder    $T ~/chemin/du/projet      # -> RESULT.md + RESULT.diff (git apply)
bin/delegate.sh reviewer $T ~/chemin/du/projet      # relit le diff non commité vs HEAD
bin/delegate.sh bigctx   $T fichier1 fichier2 ...
```

## Critères d'acceptation (appliqués par Claude)

1. Le diff (`git diff`) ne touche que ce que demande le brief, sans fichier en trop.
2. Les critères « Terminé quand » du brief sont vérifiés en les **exécutant** (tests, commande, build), pas en lisant le résumé de l'agent.
3. Le style est cohérent avec le code existant, sans dépendance ajoutée sans accord.
4. Chaque remarque du relecteur est vérifiée avant d'être crue (il se trompe parfois, voir plus bas).
5. Sinon, on refuse et on renvoie un brief corrigé (un seul aller-retour), ou bien Claude corrige lui-même si c'est plus court.

## Confidentialité, règles strictes

Les offres gratuites (OpenCode Zen `-free`, ChatGPT Free, Antigravity) peuvent utiliser les données pour entraîner leurs modèles.
- L'agent travaille sur une **copie propre** du projet (fichiers suivis par git + nouveaux fichiers non ignorés) :
  les fichiers ignorés par `.gitignore` (où vivent normalement `.env`, clés…) ne sont jamais copiés.
- `delegate.sh` **refuse** de partir (code 2) si la copie ou les fichiers fournis contiennent `.env*`, `*.pem`, `*.key`,
  `*secret*`, `*credential*`, etc. Testé le 29/09/2026, après correction d'un bug où le refus ne stoppait pas le script.
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

`bin/update-clis.sh` est branché en hook `SessionStart` par le plugin (`hooks/hooks.json`). Il tourne au plus une fois par jour
(horodatage dans `~/.cache/agents-cli/last-check`), en arrière-plan, et ne bloque jamais le démarrage.
Journal : `~/.cache/agents-cli/update.log`.

Le mode d'installation est détecté à chaque fois : Homebrew → `brew upgrade`, npm → `npm i -g …@latest`,
sinon la commande intégrée (`opencode upgrade`, `codex update`, `agy update`).

Pour forcer une vérification : `rm ~/.cache/agents-cli/last-check`.
