<#
.SYNOPSIS
    Installation complète de la stack terminal PowerShell — Johan (JConcept)

.DESCRIPTION
    Script idempotent pour (re)installer toute la stack PowerShell après une
    installation fraîche de Windows. Installe les modules, outils binaires,
    déploie le profil PS 7 et le redirect PS 5.1.

    Ce qui est installé :
    - Modules : PSReadLine, CompletionPredictor, PSFzf, SecretManagement,
      SecretStore, BurntToast, ConsoleGuiTools, Terminal-Icons
    - Binaires : fzf, zoxide, gum
    - Profil PS 7 complet (menus, palette ANSI, SSH, etc.)
    - Redirect PS 5.1 → pwsh dynamique

    Ce qui n'est PAS installé :
    - oh-my-posh (prompt custom déjà en place)
    - posh-git (git branch déjà dans le prompt)

.PARAMETER InitializeProfile
    Déployer le profil PowerShell. Défaut : $true

.PARAMETER ConfigureSecretStore
    Enregistrer le coffre SecretStore après installation.

.PARAMETER ProfileSource
    Chemin vers le profil à déployer. Défaut : Cortex backup.

.PARAMETER UseChocolateyFallback
    Utiliser Chocolatey si winget échoue.

.EXAMPLE
    .\install-powershell-stack.ps1
    .\install-powershell-stack.ps1 -ConfigureSecretStore
    .\install-powershell-stack.ps1 -ProfileSource "D:\Backup\profile.ps1"
