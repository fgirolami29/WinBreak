#!/usr/bin/env python3
from pathlib import Path

VERSION = "0.1.2"


def replace_once(text: str, old: str, new: str, label: str) -> str:
    count = text.count(old)
    if count != 1:
        raise SystemExit(
            f"Patch {label!r}: expected exactly one occurrence, found {count}."
        )
    return text.replace(old, new, 1)


ps_path = Path("WinBreak.ps1")
ps = ps_path.read_text(encoding="utf-8-sig")

ps = replace_once(
    ps,
    "Set-Variable -Name WinBreakVersion -Value '0.1.1' -Option Constant -Scope Script",
    "Set-Variable -Name WinBreakVersion -Value '0.1.2' -Option Constant -Scope Script",
    "PowerShell version",
)

old_launch = """    Write-WinBreakLog -Message 'Il setup verrà avviato senza argomenti.' -Level INFO

    if ($DryRun) {
        Write-WinBreakLog -Message ('[DRYRUN] Start-Process -FilePath "{0}" -WorkingDirectory "{1}"' -f $setupPath, $work) -Level INFO
        return $true
    }
    if (-not (Invoke-WinBreakCountdown -Seconds 10 -CancelKey A)) {
        return $false
    }

    Start-Process -FilePath $setupPath -WorkingDirectory $work | Out-Null
    Write-WinBreakLog -Message 'Installer grafico avviato. WinBreak non attenderà la fine dellʼaggiornamento.' -Level SUCCESS
"""

new_launch = """    Write-WinBreakLog -Message 'Il setup verrà aperto tramite la shell desktop di Windows senza argomenti.' -Level INFO

    if ($DryRun) {
        Write-WinBreakLog -Message ('[DRYRUN] Shell.Application.ShellExecute("{0}", "", "{1}", "open", 1)' -f $setupPath, $work) -Level INFO
        return $true
    }
    if (-not (Invoke-WinBreakCountdown -Seconds 10 -CancelKey A)) {
        return $false
    }

    $shellApplication = $null
    try {
        $shellApplication = New-Object -ComObject Shell.Application
        $shellApplication.ShellExecute($setupPath, '', $work, 'open', 1)
    }
    catch {
        throw ('Impossibile avviare setup.exe tramite Windows Explorer: {0}' -f $_.Exception.Message)
    }
    finally {
        if ($null -ne $shellApplication) {
            try {
                [void][Runtime.InteropServices.Marshal]::FinalReleaseComObject($shellApplication)
            }
            catch {
                # Il rilascio esplicito del COM non deve rendere fallito un avvio già richiesto.
            }
        }
    }

    Write-WinBreakLog -Message 'Richiesta di avvio dellʼinstaller inviata alla shell desktop. WinBreak non attenderà la fine dellʼaggiornamento.' -Level SUCCESS
"""

ps = replace_once(ps, old_launch, new_launch, "unelevated Windows Setup launch")

with ps_path.open("w", encoding="utf-8-sig", newline="\n") as handle:
    handle.write(ps)


readme_path = Path("README.md")
readme = readme_path.read_text(encoding="utf-8")

readme = replace_once(
    readme,
    "WinBreak-0.1.0-0078D4",
    f"WinBreak-{VERSION}-0078D4",
    "README badge version",
)
readme = replace_once(
    readme,
    "`WinBreak-0.1.0.zip`",
    f"`WinBreak-{VERSION}.zip`",
    "README release archive version",
)

description = (
    "WinBreak non modifica `install.wim`, `install.esd` o `install.swm`, "
    "non usa DISM per alterare immagini e non avvia `setup.exe` con "
    "parametri nascosti o non documentati."
)
description_with_launch = description + (
    "\n\nQuando viene scelta l'opzione di aggiornamento, WinBreak delega "
    "l'apertura di `setup.exe` alla shell desktop di Windows. Il controllo "
    "iniziale di compatibilità non viene quindi avviato direttamente dal "
    "processo Administrator di WinBreak; Windows Setup richiederà "
    "autonomamente l'elevazione quando necessaria."
)
readme = replace_once(
    readme,
    description,
    description_with_launch,
    "README setup launch explanation",
)

old_tree = """|-- CHANGELOG.md
`-- tests\\
    `-- WinBreak.Tests.ps1"""
readme = replace_once(
    readme,
    old_tree,
    "`-- CHANGELOG.md",
    "README release archive tree",
)

archive_note = (
    "Non eseguire WinBreak direttamente dall'interno del file ZIP: "
    "estrarre sempre tutti i file prima dell'avvio."
)
archive_note_extended = archive_note + (
    "\n\nIl pacchetto ufficiale viene creato da una allowlist e non contiene "
    "`.gitignore`, `.DS_Store`, `__MACOSX`, test o altri file di sviluppo."
)
readme = replace_once(
    readme,
    archive_note,
    archive_note_extended,
    "README clean archive note",
)

readme_path.write_text(readme, encoding="utf-8")


changelog_path = Path("CHANGELOG.md")
changelog = changelog_path.read_text(encoding="utf-8")

release_sections = """## [0.1.2] - 2026-07-11

### Corretto

- Delegato l'avvio di `setup.exe` alla shell desktop di Windows, evitando che il controllo iniziale di compatibilità venga eseguito direttamente dal processo Administrator di WinBreak.
- Corretto il pacchetto di release: lo ZIP viene creato da una allowlist e non contiene `.gitignore`, `.DS_Store`, `__MACOSX`, test o altri file di sviluppo.
- Aggiornati badge, documentazione e riferimenti al pacchetto stabile.

## [0.1.1] - 2026-07-11

### Aggiunto

- Completato il set di bypass Registry per TPM, Secure Boot, RAM e CPU.
- Aggiunto `AllowUpgradesWithUnsupportedTPMOrCPU` in `MoSetup`.
- Aggiunto `HwReqChkVars` compatibile con il metodo usato da Rufus.
- Aggiunti backup e rimozione verificata delle cache AppCompat.
- Migliorate verifica, backup e diagnostica delle modifiche Registry.

"""

changelog = replace_once(
    changelog,
    "## [0.1.0] - 2026-07-11",
    release_sections + "## [0.1.0] - 2026-07-11",
    "CHANGELOG 0.1.2 and 0.1.1 sections",
)
changelog_path.write_text(changelog, encoding="utf-8")


gitignore_path = Path(".gitignore")
gitignore = gitignore_path.read_text(encoding="utf-8")
if "dist/" not in {line.strip() for line in gitignore.splitlines()}:
    gitignore = gitignore.rstrip() + "\n\n# Release staging\ndist/\n"
gitignore_path.write_text(gitignore, encoding="utf-8")
