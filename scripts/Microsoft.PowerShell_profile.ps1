# ═══════════════════════════════════════════════════════════════════
# PowerShell 7.6 — Profil personnalise
# Dernière mise à jour : 2026-04-05
# ═══════════════════════════════════════════════════════════════════

# ──────────────────────────────────────
# PSReadLine (sans version fixée)
# ──────────────────────────────────────
try {
    Import-Module PSReadLine -ErrorAction Stop

    # CompletionPredictor : enrichit les predictions avec les cmdlets
    if (Get-Module -ListAvailable CompletionPredictor) {
        Import-Module CompletionPredictor -ErrorAction SilentlyContinue
        Set-PSReadLineOption -PredictionSource HistoryAndPlugin
    } else {
        Set-PSReadLineOption -PredictionSource History
    }

    Set-PSReadLineOption -PredictionViewStyle ListView
    Set-PSReadLineOption -EditMode Windows
    Set-PSReadLineOption -HistorySaveStyle SaveIncrementally
    Set-PSReadLineKeyHandler -Key Tab -Function MenuComplete

    # Ctrl+M → menu interactif (m)
    Set-PSReadLineKeyHandler -Chord 'Ctrl+m' -BriefDescription 'MenuInteractif' -Description 'Lancer le menu interactif' -ScriptBlock {
        [Microsoft.PowerShell.PSConsoleReadLine]::RevertLine()
        [Microsoft.PowerShell.PSConsoleReadLine]::Insert('m')
        [Microsoft.PowerShell.PSConsoleReadLine]::AcceptLine()
    }

    # F1 → aide rapide (Show-Menu)
    Set-PSReadLineKeyHandler -Chord 'F1' -BriefDescription 'ShowMenu' -Description 'Afficher le menu' -ScriptBlock {
        [Microsoft.PowerShell.PSConsoleReadLine]::RevertLine()
        [Microsoft.PowerShell.PSConsoleReadLine]::Insert('Show-Menu')
        [Microsoft.PowerShell.PSConsoleReadLine]::AcceptLine()
    }
} catch {
    Write-Host "[profil] PSReadLine non disponible : $_" -ForegroundColor DarkYellow
}

# ──────────────────────────────────────
# Modules différés (chargés au premier idle pour profil rapide)
# PSFzf, Terminal-Icons, SecretManagement, Chocolatey
# ──────────────────────────────────────
Register-EngineEvent -SourceIdentifier PowerShell.OnIdle -MaxTriggerCount 1 -Action {
    # PSFzf — Ctrl+R historique fuzzy, Ctrl+T fichiers
    if (Get-Command fzf -ErrorAction SilentlyContinue) {
        try {
            Import-Module PSFzf -ErrorAction Stop
            Set-PsFzfOption -PSReadlineChordProvider 'Ctrl+t' -PSReadlineChordReverseHistory 'Ctrl+r'
        } catch {}
    }
    # Terminal-Icons — icones dans ls (Nerd Font requise)
    try { Import-Module Terminal-Icons -ErrorAction SilentlyContinue } catch {}
    # SecretManagement
    try {
        Import-Module Microsoft.PowerShell.SecretManagement -ErrorAction SilentlyContinue
        Import-Module Microsoft.PowerShell.SecretStore -ErrorAction SilentlyContinue
    } catch {}
    # Chocolatey
    $choco = "$env:ChocolateyInstall\helpers\chocolateyProfile.psm1"
    if (Test-Path $choco) { Import-Module $choco -ErrorAction SilentlyContinue }
} | Out-Null

# ──────────────────────────────────────
# SSH Agent + Clés automatiques
# ──────────────────────────────────────
if (Get-Service ssh-agent -ErrorAction SilentlyContinue) {
    if ((Get-Service ssh-agent).Status -ne 'Running') {
        try { Start-Service ssh-agent } catch {}
    }

    # Charger toutes les clés disponibles
    $sshKeys = @(
        "$env:USERPROFILE\.ssh\id_ed25519"         # GitHub
        "$env:USERPROFILE\.ssh\id_ed25519_ubuntu"   # Ubuntu dev
    )

    $loadedKeys = ssh-add -l 2>$null
    foreach ($key in $sshKeys) {
        if (Test-Path $key) {
            $pubKey = "$key.pub"
            if ((Test-Path $pubKey) -and $loadedKeys -and ($loadedKeys | Select-String -SimpleMatch (Get-Content $pubKey).Split(" ")[1] -Quiet)) {
                # Clé déjà chargée
            } else {
                ssh-add $key 2>$null | Out-Null
            }
        }
    }
    # Stocker le compte pour le message de bienvenue (évite un 2ème appel ssh-add)
    $script:sshKeyCount = (ssh-add -l 2>$null | Measure-Object).Count
}