#>
[CmdletBinding()]
param(
    [bool]$InitializeProfile = $true,
    [switch]$ConfigureSecretStore,
    [string]$ProfileSource,
    [switch]$UseChocolateyFallback
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

# ══════════════════════════════════════════════════════════════
# Fonctions utilitaires
# ══════════════════════════════════════════════════════════════

function Write-Section { param([string]$Title) Write-Host "`n=== $Title ===" -ForegroundColor Cyan }
function Write-Info    { param([string]$Message) Write-Host "[INFO] $Message" -ForegroundColor Gray }
function Write-Ok      { param([string]$Message) Write-Host "[OK] $Message" -ForegroundColor Green }
function Write-WarnMsg { param([string]$Message) Write-Host "[WARN] $Message" -ForegroundColor Yellow }
function Write-ErrMsg  { param([string]$Message) Write-Host "[ERR] $Message" -ForegroundColor Red }

function Test-CommandExists {
    param([Parameter(Mandatory)][string]$Name)
    return [bool](Get-Command $Name -ErrorAction SilentlyContinue)
}

# ══════════════════════════════════════════════════════════════
# Prérequis
# ══════════════════════════════════════════════════════════════

function Ensure-PowerShellCompatible {
    Write-Section 'Verification PowerShell'
    Write-Info "Session : $($PSVersionTable.PSEdition) $($PSVersionTable.PSVersion)"

    if ($PSVersionTable.PSEdition -ne 'Core' -or $PSVersionTable.PSVersion -lt [version]'7.2.0') {
        Write-WarnMsg 'PowerShell 7.2+ requis.'
        if (Test-CommandExists 'winget') {
            Write-Info 'Installation de PowerShell via winget...'
            & winget install --id Microsoft.PowerShell --source winget --accept-source-agreements --accept-package-agreements | Out-Host
            Write-WarnMsg 'Relance ce script dans pwsh.'
            exit 0
        }
        throw 'PowerShell 7.2+ requis. Installe pwsh puis relance.'
    }
    Write-Ok "PowerShell $($PSVersionTable.PSVersion) OK"
}

function Ensure-PowerShellGalleryReady {
    Write-Section 'Preparation PowerShell Gallery'

    try {
        if (-not (Get-PackageProvider -Name NuGet -ErrorAction SilentlyContinue)) {
            Install-PackageProvider -Name NuGet -MinimumVersion 2.8.5.201 -Force -Scope CurrentUser -ErrorAction Stop | Out-Null
            Write-Ok 'NuGet provider installe.'
        } else { Write-Info 'NuGet provider deja present.' }
    } catch { Write-WarnMsg "NuGet : $($_.Exception.Message)" }

    try {
        $repo = Get-PSRepository -Name PSGallery -ErrorAction Stop
        if ($repo.InstallationPolicy -ne 'Trusted') {
            Set-PSRepository -Name PSGallery -InstallationPolicy Trusted
        }
        Write-Ok 'PSGallery approuvee.'
    } catch { throw "PSGallery : $($_.Exception.Message)" }
}

# ══════════════════════════════════════════════════════════════
# Installation modules
# ══════════════════════════════════════════════════════════════

function Install-OrUpdateModule {
    param(
        [Parameter(Mandatory)][string]$Name,
        [string]$MinimumVersion
    )

    $installed = Get-InstalledModule -Name $Name -ErrorAction SilentlyContinue |
        Sort-Object Version -Descending | Select-Object -First 1
    if ($installed) { Write-Info "$Name v$($installed.Version) deja present." }

    $params = @{
        Name         = $Name
        Scope        = 'CurrentUser'
        Force        = $true
        AllowClobber = $true
        ErrorAction  = 'Stop'
    }
    if ($MinimumVersion) { $params.MinimumVersion = $MinimumVersion }

    try {
        Install-Module @params | Out-Null
        Write-Ok "Module : $Name"
    } catch {
        if ($installed) {
            Write-WarnMsg "$Name deja en place, mise a jour impossible : $($_.Exception.Message)"
        } else { throw "Impossible d'installer $Name : $($_.Exception.Message)" }
    }
}

function Install-PowerShellModules {
    Write-Section 'Installation des modules PowerShell'

    $modules = @(
        @{ Name = 'PSReadLine';                                MinimumVersion = '2.2.6' }
        @{ Name = 'CompletionPredictor';                       MinimumVersion = '0.1.0' }
        @{ Name = 'PSFzf';                                     MinimumVersion = '2.6.0' }
        @{ Name = 'Microsoft.PowerShell.SecretManagement';     MinimumVersion = '1.1.2' }
        @{ Name = 'Microsoft.PowerShell.SecretStore';          MinimumVersion = '1.0.6' }
        @{ Name = 'BurntToast';                                MinimumVersion = '1.0.0' }
        @{ Name = 'Microsoft.PowerShell.ConsoleGuiTools';      MinimumVersion = '0.7.7' }
        @{ Name = 'Terminal-Icons';                             MinimumVersion = '0.11.0' }
    )

    foreach ($mod in $modules) {
        Install-OrUpdateModule -Name $mod.Name -MinimumVersion $mod.MinimumVersion
    }
}

# ══════════════════════════════════════════════════════════════
# Installation binaires
# ══════════════════════════════════════════════════════════════

function Install-WithWinget {
    param([string]$Id, [string]$Label)
    if (-not (Test-CommandExists 'winget')) { return $false }
    try {
        $check = winget list --id $Id --exact --accept-source-agreements 2>$null
        if ($LASTEXITCODE -eq 0 -and $check) { Write-Info "$Label deja installe."; return $true }
    } catch {}
    try {
        Write-Info "Installation $Label via winget..."
        & winget install --id $Id --exact --source winget --accept-source-agreements --accept-package-agreements | Out-Host
        if ($LASTEXITCODE -eq 0) { Write-Ok "$Label installe."; return $true }
    } catch { Write-WarnMsg "winget $Label : $($_.Exception.Message)" }
    return $false
}

function Install-WithChocolatey {
    param([string]$Package, [string]$Label)
    if (-not $UseChocolateyFallback -or -not (Test-CommandExists 'choco')) { return $false }
    try {
        & choco install $Package -y --no-progress | Out-Host
        if ($LASTEXITCODE -eq 0) { Write-Ok "$Label installe via Chocolatey."; return $true }
    } catch { Write-WarnMsg "choco $Label : $($_.Exception.Message)" }
    return $false
}

function Ensure-BinaryTool {
    param([string]$CommandName, [string]$Label, [string]$WingetId, [string]$ChocolateyPackage)
    if (Test-CommandExists $CommandName) { Write-Info "$Label deja disponible."; return }
    $ok = Install-WithWinget -Id $WingetId -Label $Label
    if (-not $ok -and $ChocolateyPackage) { $ok = Install-WithChocolatey -Package $ChocolateyPackage -Label $Label }
    if (-not $ok) { Write-WarnMsg "$Label : installation echouee." }
}

function Install-BinaryTools {
    Write-Section 'Installation des outils binaires'
    Ensure-BinaryTool -CommandName 'fzf'    -Label 'fzf'    -WingetId 'junegunn.fzf'       -ChocolateyPackage 'fzf'
    Ensure-BinaryTool -CommandName 'zoxide' -Label 'zoxide' -WingetId 'ajeetdsouza.zoxide' -ChocolateyPackage 'zoxide'
    Ensure-BinaryTool -CommandName 'gum'    -Label 'gum'    -WingetId 'Charmbracelet.Gum'
}

# ══════════════════════════════════════════════════════════════
# SecretStore
# ══════════════════════════════════════════════════════════════

function Configure-SecretStoreIfRequested {
    if (-not $ConfigureSecretStore) { return }
    Write-Section 'Configuration SecretStore'
    try {
        Import-Module Microsoft.PowerShell.SecretManagement -ErrorAction Stop
        Import-Module Microsoft.PowerShell.SecretStore -ErrorAction Stop
        $vault = Get-SecretVault -Name SecretStore -ErrorAction SilentlyContinue
        if (-not $vault) {
            Register-SecretVault -Name SecretStore -ModuleName Microsoft.PowerShell.SecretStore -DefaultVault -ErrorAction Stop
            Write-Ok 'SecretStore enregistre comme coffre par defaut.'
        } else { Write-Ok 'SecretStore deja enregistre.' }
    } catch { Write-WarnMsg "SecretStore : $($_.Exception.Message)" }
}

# ══════════════════════════════════════════════════════════════
# Deploiement du profil
# ══════════════════════════════════════════════════════════════

function Deploy-Profile {
    if (-not $InitializeProfile) {
        Write-Info 'Deploiement du profil ignore par parametre.'
        return
    }

    Write-Section 'Deploiement du profil PowerShell'

    $profilePath = $PROFILE.CurrentUserCurrentHost
    $profileDir  = Split-Path $profilePath -Parent

    # Determiner la source du profil
    $source = $null
    if ($ProfileSource -and (Test-Path $ProfileSource)) {
        $source = $ProfileSource
        Write-Info "Source profil : parametre ($ProfileSource)"
    } else {
        # Chercher le backup Cortex
        $cortexPaths = @(
            "$env:USERPROFILE\SecondBrain\Cortex\05-system\scripts\Microsoft.PowerShell_profile.ps1"
            "C:\Users\Johan\SecondBrain\Cortex\05-system\scripts\Microsoft.PowerShell_profile.ps1"
        )
        foreach ($p in $cortexPaths) {
            if (Test-Path $p) { $source = $p; Write-Info "Source profil : Cortex ($p)"; break }
        }
    }

    if (-not $source) {
        Write-WarnMsg 'Aucune source de profil trouvee (ni parametre, ni Cortex).'
        Write-WarnMsg 'Utilise -ProfileSource pour specifier le chemin du profil.'
        return
    }

    # Backup de l'ancien profil si existant
    if (Test-Path $profilePath) {
        $timestamp = Get-Date -Format 'yyyyMMdd-HHmmss'
        $backup = "$profilePath.bak-$timestamp"
        Copy-Item $profilePath $backup -Force
        Write-Info "Ancien profil sauvegarde : $backup"
    }

    # Creer le dossier si necessaire
    if (-not (Test-Path $profileDir)) {
        New-Item -ItemType Directory -Path $profileDir -Force | Out-Null
    }

    # Copier le profil
    Copy-Item $source $profilePath -Force
    Write-Ok "Profil PS 7 deploye : $profilePath"

    # ── Redirect PS 5.1 ──
    $ps51Dir  = "$env:USERPROFILE\Documents\WindowsPowerShell"
    $ps51Path = "$ps51Dir\Microsoft.PowerShell_profile.ps1"

    if (-not (Test-Path $ps51Dir)) {
        New-Item -ItemType Directory -Path $ps51Dir -Force | Out-Null
    }

    $ps51Content = @'
# Profil PowerShell 5.1 — Redirection auto vers pwsh (7.x, 8.x+)
# Detecte dynamiquement la derniere version installee

$pwshInPath = Get-Command pwsh -ErrorAction SilentlyContinue

if ($pwshInPath) {
    $pwshExe = $pwshInPath.Source
} else {
    $pwshBase = "$env:ProgramFiles\PowerShell"
    if (Test-Path $pwshBase) {
        $latestDir = Get-ChildItem $pwshBase -Directory |
            Where-Object { $_.Name -match '^\d+' } |
            Sort-Object { [int]($_.Name -replace '[^\d].*','') } -Descending |
            Select-Object -First 1
        if ($latestDir -and (Test-Path "$($latestDir.FullName)\pwsh.exe")) {
            $pwshExe = "$($latestDir.FullName)\pwsh.exe"
        }
    }
}

if ($pwshExe) {
    $version = & $pwshExe --version 2>$null
    Write-Host "Basculement vers $version..." -ForegroundColor Cyan
    & $pwshExe -NoLogo
    exit
}

Write-Host "PowerShell moderne (7+) non installe — session PS 5.1" -ForegroundColor DarkYellow
'@

    Set-Content -Path $ps51Path -Value $ps51Content -Encoding UTF8 -Force
    Write-Ok "Redirect PS 5.1 deploye : $ps51Path"
}

# ══════════════════════════════════════════════════════════════
# Execution
# ══════════════════════════════════════════════════════════════

Ensure-PowerShellCompatible
Ensure-PowerShellGalleryReady
Install-PowerShellModules
Install-BinaryTools
Configure-SecretStoreIfRequested
Deploy-Profile

Write-Section 'Resume'
Write-Host ''
Write-Host '  Modules  : PSReadLine, CompletionPredictor, PSFzf, Terminal-Icons' -ForegroundColor White
Write-Host '             SecretManagement, SecretStore, BurntToast, ConsoleGuiTools' -ForegroundColor White
Write-Host '  Binaires : fzf, zoxide, gum' -ForegroundColor White
Write-Host '  Profil   : PS 7 (custom) + redirect PS 5.1' -ForegroundColor White
Write-Host ''
Write-Host '  NON installe : oh-my-posh, posh-git (prompt custom deja en place)' -ForegroundColor DarkGray
Write-Host ''
Write-Host 'Ferme puis rouvre PowerShell/Windows Terminal.' -ForegroundColor Cyan
Write-Host 'Verification : fzf --version ; zoxide --version ; gum --version' -ForegroundColor Cyan
