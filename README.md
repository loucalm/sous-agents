# Sous-agents CLI gratuits, supervisés par Claude Code

Claude Code garde la conception et la validation. Il délègue le travail mécanique à des CLI gratuites
et relit tout ce qu'elles produisent avant de l'accepter.

## Rôles

| Rôle | Outil | Modèle / mode | Usage |
|---|---|---|---|
| `coder` | OpenCode | modèles gratuits OpenCode en cascade, secours Codex | écrire / corriger du code bien spécifié |
| `reviewer` | Codex CLI (ChatGPT Free) | lecture seule, `model_reasoning_effort=high` | 2ᵉ avis indépendant sur un changement |
| `bigctx` | Antigravity CLI (`agy`) | lecture seule via `view_file`, sur copie propre | questions sur beaucoup de fichiers à la fois |

## Installation (sur chaque ordinateur)

C'est un plugin Claude Code chargé automatiquement depuis `~/.claude/skills/sous-agents`.

**macOS / Linux**
```bash
git clone <url-du-dépôt> ~/.claude/skills/sous-agents
bash ~/.claude/skills/sous-agents/bin/check.sh
```

**Windows** : prérequis [Git for Windows](https://git-scm.com/downloads/win) (fournit Git Bash, que Claude Code utilise
aussi pour ses commandes et ses hooks). Dans **Git Bash** :
```bash
git clone <url-du-dépôt> ~/.claude/skills/sous-agents
bash ~/.claude/skills/sous-agents/bin/check.sh
```

`check.sh` vérifie git/tar et que chaque CLI est installée, connectée et répond. Une CLI absente rend seulement son rôle
indisponible. Pour installer et connecter les CLI : `opencode` (puis rien, les modèles `-free` marchent sans clé),
`codex login`, `agy` (1er lancement interactif).
Mise à jour du système : `git -C ~/.claude/skills/sous-agents pull`.

Contenu : `skills/sous-agents/SKILL.md` (quand et comment Claude délègue), `bin/` (scripts bash : `delegate.sh`, `session-start.sh`,
`update-clis.sh`, `check.sh`), `roles/` (prompts de rôle + modèle de brief), `hooks/hooks.json` (début de session :
mise à jour quotidienne des CLI + rappel à Claude de l'accord du projet, pour qu'il propose les sous-agents dès le départ).
Pour vérifier que le plugin est bien chargé : `claude plugin details sous-agents@skills-dir` doit indiquer `Skills (1)`.

## Utilisation (faite par Claude, d'après SKILL.md)

```bash
T=~/.cache/sous-agents/tasks/<projet>-<date>-<nom>   # 1 dossier par tâche, hors du projet
# écrire $T/BRIEF.md d'après roles/brief-modele.md, puis :
bash bin/delegate.sh coder    $T ~/chemin/du/projet               # -> RESULT.md + RESULT.diff (git apply)
bash bin/delegate.sh reviewer $T ~/chemin/du/projet               # relit le diff non commité vs HEAD
bash bin/delegate.sh bigctx   $T ~/chemin/du/projet [fichiers...] # questions, sans rien modifier
```

## Critères d'acceptation (appliqués par Claude)

1. Le diff (`git diff`) ne touche que ce que demande le brief, sans fichier en trop.
2. Les critères « Terminé quand » du brief sont vérifiés en les **exécutant** (tests, commande, build), pas en lisant le résumé de l'agent.
3. Le style est cohérent avec le code existant, sans dépendance ajoutée sans accord.
4. Chaque remarque du relecteur est vérifiée avant d'être crue (il se trompe parfois, voir plus bas).
5. Sinon, on refuse et on renvoie un brief corrigé (un seul aller-retour), ou bien Claude corrige lui-même si c'est plus court.

## Accord et transparence

- Aucun envoi sans accord de l'utilisateur pour le projet. Claude pose la question en début de session sur tout projet git pas encore décidé
  (oui pour ce projet / juste cette fois / non). Le choix est mémorisé dans `~/.config/sous-agents/projets`
  (par ordinateur ; pour le modifier : `delegate.sh allow|deny <projet>`, pour le lire : `delegate.sh status <projet>`).
- Le script bloque (code 4) tout projet non autorisé, sauf accord ponctuel `SOUS_AGENTS_OK=1`.
- Claude annonce chaque délégation avant de la lancer et récapitule à la fin ce qui a été délégué, à qui, avec quel verdict.

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
- **Antigravity** : en mode `-p`, l'outil `run_command` est refusé en headless, mais `view_file` fonctionne.
  Le prompt impose donc `view_file`. Le mode `--dangerously-skip-permissions` n'est pas utilisé.
  `agy -p` ne lit pas stdin : pour un prompt passé par stdin, il faut `--input-format stream-json --output-format stream-json --print=`
  avec des lignes `{"event":"user","message":{"content":"..."}}` (non utilisé pour l'instant).
- **Windows** : les scripts utilisent `pwd -W` (chemins `C:/...` pour les .exe), `tar` à la place de `rsync`, et
  `.gitattributes` force les fins de ligne LF (sinon bash casse). Non testé sur un vrai PC au 29/09/2026 : lancer `check.sh`.
- **Garde-fou** : `check_secrets` doit être appelé directement, jamais derrière un `|` (dans un sous-shell, `exit` n'arrête pas le script).
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