# ──────────────────────────────────────
# FNM (Fast Node Manager) — sortie cachée
# ──────────────────────────────────────
if (Get-Command fnm -ErrorAction SilentlyContinue) {
    $fnmCache = "$env:TEMP\fnm-env-cache.ps1"
    if (-not (Test-Path $fnmCache) -or ((Get-Date) - (Get-Item $fnmCache).LastWriteTime).TotalHours -gt 12) {
        fnm env --use-on-cd --shell power-shell | Set-Content $fnmCache -Force
    }
    . $fnmCache
}

# ──────────────────────────────────────
# Node.js global binaries
# ──────────────────────────────────────
$npmGlobal = "$env:APPDATA\npm"
if ((Test-Path $npmGlobal) -and ($env:PATH -notmatch [regex]::Escape($npmGlobal))) {
    $env:PATH += ";$npmGlobal"
}

# ──────────────────────────────────────
# Python
# ──────────────────────────────────────
$pythonPath = "C:\Python313\python.exe"  # ← adapter si necessaire
if (Test-Path $pythonPath) {
    $env:PYTHON = $pythonPath
}

# ──────────────────────────────────────
# Mode admin
# ──────────────────────────────────────
$global:IsAdmin = ([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()
).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)

if ($IsAdmin) {
    $Host.UI.RawUI.WindowTitle = "PowerShell 7.6 — Admin"
} else {
    $Host.UI.RawUI.WindowTitle = "PowerShell 7.6"
}

# ──────────────────────────────────────
# Prompt
# ──────────────────────────────────────
function prompt {
    $path = (Get-Location).Path.Replace($HOME, "~")
    $prefix = if ($IsAdmin) { "[ADMIN] " } else { "" }
    $gitBranch = ""
    if (Get-Command git -ErrorAction SilentlyContinue) {
        $branch = git rev-parse --abbrev-ref HEAD 2>$null
        if ($branch) { $gitBranch = " ($branch)" }
    }
    Write-Host "$prefix" -NoNewline -ForegroundColor $(if ($IsAdmin) { "Red" } else { "DarkGray" })
    Write-Host "$path" -NoNewline -ForegroundColor Cyan
    Write-Host "$gitBranch" -NoNewline -ForegroundColor Yellow
    return " > "
}

# ══════════════════════════════════════════════════════════════
# PALETTE ANSI TRUE COLOR — Degrade arc-en-ciel
# Ordre : bleu → cyan → vert → jaune → orange → rouge → rose
# ══════════════════════════════════════════════════════════════
$script:TC = @{
    Claude   = "`e[38;2;37;99;235m"     #  1  Bleu royal     #2563EB
    Codex    = "`e[38;2;56;189;248m"    #  2  Bleu ciel      #38BDF8
    Gemini   = "`e[38;2;34;211;238m"    #  3  Cyan clair     #22D3EE
    Ollama   = "`e[38;2;45;212;191m"    #  4  Turquoise      #2DD4BF
    Docker   = "`e[38;2;52;211;153m"    #  5  Vert emeraude  #34D399
    WSL      = "`e[38;2;163;230;53m"    #  6  Vert citron    #A3E635
    FlyEnv   = "`e[38;2;250;204;21m"    #  7  Jaune soleil   #FACC15
    Git      = "`e[38;2;245;158;11m"    #  8  Ambre dore     #F59E0B
    Admin    = "`e[38;2;251;146;60m"    #  9  Orange doux    #FB923C
    Env      = "`e[38;2;248;113;113m"   # 10  Rouge corail   #F87171
    Settings = "`e[38;2;236;72;153m"    # 11  Rose framboise #EC4899
    Help     = "`e[38;2;248;250;252m"   # 12  Blanc froid    #F8FAFC
    Text     = "`e[38;2;248;250;252m"   #     Blanc froid    #F8FAFC
    Dim      = "`e[38;2;148;163;184m"   #     Gris doux      #94A3B8
    R        = "`e[0m"                  #     Reset
}

