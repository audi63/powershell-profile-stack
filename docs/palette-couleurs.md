# Palette de couleurs ANSI — PowerShell Profile Stack

## Degrade arc-en-ciel (12 couleurs)

Ordre fixe, du bleu au blanc. Chaque couleur est associee a une categorie du menu.

| # | Nom | Hex | RGB | Sequence ANSI | Categorie |
|---|---|---|---|---|---|
| 1 | Bleu royal | `#2563EB` | 37, 99, 235 | `` `e[38;2;37;99;235m `` | Claude Code |
| 2 | Bleu ciel | `#38BDF8` | 56, 189, 248 | `` `e[38;2;56;189;248m `` | Codex CLI |
| 3 | Cyan clair | `#22D3EE` | 34, 211, 238 | `` `e[38;2;34;211;238m `` | Gemini CLI |
| 4 | Turquoise | `#2DD4BF` | 45, 212, 191 | `` `e[38;2;45;212;191m `` | Ollama |
| 5 | Vert emeraude | `#34D399` | 52, 211, 153 | `` `e[38;2;52;211;153m `` | Docker |
| 6 | Vert citron | `#A3E635` | 163, 230, 53 | `` `e[38;2;163;230;53m `` | WSL Ubuntu |
| 7 | Jaune soleil | `#FACC15` | 250, 204, 21 | `` `e[38;2;250;204;21m `` | FlyEnv |
| 8 | Ambre dore | `#F59E0B` | 245, 158, 11 | `` `e[38;2;245;158;11m `` | Git |
| 9 | Orange doux | `#FB923C` | 251, 146, 60 | `` `e[38;2;251;146;60m `` | Switch-Admin |
| 10 | Rouge corail | `#F87171` | 248, 113, 113 | `` `e[38;2;248;113;113m `` | Show-Env |
| 11 | Rose framboise | `#EC4899` | 236, 72, 153 | `` `e[38;2;236;72;153m `` | Settings |
| 12 | Blanc froid | `#F8FAFC` | 248, 250, 252 | `` `e[38;2;248;250;252m `` | Help |

## Couleurs utilitaires

| Nom | Hex | Usage |
|---|---|---|
| Text | `#F8FAFC` | Texte standard (= blanc froid) |
| Dim | `#94A3B8` | Texte secondaire, separateurs |
| R | — | Reset ANSI (`` `e[0m ``) |

## Implementation

Variable `$script:TC` (Theme Colors) dans le profil :

```powershell
$script:TC = @{
    Claude   = "`e[38;2;37;99;235m"     #  1  Bleu royal
    Codex    = "`e[38;2;56;189;248m"    #  2  Bleu ciel
    # ... (voir profil complet)
    Text     = "`e[38;2;248;250;252m"   #     Blanc froid
    Dim      = "`e[38;2;148;163;184m"   #     Gris doux
    R        = "`e[0m"                  #     Reset
}
```

## Prerequis

- **PowerShell 7+** : supporte `` `e `` comme caractere ESC
- **Windows Terminal** : supporte ANSI true color 24-bit nativement
- Ne fonctionne PAS dans PowerShell ISE ni dans `cmd.exe`

## Origine des couleurs

Palette inspiree de [Tailwind CSS](https://tailwindcss.com/docs/customizing-colors) :
blue-600, sky-400, cyan-400, teal-400, emerald-400, lime-400, yellow-400, amber-500, orange-400, red-400, pink-500, slate-50.
