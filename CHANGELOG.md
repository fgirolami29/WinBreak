# Changelog

Tutte le modifiche rilevanti di WinBreak sono documentate in questo file.

Il formato segue i principi di [Keep a Changelog](https://keepachangelog.com/it-IT/1.1.0/) e il progetto usa il versionamento semantico.

## [0.1.0] - 2026-07-11

### Aggiunto

- Prima versione di WinBreak per Windows PowerShell 5.1.
- Banner adattivo a colori, controllo Administrator e gestione centralizzata di log ed errori.
- Ricerca non ricorsiva delle ISO in `C:\` e `%USERPROFILE%\Downloads`, selezione interattiva e inserimento percorso con completamento Tab.
- Validazione del file ISO, mount sicuro con rilevamento della proprietà del mount e timeout per la lettera di unità.
- Controllo della struttura del supporto e lettura non distruttiva delle edizioni Windows tramite `Get-WindowsImage`.
- Validazione Windows 11 basata su struttura, metadati leggibili e build minima 22000.
- Backup JSON dello stato Registry, applicazione idempotente e verifica dei bypass TPM, Secure Boot e CPU.
- Preparazione sicura della directory di lavoro, stima dello spazio richiesto e copia con `robocopy`.
- Rimozione verificata di `sources\appraiserres.dll`, con hash SHA256 e backup verificato.
- Avvio del normale `setup.exe` grafico senza argomenti, preceduto da conferma e countdown annullabile.
- Creazione facoltativa di una ISO BIOS/UEFI con `oscdimg.exe`, verifica dell'output e hash SHA256.
- Cleanup protetto della directory di lavoro, eseguito soltanto dopo conferma esplicita.
- Parametri `-DryRun`, `-KeepMounted`, `-WorkDirectory` e `-OutputIso`.
- Test Pester non distruttivi per logica pura, percorsi, menu, exit code, build, cleanup, argomenti `oscdimg`, DryRun e gestione di `appraiserres.dll`.
- Documentazione italiana con procedura di avvio, requisiti, sicurezza, limiti e recupero.

### Sicurezza

- Nessuna modifica dei payload `install.wim`, `install.esd` o `install.swm`.
- Nessun download automatico, auto-elevazione, parametro nascosto di Setup o uso di `Invoke-Expression`.
- Nessuna eliminazione automatica di una directory di lavoro non vuota e nessun cleanup dopo l'avvio dell'upgrade.
- Smontaggio automatico limitato alle immagini montate da WinBreak, salvo `-KeepMounted`.
- Modalità DryRun senza scritture Registry, mount, copie, eliminazioni, avvio di Setup o esecuzione di `oscdimg.exe`.

### Limitazioni

- La validazione del supporto è strutturale e basata sulla leggibilità dei metadati; non è crittografica.
- La creazione della ISO richiede Windows ADK Deployment Tools già installato.
- Il comportamento di Microsoft Setup può cambiare e l'efficacia del metodo non è garantita per build future.