# ══════════════════════════════════════════════════════════════
# FONCTIONS + SOUS-MENUS
# ══════════════════════════════════════════════════════════════

# ──────────────────────────────────────
# 1. Claude Code
# ──────────────────────────────────────
function cc          { claude }
function cc-auto     { claude --permission-mode auto }
function cc-yolo     { claude --dangerously-skip-permissions }
function cc-plan     { claude --permission-mode plan }
function cc-opus     { claude --model opus }
function cc-sonnet   { claude --model sonnet }
function cc-last     { claude --continue }
function cc-resume   { param([string]$s) claude --resume $s }
function cc-menu {
    $c = $TC.Claude; $t = $TC.Text; $r = $TC.R
    Write-Host "`n${c}══════ Claude Code ══════${r}"
    Write-Host "  ${c}cc${r}           ${t}— Lancement standard${r}"
    Write-Host "  ${c}cc-auto${r}      ${t}— Mode auto (pre-approved)${r}"
    Write-Host "  ${c}cc-yolo${r}      ${t}— Skip toutes les permissions${r}"
    Write-Host "  ${c}cc-plan${r}      ${t}— Mode planification (read-only)${r}"
    Write-Host "  ${c}cc-opus${r}      ${t}— Forcer modele Opus${r}"
    Write-Host "  ${c}cc-sonnet${r}    ${t}— Forcer modele Sonnet${r}"
    Write-Host "  ${c}cc-last${r}      ${t}— Reprendre derniere session${r}"
    Write-Host "  ${c}cc-resume X${r}  ${t}— Reprendre session par nom/ID${r}"
    Write-Host "${c}════════════════════════${r}`n"
}

