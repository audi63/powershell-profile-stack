# Guide d'utilisation — PowerShell Profile Stack

## Raccourcis clavier

| Raccourci | Action |
|---|---|
| **F1** | Afficher le menu statique (`Show-Menu`) |
| **Ctrl+M** | Lancer le menu interactif (`m`) |
| **Ctrl+R** | Recherche fuzzy dans l'historique (PSFzf) |
| **Ctrl+T** | Recherche fuzzy de fichiers (PSFzf) |
| **Tab** | Completion en menu deroulant (`MenuComplete`) |
| **↑↓** | Naviguer dans les predictions ListView |

## Menus

### Show-Menu (F1) — Aide-memoire statique

Affiche la liste de toutes les categories et commandes. Ne bloque pas le terminal : tu tapes ensuite le nom de la commande.

### Menu interactif `m` (Ctrl+M)

Menu a deux niveaux avec navigation au clavier :

1. **Niveau 1** — 12 categories en degrade arc-en-ciel
2. **Niveau 2** — Commandes de la categorie selectionnee

Controles :
- **↑ ↓** : naviguer
- **Entree** : ouvrir la categorie ou executer la commande
- **Echap** : remonter d'un niveau (niveau 2 → 1) ou quitter (niveau 1)
- **← Retour** : premiere option du niveau 2, revient au niveau 1

Le menu se redessine en place (un seul bloc ANSI, pas d'empilement).

## Commandes par categorie

### 1. Claude Code

| Commande | Description |
|---|---|
| `cc` | Lancement standard |
| `cc-auto` | Mode auto (pre-approved) |
| `cc-yolo` | Skip toutes les permissions |
| `cc-plan` | Mode planification (read-only) |
| `cc-opus` | Forcer modele Opus |
| `cc-sonnet` | Forcer modele Sonnet |
| `cc-last` | Reprendre derniere session |
| `cc-resume <id>` | Reprendre session par nom ou ID |
| `cc-menu` | Afficher le sous-menu |

### 2. Codex CLI

| Commande | Description |
|---|---|
| `codex-go` | Lancement standard (suggest) |
| `codex-auto` | Mode auto-edit |
| `codex-yolo` | Mode full-auto |
| `codex-menu` | Afficher le sous-menu |

### 3. Gemini CLI

| Commande | Description |
|---|---|
| `gemini-go` | Lancement standard |
| `gemini-sandbox` | Mode sandbox (isole) |
| `gemini-menu` | Afficher le sous-menu |

### 4. Ollama

| Commande | Description |
|---|---|
| `ollama-start` | Demarrer le serveur |
| `ollama-list` | Modeles installes |
| `ollama-run [modele]` | Lancer un modele (defaut : llama3) |
| `ollama-pull <modele>` | Telecharger un modele |
| `ollama-stop` | Arreter Ollama |
| `ollama-menu` | Afficher le sous-menu |

### 5. Docker

| Commande | Description |
|---|---|
| `docker-start` | Lancer Docker Desktop |
| `docker-stop` | Arreter Docker + WSL shutdown |
| `docker-restart` | Redemarrer Docker |
| `docker-ps` | Conteneurs en cours (format table) |
| `docker-clean` | Nettoyer images/cache inutilises |
| `docker-menu` | Afficher le sous-menu |

### 6. WSL Ubuntu

| Commande | Description |
|---|---|
| `wsl-go` | Ouvrir Ubuntu |
| `wsl-restart` | Redemarrer WSL |
| `wsl-list` | Distributions installees |
| `wsl-ip` | Adresse IP de la VM WSL |
| `wsl-menu` | Afficher le sous-menu |

### 7. FlyEnv

| Commande | Description |
|---|---|
| `flyenv-start` | Lancer FlyEnv (PhpWebStudy) |
| `flyenv-menu` | Afficher le sous-menu |

### 8. Git (en francais)

| Commande | Description |
|---|---|
| `git-etat` | git status |
| `git-log` | Historique graphique (20 derniers) |
| `git-diff` | Voir les modifications |
| `git-add [fichier]` | Ajouter (defaut : tout) |
| `git-pull` | Recuperer les changements distants |
| `git-push` | Envoyer les commits |
| `git-menu` | Afficher le sous-menu |

## Navigation rapide

| Commande | Destination |
|---|---|
| `dev` | `C:\Users\Johan\TRAVAUX\PROJETS` |
| `sites` | `C:\Users\Johan\TRAVAUX\SITES` |
| `plugins` | `C:\Users\Johan\TRAVAUX\PLUGINS` |
| `projets` | `C:\Users\Johan\Projets` |
| `cortex` | `C:\Users\Johan\SecondBrain\Cortex` |
| `codehere` / `ch` | Ouvrir VS Code dans le dossier courant |
| `z <mot-cle>` | Navigation intelligente zoxide |

### zoxide

zoxide apprend les repertoires visites et permet d'y sauter par mot-cle :
- `z cortex` → saute dans le dossier Cortex
- `z toilettage` → saute dans le projet toilettage
- `zi` → mode interactif avec fzf

## Utilitaires systeme

| Commande | Description |
|---|---|
| `Switch-Admin` | Ouvrir une console Admin (ou User si deja Admin) |
| `Show-Env` | Afficher versions (PS, Node, Git, SSH, Ollama) |
| `Settings` | Ouvrir le profil dans VS Code ou Notepad |
| `Help` | Aide complete de toutes les commandes |
| `portcheck [port]` | Tester la connexion sur un port (defaut : 80) |

## Modules charges au demarrage

| Module | Role |
|---|---|
| **PSReadLine** | Autocompletion, historique, predictions ListView |
| **CompletionPredictor** | Predictions cmdlets (enrichit PSReadLine) |
| **PSFzf** | Ctrl+R et Ctrl+T via fzf |
| **SecretManagement** | API de coffre de secrets |
| **SecretStore** | Backend de stockage chiffre |
| **Terminal-Icons** | Icones Nerd Font dans `ls` |
| **Chocolatey** | Gestionnaire de paquets |

## Outils binaires requis

| Outil | Installation | Usage |
|---|---|---|
| **fzf** | `winget install junegunn.fzf` | Recherche fuzzy |
| **zoxide** | `winget install ajeetdsouza.zoxide` | Navigation `z` intelligente |
| **gum** | `winget install charmbracelet.gum` | TUI optionnel |

## Prompt

Format : `[ADMIN] ~/chemin (branche-git) > `

- `[ADMIN]` en rouge si console administrateur
- Chemin avec `~` pour le home
- Branche Git en jaune si dans un repo
- Titre fenetre : `PowerShell 7.6 — Admin (JConcept)` ou `PowerShell 7.6 — Johan`

## SSH

Deux cles chargees automatiquement au demarrage :
- `~/.ssh/id_ed25519` — GitHub
- `~/.ssh/id_ed25519_ubuntu` — Ubuntu dev (homelab)

Chargement intelligent : verifie si la cle est deja dans l'agent avant d'appeler `ssh-add`.
