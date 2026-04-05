# Procedure de reinstallation Windows

Guide pas a pas pour reinstaller la stack PowerShell complete apres un formatage ou une installation fraiche de Windows.

## Prerequis

1. **Windows 10/11** a jour
2. **Windows Terminal** installe depuis le Microsoft Store
3. **winget** disponible (inclus dans Windows 11, App Installer sur Windows 10)

## Etapes

### 1. Installer une Nerd Font

Necessaire pour Terminal-Icons (icones dans `ls`).

1. Telecharger [FiraCode Nerd Font](https://github.com/ryanoasis/nerd-fonts/releases) (ou une autre Nerd Font)
2. Extraire le zip
3. Selectionner tous les fichiers `.ttf` → clic droit → **Installer pour tous les utilisateurs**
4. Dans Windows Terminal : Parametres → Profil par defaut → Apparence → Police → selectionner `FiraCode Nerd Font`

### 2. Installer PowerShell 7

```powershell
winget install Microsoft.PowerShell
```

Fermer et rouvrir le terminal. Verifier : `pwsh --version` → `PowerShell 7.6.x`

### 3. Restaurer Cortex (si disponible)

Si le vault Cortex est restaure depuis une sauvegarde :

```powershell
& "$env:USERPROFILE\SecondBrain\Cortex\05-system\scripts\install-powershell-stack.ps1"
```

### 4. Installation depuis le repo Git

Si Cortex n'est pas encore restaure :

```powershell
# Installer git si necessaire
winget install Git.Git

# Cloner le repo
cd "$env:USERPROFILE\Projets"
git clone https://github.com/audi63/powershell-profile-stack.git

# Executer le script d'installation
& ".\powershell-profile-stack\scripts\install-powershell-stack.ps1" -ProfileSource ".\powershell-profile-stack\scripts\Microsoft.PowerShell_profile.ps1"
```

### 5. Fermer et rouvrir le terminal

Le profil se charge automatiquement. Message de bienvenue attendu :

```
PS 7.6.0 | SSH: 0 cle(s) | user | F1 = menu | Ctrl+M = interactif | Ctrl+R = historique
```

### 6. Configurer SSH (optionnel)

```powershell
# Generer une cle GitHub
ssh-keygen -t ed25519 -C "johan.coffigniez@gmail.com" -f "$env:USERPROFILE\.ssh\id_ed25519"

# Generer une cle Ubuntu
ssh-keygen -t ed25519 -C "ubuntu-dev" -f "$env:USERPROFILE\.ssh\id_ed25519_ubuntu"

# Ajouter la cle publique sur GitHub
cat "$env:USERPROFILE\.ssh\id_ed25519.pub" | clip
# → Coller dans https://github.com/settings/keys
```

### 7. Configurer SecretStore (optionnel)

```powershell
& ".\powershell-profile-stack\scripts\install-powershell-stack.ps1" -ConfigureSecretStore
```

## Verification post-installation

```powershell
# Outils binaires
fzf --version
zoxide --version
gum --version

# Modules
Get-InstalledModule | Format-Table Name, Version

# Menu interactif
m

# Environnement
Show-Env
```

## Ce qui est installe

### Modules PowerShell

| Module | Role |
|---|---|
| PSReadLine | Autocompletion, predictions |
| CompletionPredictor | Predictions cmdlets |
| PSFzf | Ctrl+R, Ctrl+T |
| Terminal-Icons | Icones Nerd Font |
| SecretManagement | Coffre de secrets |
| SecretStore | Backend chiffre |
| BurntToast | Notifications Windows |
| ConsoleGuiTools | TUI grid (optionnel) |

### Outils binaires

| Outil | Source | Usage |
|---|---|---|
| fzf | winget / choco | Recherche fuzzy |
| zoxide | winget / choco | Navigation `z` |
| gum | winget | TUI interactive |

### Ce qui n'est PAS installe

- **oh-my-posh** — le prompt est custom dans le profil
- **posh-git** — la branche Git est deja affichee dans le prompt

## Depannage

### Le profil ne se charge pas

```powershell
# Verifier que le profil existe
Test-Path $PROFILE
# Si non : relancer le script d'installation
```

### fzf non trouve apres installation

```powershell
# Le PATH n'est pas mis a jour dans la session courante
# Fermer et rouvrir le terminal, ou :
$env:PATH = [Environment]::GetEnvironmentVariable('PATH', 'User') + ';' + [Environment]::GetEnvironmentVariable('PATH', 'Machine')
```

### Terminal-Icons n'affiche pas d'icones

Verifier que la police Windows Terminal est une **Nerd Font**. Les polices standard (Cascadia Code, Consolas) n'incluent pas les glyphes necessaires.

### Temps de chargement lent

Le profil charge ~8 modules. Temps normal : 2-4 secondes. Pour diagnostiquer :

```powershell
Measure-Command { pwsh -NoProfile -Command "exit" }   # Baseline
Measure-Command { pwsh -Command "exit" }                # Avec profil
```