# ──────────────────────────────────────
# 2. Codex CLI
# ──────────────────────────────────────
function codex-go {
    $codexCmd = "$env:APPDATA\npm\codex.cmd"
    if (Test-Path $codexCmd) {
        Start-Process pwsh.exe -ArgumentList "-NoExit", "-NoProfile", "-Command", "& `"$codexCmd`""
    } else { Write-Host "Codex CLI non installe (npm i -g @openai/codex)" -ForegroundColor Yellow }
}
function codex-auto {
    $codexCmd = "$env:APPDATA\npm\codex.cmd"
    if (Test-Path $codexCmd) {
        Start-Process pwsh.exe -ArgumentList "-NoExit", "-NoProfile", "-Command", "& `"$codexCmd`" --approval-mode auto-edit"
    } else { Write-Host "Codex CLI non installe" -ForegroundColor Yellow }
}
function codex-yolo {
    $codexCmd = "$env:APPDATA\npm\codex.cmd"
    if (Test-Path $codexCmd) {
        Start-Process pwsh.exe -ArgumentList "-NoExit", "-NoProfile", "-Command", "& `"$codexCmd`" --approval-mode full-auto"
    } else { Write-Host "Codex CLI non installe" -ForegroundColor Yellow }
}
function codex-menu {
    $c = $TC.Codex; $t = $TC.Text; $r = $TC.R
    Write-Host "`n${c}══════ Codex CLI ══════${r}"
    Write-Host "  ${c}codex-go${r}     ${t}— Lancement standard (suggest)${r}"
    Write-Host "  ${c}codex-auto${r}   ${t}— Mode auto-edit${r}"
    Write-Host "  ${c}codex-yolo${r}   ${t}— Mode full-auto (tout approuve)${r}"
    Write-Host "${c}══════════════════════${r}`n"
}

# ──────────────────────────────────────
# 3. Gemini CLI
# ──────────────────────────────────────
function gemini-go   { Start-Process cmd.exe -ArgumentList "/k", "gemini" }
function gemini-sandbox { Start-Process cmd.exe -ArgumentList "/k", "gemini --sandbox" }
function gemini-menu {
    $c = $TC.Gemini; $t = $TC.Text; $r = $TC.R
    Write-Host "`n${c}══════ Gemini CLI ══════${r}"
    Write-Host "  ${c}gemini-go${r}      ${t}— Lancement standard${r}"
    Write-Host "  ${c}gemini-sandbox${r} ${t}— Mode sandbox (isole)${r}"
    Write-Host "${c}═══════════════════════${r}`n"
}

# ──────────────────────────────────────
# 4. Docker
# ──────────────────────────────────────
function docker-start   { Write-Host "$($TC.Docker)Lancement Docker...$($TC.R)"; Start-Process "C:\Program Files\Docker\Docker\Docker Desktop.exe" }
function docker-stop    { Stop-Process -Name "Docker Desktop" -Force -ErrorAction SilentlyContinue; wsl --shutdown; Write-Host "$($TC.Docker)Docker arrete.$($TC.R)" }
function docker-restart { docker-stop; Start-Sleep 3; docker-start }
function docker-ps      { docker ps --format "table {{.Names}}\t{{.Status}}\t{{.Ports}}" }
function docker-clean   { docker system prune -f; Write-Host "$($TC.Docker)Docker nettoye.$($TC.R)" }
function docker-menu {
    $c = $TC.Docker; $t = $TC.Text; $r = $TC.R
    Write-Host "`n${c}══════ Docker ══════${r}"
    Write-Host "  ${c}docker-start${r}   ${t}— Lancer Docker Desktop${r}"
    Write-Host "  ${c}docker-stop${r}    ${t}— Arreter Docker + WSL${r}"
    Write-Host "  ${c}docker-restart${r} ${t}— Redemarrer Docker${r}"
    Write-Host "  ${c}docker-ps${r}      ${t}— Conteneurs en cours${r}"
    Write-Host "  ${c}docker-clean${r}   ${t}— Nettoyer images/cache inutilises${r}"
    Write-Host "${c}════════════════════${r}`n"
}

# ──────────────────────────────────────
# 5. WSL
# ──────────────────────────────────────
function wsl-go      { wsl -d Ubuntu }
function wsl-restart { wsl --shutdown; Start-Sleep 2; wsl }
function wsl-list    { wsl --list --verbose }
function wsl-ip      { wsl hostname -I }
function wsl-menu {
    $c = $TC.WSL; $t = $TC.Text; $r = $TC.R
    Write-Host "`n${c}══════ WSL ══════${r}"
    Write-Host "  ${c}wsl-go${r}       ${t}— Ouvrir Ubuntu${r}"
    Write-Host "  ${c}wsl-restart${r}  ${t}— Redemarrer WSL${r}"
    Write-Host "  ${c}wsl-list${r}     ${t}— Distributions installees${r}"
    Write-Host "  ${c}wsl-ip${r}       ${t}— Adresse IP de la VM WSL${r}"
    Write-Host "${c}═════════════════${r}`n"
}

# ──────────────────────────────────────
# 6. FlyEnv
# ──────────────────────────────────────
function flyenv-start {
    $flyenvPath = "$env:USERPROFILE\Projets\FlyEnv\PhpWebStudy\PhpWebStudy.exe"  # ← adapter le chemin
    if (Test-Path $flyenvPath) { Start-Process $flyenvPath }
    else { Write-Host "FlyEnv introuvable : $flyenvPath" -ForegroundColor Yellow }
}
function flyenv-menu {
    $c = $TC.FlyEnv; $t = $TC.Text; $d = $TC.Dim; $r = $TC.R
    Write-Host "`n${c}══════ FlyEnv ══════${r}"
    Write-Host "  ${c}flyenv-start${r} ${t}— Lancer FlyEnv (PhpWebStudy)${r}"
    Write-Host "${c}════════════════════${r}`n"
}

# ──────────────────────────────────────
# 7. Ollama
# ──────────────────────────────────────
function ollama-start   { ollama serve }
function ollama-list    { ollama list }
function ollama-run     { param([string]$m = "llama3") ollama run $m }
function ollama-pull    { param([string]$m) ollama pull $m }
function ollama-stop    { Get-Process ollama -ErrorAction SilentlyContinue | Stop-Process -Force; Write-Host "$($TC.Ollama)Ollama arrete.$($TC.R)" }
function ollama-menu {
    $c = $TC.Ollama; $t = $TC.Text; $r = $TC.R
    Write-Host "`n${c}══════ Ollama ══════${r}"
    Write-Host "  ${c}ollama-start${r}    ${t}— Demarrer le serveur Ollama${r}"
    Write-Host "  ${c}ollama-list${r}     ${t}— Modeles installes${r}"
    Write-Host "  ${c}ollama-run X${r}    ${t}— Lancer un modele (defaut: llama3)${r}"
    Write-Host "  ${c}ollama-pull X${r}   ${t}— Telecharger un modele${r}"
    Write-Host "  ${c}ollama-stop${r}     ${t}— Arreter Ollama${r}"
    Write-Host "${c}════════════════════${r}`n"
}

# ──────────────────────────────────────
# 8. Git
# ──────────────────────────────────────
function git-etat { git status }
function git-log  { git log --oneline --graph --all --decorate -20 }
function git-pull { git pull }
function git-push { git push }
function git-diff { git diff }
function git-add  { param([string]$f = ".") git add $f }
function git-menu {
    $c = $TC.Git; $t = $TC.Text; $r = $TC.R
    Write-Host "`n${c}══════ Git ══════${r}"
    Write-Host "  ${c}git-etat${r}     ${t}— Etat du repo (git status)${r}"
    Write-Host "  ${c}git-log${r}      ${t}— Historique graphique${r}"
    Write-Host "  ${c}git-diff${r}     ${t}— Voir les modifications${r}"
    Write-Host "  ${c}git-add${r}      ${t}— Ajouter (git-add . ou git-add fichier)${r}"
    Write-Host "  ${c}git-pull${r}     ${t}— Recuperer les changements distants${r}"
    Write-Host "  ${c}git-push${r}     ${t}— Envoyer les commits${r}"
    Write-Host "${c}═════════════════${r}`n"
}

# ──────────────────────────────────────
# Navigation rapide
# ──────────────────────────────────────
# ── Adapter ces chemins a votre environnement ──
function dev      { Set-Location "$env:USERPROFILE\TRAVAUX\PROJETS" }
function sites    { Set-Location "$env:USERPROFILE\TRAVAUX\SITES" }
function plugins  { Set-Location "$env:USERPROFILE\TRAVAUX\PLUGINS" }
function projets  { Set-Location "$env:USERPROFILE\Projets" }
function obsidian { Set-Location "$env:USERPROFILE\Obsidian" }    # ← adapter au chemin de votre vault
function codehere { code . }
Set-Alias ch codehere

# ──────────────────────────────────────
# Reseau
# ──────────────────────────────────────
function portcheck { param([int]$port = 80) Test-NetConnection -ComputerName localhost -Port $port }

# ──────────────────────────────────────
# Systeme
# ──────────────────────────────────────
function Switch-Admin {
    $pwshPath = (Get-Command pwsh).Source
    if ($IsAdmin) {
        Start-Process -FilePath $pwshPath -ArgumentList "-NoExit"
        Write-Host "$($TC.Admin)Console utilisateur ouverte.$($TC.R)"
    } else {
        Start-Process -FilePath $pwshPath -Verb RunAs -ArgumentList "-NoExit"
        Write-Host "$($TC.Admin)Console admin ouverte.$($TC.R)"
    }
}

function Show-Env {
    $c = $TC.Env; $t = $TC.Text; $r = $TC.R
    Write-Host "`n${c}--- Environnement ---${r}"
    Write-Host "  ${t}PowerShell : $($PSVersionTable.PSVersion)${r}"
    Write-Host "  ${t}Admin      : $IsAdmin${r}"
    $nodeV = node --version 2>$null;  if ($nodeV)  { Write-Host "  ${t}Node.js    : $nodeV${r}" }
    $gitV  = git --version 2>$null;   if ($gitV)   { Write-Host "  ${t}Git        : $gitV${r}" }
    $sshKeys = ssh-add -l 2>$null;    if ($sshKeys) { Write-Host "  ${t}SSH keys   : $($sshKeys.Count) chargee(s)${r}" }
    $ollamaV = ollama --version 2>$null; if ($ollamaV) { Write-Host "  ${t}Ollama     : $ollamaV${r}" }
    Write-Host ""
}

function Settings {
    $profilePath = $PROFILE
    if (Get-Command code -ErrorAction SilentlyContinue) {
        code $profilePath
    } else {
        notepad $profilePath
    }
    Write-Host "$($TC.Settings)Profil ouvert dans l'editeur.$($TC.R)"
}

function Help {
    $t = $TC.Text; $d = $TC.Dim; $r = $TC.R
    Write-Host "`n${t}══════ Aide — Toutes les commandes ══════${r}"
    Write-Host ""
    Write-Host "  ${d}IA${r}"
    Write-Host "  ${t}cc cc-auto cc-yolo cc-plan cc-opus cc-sonnet cc-last cc-resume${r}"
    Write-Host "  ${t}codex-go codex-auto codex-yolo${r}"
    Write-Host "  ${t}gemini-go gemini-sandbox${r}"
    Write-Host "  ${t}ollama-start ollama-list ollama-run ollama-pull ollama-stop${r}"
    Write-Host ""
    Write-Host "  ${d}Infrastructure${r}"
    Write-Host "  ${t}docker-start docker-stop docker-restart docker-ps docker-clean${r}"
    Write-Host "  ${t}wsl-go wsl-restart wsl-list wsl-ip${r}"
    Write-Host "  ${t}flyenv-start${r}"
    Write-Host ""
    Write-Host "  ${d}Git${r}"
    Write-Host "  ${t}git-etat git-log git-diff git-add git-pull git-push${r}"
    Write-Host ""
    Write-Host "  ${d}Navigation${r}"
    Write-Host "  ${t}dev sites plugins projets obsidian codehere (ch)${r}"
    Write-Host "  ${t}z <mot-cle> (zoxide — navigation intelligente)${r}"
    Write-Host ""
    Write-Host "  ${d}Systeme${r}"
    Write-Host "  ${t}Switch-Admin Show-Env Settings portcheck${r}"
    Write-Host ""
    Write-Host "  ${d}Menus et raccourcis${r}"
    Write-Host "  ${t}Show-Menu  m (interactif)  Help${r}"
    Write-Host "  ${t}F1 = menu | Ctrl+M = interactif | Ctrl+R = historique fuzzy${r}"
    Write-Host "  ${t}Ctrl+T = chercher fichier | Tab = completion menu${r}"
    Write-Host "${t}═════════════════════════════════════════${r}`n"
}

# ══════════════════════════════════════════════════════════════
# MENU PRINCIPAL (statique)
# ══════════════════════════════════════════════════════════════
function Show-Menu {
    $r = $TC.R; $t = $TC.Text; $d = $TC.Dim
    Write-Host "`n${d}═══════════${r} ${t}Menu${r} ${d}═══════════════════${r}"
    Write-Host ""
    Write-Host "  $($TC.Claude)cc-menu${r}        ${t}— Claude Code${r}"
    Write-Host "  $($TC.Codex)codex-menu${r}     ${t}— Codex CLI${r}"
    Write-Host "  $($TC.Gemini)gemini-menu${r}    ${t}— Gemini CLI${r}"
    Write-Host "  $($TC.Ollama)ollama-menu${r}    ${t}— Ollama (LLM locaux)${r}"
    Write-Host "  $($TC.Docker)docker-menu${r}    ${t}— Docker${r}"
    Write-Host "  $($TC.WSL)wsl-menu${r}       ${t}— WSL Ubuntu${r}"
    Write-Host "  $($TC.FlyEnv)flyenv-menu${r}    ${t}— FlyEnv${r}"
    Write-Host "  $($TC.Git)git-menu${r}       ${t}— Git${r}"
    Write-Host "  $($TC.Admin)Switch-Admin${r}   ${t}— Basculer Admin/User${r}"
    Write-Host "  $($TC.Env)Show-Env${r}       ${t}— Voir l'environnement${r}"
    Write-Host "  $($TC.Settings)Settings${r}       ${t}— Reglages${r}"
    Write-Host "  $($TC.Help)Help${r}           ${t}— Aide${r}"
    Write-Host ""
    Write-Host "  ${d}Tapez ${t}m${d} ou ${t}Ctrl+M${d} pour le menu interactif | ${t}F1${d} = ce menu${r}"
    Write-Host ""
    Write-Host "${d}══════════════════════════════════${r}`n"
}

# ══════════════════════════════════════════════════════════════
# MENU INTERACTIF (m) — Ctrl+M
# Navigation native ↑↓ avec palette de couleurs
# Options : m (natif) | m -Tool gum|ocgv|fzf|num
# ══════════════════════════════════════════════════════════════

# Donnees partagees entre Show-Menu et m
$script:MenuData = [ordered]@{
    'Claude Code'  = @(
        'cc           — Lancement standard'
        'cc-auto      — Mode auto (pre-approved)'
        'cc-yolo      — Skip toutes les permissions'
        'cc-plan      — Mode planification (read-only)'
        'cc-opus      — Forcer modele Opus'
        'cc-sonnet    — Forcer modele Sonnet'
        'cc-last      — Reprendre derniere session'
        'cc-resume    — Reprendre par nom/ID'
    )
    'Codex CLI'    = @(
        'codex-go     — Lancement standard (suggest)'
        'codex-auto   — Mode auto-edit'
        'codex-yolo   — Mode full-auto'
    )
    'Gemini CLI'   = @(
        'gemini-go       — Lancement standard'
        'gemini-sandbox  — Mode sandbox (isole)'
    )
    'Ollama'       = @(
        'ollama-start — Demarrer le serveur'
        'ollama-list  — Modeles installes'
        'ollama-run   — Lancer un modele (defaut: llama3)'
        'ollama-pull  — Telecharger un modele'
        'ollama-stop  — Arreter Ollama'
    )
    'Docker'       = @(
        'docker-start   — Lancer Docker Desktop'
        'docker-stop    — Arreter Docker + WSL'
        'docker-restart — Redemarrer Docker'
        'docker-ps      — Conteneurs en cours'
        'docker-clean   — Nettoyer images/cache'
    )
    'WSL Ubuntu'   = @(
        'wsl-go      — Ouvrir Ubuntu'
        'wsl-restart — Redemarrer WSL'
        'wsl-list    — Distributions installees'
        'wsl-ip      — Adresse IP WSL'
    )
    'FlyEnv'       = @(
        'flyenv-start — Lancer FlyEnv (PhpWebStudy)'
    )
    'Git'          = @(
        'git-etat — Etat du repo (git status)'
        'git-log  — Historique graphique'
        'git-diff — Voir les modifications'
        'git-add  — Ajouter fichiers'
        'git-pull — Recuperer distant'
        'git-push — Envoyer commits'
    )
}
$script:DirectActions = [ordered]@{
    'Switch-Admin' = 'Basculer Admin/User'
    'Show-Env'     = 'Voir l''environnement'
    'Settings'     = 'Reglages'
    'Help'         = 'Aide'
}
$script:CatColors = @($TC.Claude,$TC.Codex,$TC.Gemini,$TC.Ollama,$TC.Docker,$TC.WSL,$TC.FlyEnv,$TC.Git,$TC.Admin,$TC.Env,$TC.Settings,$TC.Help)

# ── Menu interactif unique : se redessine en place (↑↓ Entree Echap) ──
function m {
    $r = $TC.R; $d = $TC.Dim
    $allCats = @($MenuData.Keys) + @($DirectActions.Keys)
    $savedCursor = [Console]::CursorVisible
    [Console]::CursorVisible = $false

    $level = 1; $catIdx = 0; $subIdx = 0; $selCat = ''
    $prevLines = 0

    try {
        while ($true) {
            # ── Remonter par-dessus l'affichage precedent ──
            if ($prevLines -gt 0) {
                [Console]::Write("`e[${prevLines}A`e[0G")
            }

            # ── Construire l'affichage ──
            $buf = [System.Text.StringBuilder]::new()
            $lineCount = 0

            if ($level -eq 1) {
                [void]$buf.AppendLine("`e[2K"); $lineCount++
                [void]$buf.AppendLine("`e[2K  $($TC.Text)Menu principal${r}  ${d}(↑↓ Entree Echap)${r}"); $lineCount++
                [void]$buf.AppendLine("`e[2K"); $lineCount++
                for ($i = 0; $i -lt $allCats.Count; $i++) {
                    $ic = if ($i -lt $CatColors.Count) { $CatColors[$i] } else { $d }
                    if ($i -eq $catIdx) {
                        [void]$buf.AppendLine("`e[2K  $($TC.Codex)→ $($allCats[$i])${r}")
                    } else {
                        [void]$buf.AppendLine("`e[2K    ${ic}$($allCats[$i])${r}")
                    }
                    $lineCount++
                }
            } else {
                $catI = [array]::IndexOf($allCats, $selCat)
                $cc = if ($catI -ge 0 -and $catI -lt $CatColors.Count) { $CatColors[$catI] } else { $TC.Text }
                $subs = @('← Retour') + $MenuData[$selCat]

                [void]$buf.AppendLine("`e[2K"); $lineCount++
                [void]$buf.AppendLine("`e[2K  ${cc}${selCat}${r}  ${d}(↑↓ Entree Echap)${r}"); $lineCount++
                [void]$buf.AppendLine("`e[2K"); $lineCount++
                for ($i = 0; $i -lt $subs.Count; $i++) {
                    $ic = if ($i -eq 0) { $d } else { $cc }
                    if ($i -eq $subIdx) {
                        [void]$buf.AppendLine("`e[2K  $($TC.Settings)→ $($subs[$i])${r}")
                    } else {
                        [void]$buf.AppendLine("`e[2K    ${ic}$($subs[$i])${r}")
                    }
                    $lineCount++
                }
            }

            # Effacer les lignes residuelles si la vue precedente etait plus longue
            while ($lineCount -lt $prevLines) {
                [void]$buf.AppendLine("`e[2K"); $lineCount++
            }

            # Afficher d'un seul bloc (zero flicker)
            [Console]::Write($buf.ToString())
            $prevLines = $lineCount

            # ── Lire touche ──
            $key = [Console]::ReadKey($true)

            if ($level -eq 1) {
                switch ($key.Key) {
                    'UpArrow'   { $catIdx = if ($catIdx -gt 0) { $catIdx - 1 } else { $allCats.Count - 1 } }
                    'DownArrow' { $catIdx = if ($catIdx -lt $allCats.Count - 1) { $catIdx + 1 } else { 0 } }
                    'Enter' {
                        $sel = $allCats[$catIdx]
                        if ($DirectActions.Contains($sel)) {
                            [Console]::WriteLine(); & $sel; return
                        }
                        $selCat = $sel; $subIdx = 0; $level = 2
                    }
                    'Escape' { [Console]::WriteLine(); return }
                }
            } else {
                $subs = @('← Retour') + $MenuData[$selCat]
                switch ($key.Key) {
                    'UpArrow'   { $subIdx = if ($subIdx -gt 0) { $subIdx - 1 } else { $subs.Count - 1 } }
                    'DownArrow' { $subIdx = if ($subIdx -lt $subs.Count - 1) { $subIdx + 1 } else { 0 } }
                    'Enter' {
                        if ($subIdx -eq 0) { $level = 1; $subIdx = 0 }
                        else {
                            $cmd = ($subs[$subIdx].Trim() -split '\s+')[0]
                            [Console]::WriteLine(); & $cmd; return
                        }
                    }
                    'Escape' { $level = 1; $subIdx = 0 }
                }
            }
        }
    } finally {
        [Console]::CursorVisible = $savedCursor
    }
}

# ──────────────────────────────────────
# zoxide — navigation intelligente (toujours en fin de profil)
# Utiliser : z projets, z obsidian, z monprojet...
# ──────────────────────────────────────
if (Get-Command zoxide -ErrorAction SilentlyContinue) {
    $zoxideCache = "$env:TEMP\zoxide-init-cache.ps1"
    if (-not (Test-Path $zoxideCache) -or ((Get-Date) - (Get-Item $zoxideCache).LastWriteTime).TotalDays -gt 7) {
        zoxide init powershell | Set-Content $zoxideCache -Force
    }
    . $zoxideCache
}

# ──────────────────────────────────────
# Message de bienvenue (réutilise $sshKeyCount calculé lors du chargement SSH)
# ──────────────────────────────────────
Write-Host "$($TC.Dim)PS $($PSVersionTable.PSVersion) | SSH: $($script:sshKeyCount) cle(s) | $(if($IsAdmin){'ADMIN'}else{'user'}) | F1 = menu | Ctrl+M = interactif | Ctrl+R = historique$($TC.R)"
