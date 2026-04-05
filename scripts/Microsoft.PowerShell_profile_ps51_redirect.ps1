# ═══════════════════════════════════════════════════════════════
# Profil PowerShell 5.1 — Redirection auto vers pwsh (7.x, 8.x+)
# Detecte dynamiquement la derniere version installee
# Ne pas modifier — genere par Phase2-Install-Profile.ps1
# ═══════════════════════════════════════════════════════════════

# Chercher pwsh dans le PATH d'abord (methode la plus fiable)
$pwshInPath = Get-Command pwsh -ErrorAction SilentlyContinue

if ($pwshInPath) {
    # pwsh est dans le PATH — on l'utilise directement
    $pwshExe = $pwshInPath.Source
} else {
    # Fallback : chercher dans Program Files (toutes versions)
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

# Si aucun pwsh trouve, on reste en PS 5.1 sans erreur
Write-Host "PowerShell moderne (7+) non installe — session PS 5.1" -ForegroundColor DarkYellow
