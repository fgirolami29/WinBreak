# WinBreak 0.1.2

## Correzioni

- `setup.exe` viene ora aperto tramite la shell desktop di Windows invece di essere avviato direttamente dal processo Administrator di WinBreak.
- Risolto il caso in cui Windows Setup poteva mostrare l'errore che impediva di determinare la compatibilità del sistema.
- Il pacchetto ZIP viene costruito da una allowlist di file destinati all'utente finale.
- Rimossi dal pacchetto `.gitignore`, `.DS_Store`, `__MACOSX`, test e altri file di sviluppo.

## Contenuto del pacchetto

- `WinBreak.ps1`
- `Start-WinBreak.cmd`
- `Start-WinBreak-DryRun.cmd`
- `README.md`
- `CHANGELOG.md`
