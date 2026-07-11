# WinBreak

<div style="display: flex; flex-direction: row">
<p align="left" style="width: 70%">
        <a href="https://github.com/fgirolami29/WinBreak">
            <img alt="WinBreak" src="https://img.shields.io/badge/WinBreak-0.1.0-0078D4?style=for-the-badge&logo=windows11&logoColor=white" />
        </a>
        <a href="https://github.com/fgirolami29/WinBreak/releases/latest">
            <img alt="Latest release" src="https://img.shields.io/github/v/release/fgirolami29/WinBreak?style=for-the-badge&logo=github&logoColor=white">
        </a>
        <a href="https://github.com/fgirolami29/WinBreak/releases">
            <img alt="Release downloads" src="https://img.shields.io/github/downloads/fgirolami29/WinBreak/total?style=for-the-badge&logo=github&logoColor=white">
        </a>
        <a href="https://github.com/fgirolami29/WinBreak/commits/main">
            <img alt="Last commit" src="https://img.shields.io/github/last-commit/fgirolami29/WinBreak?style=for-the-badge&logo=github&logoColor=white" />
        </a>
        <a href="https://github.com/fgirolami29/WinBreak/stargazers">
            <img alt="GitHub stars" src="https://img.shields.io/github/stars/fgirolami29/WinBreak?style=for-the-badge&logo=github&logoColor=white" />
        </a>
        <a href="https://github.com/fgirolami29/WinBreak/network/members">
            <img alt="GitHub forks" src="https://img.shields.io/github/forks/fgirolami29/WinBreak?style=for-the-badge&logo=github&logoColor=white" />
        </a>
        <a href="https://github.com/fgirolami29/WinBreak/issues">
            <img alt="GitHub issues" src="https://img.shields.io/github/issues/fgirolami29/WinBreak?style=for-the-badge&logo=github&logoColor=white" />
        </a>
        <a href="https://github.com/fgirolami29">
            <img alt="fgirolami29" src="https://img.shields.io/badge/Author-Federico_Girolami-181717?style=for-the-badge&logo=github&logoColor=white" />
        </a>
        <a href="https://github.com/CodeCornTech">
            <img alt="CodeCorn Technology" src="https://img.shields.io/badge/CodeCorn-Technology-C1A269?style=for-the-badge&logo=coffeescript&logoColor=white" />
        </a>
        <a href="https://github.com/PytorchiaOrg">
            <img alt="PyTorchia Legion" src="https://img.shields.io/badge/PyTorchia-Legion-%2300BFFF?style=for-the-badge&logo=docker&logoColor=white" />
        </a>
    </p>
    <div style="width: 30%;display:flex;flex-direction:column;justify-content:center;align-items:end;">
        <img alt="CodeCornTechnology™" src="https://i.postimg.cc/TP3ttFM8/CODECORN-trasp-white-ORI.png" width="250px" />
    </div>
</div>

**Windows 11 Requirements Patcher**

<div style="display: flex; flex-direction: row">
    <p align="left" style="width: 70%">
        <a href="https://github.com/fgirolami29/WinBreak">
            <img alt="PowerShell 5.1" src="https://img.shields.io/badge/PowerShell-5.1-5391FE?style=for-the-badge&logo=powershell&logoColor=white" />
        </a>
        <a href="https://www.microsoft.com/windows/windows-11">
            <img alt="Windows 11" src="https://img.shields.io/badge/Windows-11-0078D4?style=for-the-badge&logo=windows11&logoColor=white" />
        </a>
        <a href="https://github.com/pester/Pester">
            <img alt="Tested with Pester" src="https://img.shields.io/badge/Tested_with-Pester-5C2D91?style=for-the-badge&logo=powershell&logoColor=white" />
        </a>
    </p>

</div>

WinBreak è uno script interattivo per Windows 11 e PowerShell 5.1 che prepara una copia locale di un supporto di installazione Windows 11 destinata a sistemi con requisiti hardware non supportati.

Lo script individua e convalida una ISO, mostra le edizioni disponibili, configura i bypass Registry previsti da Microsoft Setup, copia il supporto in una directory di lavoro e rimuove `sources\appraiserres.dll` dalla sola copia. Al termine può aprire il normale installer grafico oppure creare una nuova ISO avviabile con `oscdimg.exe`.

WinBreak non modifica `install.wim`, `install.esd` o `install.swm`, non usa DISM per alterare immagini e non avvia `setup.exe` con parametri nascosti o non documentati.

## Avvertenze importanti

- Usare WinBreak soltanto dopo avere eseguito un backup completo dei dati importanti.
- L'installazione su hardware non supportato può causare problemi di compatibilità, affidabilità, assistenza o disponibilità degli aggiornamenti.
- La verifica del supporto controlla struttura e leggibilità dei metadati: **non è una verifica crittografica** dell'autenticità o dell'integrità della ISO.
- La rimozione di `appraiserres.dll` e i valori Registry descritti qui non garantiscono il superamento di ogni controllo.
- Microsoft può cambiare in qualsiasi momento il comportamento di Windows Setup. Non è garantito che WinBreak funzioni con ogni build futura.
- La directory di lavoro è una copia temporanea completa del supporto. Non usarla per conservare altri file.

## Requisiti

- Windows 11 in una console standard.
- Windows PowerShell 5.1 avviato **come Administrator**.
- Una ISO di Windows 11 leggibile, con build 22000 o successiva.
- Spazio libero sufficiente per la copia del supporto e, se richiesta, per la nuova ISO.
- `robocopy.exe`, incluso in Windows.
- Per creare una nuova ISO: Windows ADK con il componente **Deployment Tools**, che fornisce `oscdimg.exe`.

WinBreak non installa moduli, non scarica software e non apre automaticamente un browser. Pester e PSScriptAnalyzer sono facoltativi e vengono usati per lo sviluppo soltanto se già presenti.

## Download e installazione

WinBreak non richiede un installer e può essere eseguito da qualsiasi directory locale.

### Metodo consigliato: GitHub Release

1. Aprire la sezione [**Releases**](https://github.com/fgirolami29/WinBreak/releases/latest) del repository.
2. Scaricare `WinBreak-0.1.0.zip` dalla release più recente.
3. Fare clic destro sul file ZIP e scegliere **Estrai tutto**.
4. Estrarre l'archivio in una directory locale.

Lo ZIP ufficiale contiene già una directory radice denominata `WinBreak`. Per ottenere il percorso consigliato:

```text
C:\WinBreak
```

impostare come destinazione dell'estrazione:

```text
C:\
```

È possibile estrarre WinBreak anche altrove, per esempio nella cartella Download dell'utente. Non è necessario rinominare o spostare la directory per eseguire il programma.

La struttura risultante sarà:

```text
C:\WinBreak\
|-- WinBreak.ps1
|-- Start-WinBreak.cmd
|-- Start-WinBreak-DryRun.cmd
|-- README.md
|-- CHANGELOG.md
`-- tests\
    `-- WinBreak.Tests.ps1
```

Non eseguire WinBreak direttamente dall'interno del file ZIP: estrarre sempre tutti i file prima dell'avvio.

### Download della branch `main`

Il pulsante GitHub **Code → Download ZIP** scarica invece un archivio dello stato corrente di sviluppo.

Dopo l'estrazione la directory si chiamerà normalmente:

```text
WinBreak-main
```

WinBreak può essere eseguito anche da questa directory, senza rinominarla o spostarla in `C:\WinBreak`.

Per un utilizzo normale è comunque consigliato scaricare una versione stabile dalla sezione **Releases**.

## Avvio facile

Aprire la directory estratta, fare clic destro su:

```text
Start-WinBreak.cmd
```

e scegliere:

```text
Esegui come amministratore
```

Il launcher avvia Windows PowerShell 5.1 con un'Execution Policy temporanea valida soltanto per quel processo.

WinBreak controlla comunque di essere stato avviato con privilegi Administrator. Se la console non è elevata, mostra:

```text
RUNNAMI COME ADMINISTRATOR!
```

e termina senza tentare l'auto-elevazione.

## DryRun facile

Per simulare il flusso senza eseguire le operazioni di sistema, fare clic destro su:

```text
Start-WinBreak-DryRun.cmd
```

e scegliere:

```text
Esegui come amministratore
```

Anche la modalità DryRun richiede una console Administrator.

In DryRun WinBreak descrive le operazioni previste, ma non:

- scrive nel Registry;
- monta o smonta immagini;
- esegue `robocopy`;
- elimina file;
- avvia `setup.exe`;
- esegue `oscdimg.exe`.

Poiché la ISO non viene montata, struttura, metadati ed edizioni vengono indicati come controlli non eseguiti e non come verifiche superate.

## Avvio manuale da PowerShell

In alternativa ai launcher, aprire **Windows PowerShell 5.1 come Administrator** e spostarsi nella directory in cui è stato estratto WinBreak.

Esempio con la directory consigliata:

```powershell
Set-Location "C:\WinBreak"
Set-ExecutionPolicy -Scope Process Bypass -Force
& ".\WinBreak.ps1"
```

La modifica dell'Execution Policy vale soltanto per la sessione PowerShell corrente e non modifica permanentemente la configurazione del sistema.

### DryRun manuale

Anche prima del DryRun deve essere impostata l'Execution Policy per il processo corrente:

```powershell
Set-Location "C:\WinBreak"
Set-ExecutionPolicy -Scope Process Bypass -Force
& ".\WinBreak.ps1" -DryRun
```

Se è stato usato **Code → Download ZIP**, specificare invece il percorso effettivo della directory estratta, per esempio:

```powershell
Set-Location "$env:USERPROFILE\Downloads\WinBreak-main"
Set-ExecutionPolicy -Scope Process Bypass -Force
& ".\WinBreak.ps1" -DryRun
```

## File generati

Log e backup vengono creati all'interno della directory che contiene `WinBreak.ps1`, indipendentemente dalla directory corrente della console:

```text
<directory WinBreak>\
|-- logs\
|   `-- WinBreak-YYYYMMDD-HHMMSS.log
`-- backup\
    |-- registry-YYYYMMDD-HHMMSS-xxxxxxxx.json
    `-- YYYYMMDD-HHMMSS-xxx\
        `-- appraiserres.dll
```

I percorsi operativi predefiniti restano:

| Percorso                       | Uso                                                       |
| ------------------------------ | --------------------------------------------------------- |
| `<directory WinBreak>\logs\`   | Log di console e diagnostica                              |
| `<directory WinBreak>\backup\` | Backup Registry e backup verificato di `appraiserres.dll` |
| `C:\Win11ISO`                  | Copia di lavoro del supporto Windows                      |
| `C:\Windows11Modded.iso`       | ISO prodotta con `oscdimg.exe`                            |

Il backup JSON registra lo stato precedente dei valori Registry, ma WinBreak non esegue un ripristino automatico.

## Parametri

| Parametro        | Descrizione                                   | Predefinito              |
| ---------------- | --------------------------------------------- | ------------------------ |
| `-DryRun`        | Simula le operazioni con effetti sul sistema. | Disattivato              |
| `-KeepMounted`   | Non smonta una ISO montata da WinBreak.       | Disattivato              |
| `-WorkDirectory` | Directory della copia di lavoro.              | `C:\Win11ISO`            |
| `-OutputIso`     | Percorso della ISO generata.                  | `C:\Windows11Modded.iso` |

Esempio manuale con percorsi personalizzati:

```powershell
Set-Location "C:\WinBreak"
Set-ExecutionPolicy -Scope Process Bypass -Force

& ".\WinBreak.ps1" `
    -WorkDirectory "D:\WinBreak Work\Win11ISO" `
    -OutputIso "D:\ISO\Windows11Modded.iso"
```

## Modalità interattiva

### 1. Selezione e verifica della ISO

WinBreak cerca, senza scansione ricorsiva, file ISO compatibili in:

- `C:\`;
- `%USERPROFILE%\Downloads`.

È anche possibile digitare o trascinare nella console un percorso assoluto. Sono supportati percorsi tra virgolette, spazi, variabili ambiente, `~` e completamento con Tab. Escape annulla l'inserimento.

Prima di procedere, WinBreak controlla che il percorso indichi un file `.iso` reale e non vuoto. Dopo il mount verifica almeno:

- `setup.exe`;
- `boot\etfsboot.com`;
- `efi\microsoft\boot`;
- `sources\boot.wim`;
- uno fra `sources\install.wim`, `sources\install.esd` e `sources\install.swm`.

I metadati del payload vengono letti con `Get-WindowsImage` senza alterarlo. La tabella mostra indice, nome, EditionId, architettura e versione di ciascuna immagine. Il supporto è accettato soltanto se contiene almeno un'immagine leggibile e tutte le immagini rilevate hanno build 22000 o successiva.

Se l'immagine era già montata, WinBreak riutilizza il mount e non la smonta automaticamente. Se viene montata da WinBreak, viene smontata al termine della copia o durante il cleanup, salvo uso di `-KeepMounted`.

### 2. Configurazione Registry

WinBreak registra lo stato precedente in un backup JSON, applica in modo idempotente questi DWORD e li rilegge immediatamente per verificarli:

```text
HKLM\SYSTEM\Setup\LabConfig\BypassTPMCheck = 1
HKLM\SYSTEM\Setup\LabConfig\BypassSecureBootCheck = 1
HKLM\SYSTEM\Setup\MoSetup\AllowUpgradesWithUnsupportedTPMOrCPU = 1
```

Sono valori Registry della macchina locale, non variabili d'ambiente. WinBreak non usa `SetX`, non riavvia Explorer e non riavvia PowerShell.

### 3. Preparazione della copia

La destinazione predefinita è `C:\Win11ISO`. Se esiste ed è vuota può essere riutilizzata. Se contiene file, WinBreak richiede di scegliere se eliminarla e ricrearla, usare un'altra directory o annullare: non viene mai cancellata senza una scelta esplicita.

Prima della copia vengono controllati dimensione stimata, spazio libero e separazione tra sorgente e destinazione. La copia usa `robocopy` con almeno:

```text
/MIR /R:2 /W:2 /XJ
```

`/MIR` rende la destinazione uno specchio della sorgente e può rimuovere dalla destinazione elementi non presenti nella sorgente. Per questo `WorkDirectory` deve essere una directory dedicata e priva di dati personali. Gli exit code `0`-`7` sono considerati non bloccanti; `8` o superiore indica un errore.

### 4. Patch della copia

Con la directory di lavoro predefinita, WinBreak opera sul file:

```text
C:\Win11ISO\sources\appraiserres.dll
```

Prima della rimozione ne registra dimensione e SHA256 e ne salva una copia verificata sotto `<directory WinBreak>\backup\<timestamp>\`. Se il file è già assente, viene mostrato un avviso e serve una conferma esplicita per continuare. Il file `appraiser.dll` non viene rimosso. Con `-WorkDirectory`, il percorso sorgente del file segue la directory personalizzata.

## Opzioni finali

### Avvia aggiornamento Windows 11

Dopo conferma e countdown annullabile, con la directory di lavoro predefinita WinBreak avvia esclusivamente:

```text
C:\Win11ISO\setup.exe
```

Il programma non passa argomenti a Setup, non attende la fine dell'aggiornamento e non tenta di determinarne automaticamente l'esito. In particolare non usa `/product server`, `/compat ignorewarning`, `/auto upgrade`, comandi DISM o altri parametri nascosti.

WinBreak **non elimina la directory di lavoro durante l'aggiornamento**. Dopo avere completato e verificato manualmente l'aggiornamento, eliminare la directory di lavoro a mano quando non serve più.

### Crea ISO modificata

Questa opzione richiede `oscdimg.exe` del Windows ADK Deployment Tools. WinBreak lo cerca nel `PATH` e nelle installazioni ADK locali plausibili; se non lo trova, spiega il requisito e torna al menu senza installare o modificare nulla.

La ISO generata include il boot BIOS tramite `boot\etfsboot.com` e il boot UEFI tramite `efisys.bin`, oppure `efisys_noprompt.bin` se necessario. L'output esistente non viene sovrascritto senza conferma. Al termine WinBreak richiede exit code zero, file non vuoto, calcola SHA256 e apre Explorer evidenziando il file.

Dopo una creazione riuscita, usando il valore predefinito, compare:

```text
Rimuovere ora C:\Win11ISO? [S/N]
```

Soltanto una risposta esplicita `S` autorizza il cleanup, dopo i controlli che impediscono l'eliminazione di radice del volume, profilo utente, directory di sistema, directory di output o percorsi non validi.

### Esci senza avviare nulla

Termina normalmente senza avviare Setup o creare una ISO. La directory di lavoro non viene eliminata automaticamente.

## Log, errori e recupero

Ogni operazione importante viene riportata in console e nel log con livello `INFO`, `SUCCESS`, `WARN`, `ERROR` o `DEBUG`. In caso di errore WinBreak:

- mostra un messaggio sintetico;
- salva i dettagli nel log;
- smonta soltanto le immagini che aveva montato, se dovuto;
- conserva la directory di lavoro;
- indica il percorso del log e termina con exit code non zero.

Se l'esecuzione viene interrotta, controllare il log più recente nella directory `logs` accanto a `WinBreak.ps1` e verificare manualmente lo stato del mount e della directory di lavoro prima di riprovare.

## Test non distruttivi

Lo sviluppo non richiede né autorizza un'esecuzione end-to-end. La sintassi può essere verificata con il parser nativo di PowerShell:

```powershell
$tokens = $null
$errors = $null
[System.Management.Automation.Language.Parser]::ParseFile(
    "C:\WinBreak\WinBreak.ps1",
    [ref]$tokens,
    [ref]$errors
) > $null
$errors
```

Se Pester è già installato, eseguire i test puri e isolati con:

```powershell
Invoke-Pester "C:\WinBreak\tests\WinBreak.Tests.ps1"
```

Non eseguire lo script completo come test: un'esecuzione reale può montare supporti, modificare il Registry, copiare o eliminare file e avviare programmi soltanto dopo le conferme previste.

## Limitazioni note

- WinBreak non certifica provenienza, firma o hash ufficiale della ISO.
- Non converte né modifica i payload WIM, ESD o SWM.
- Il payload deve essere leggibile dalla versione locale di `Get-WindowsImage`; se un `install.swm` non è supportato o leggibile dal cmdlet, la validazione termina in sicurezza senza ricorrere a DISM CLI o conversioni.
- Non crea la ISO senza un'installazione locale di Windows ADK Deployment Tools.
- Non ripristina automaticamente i valori Registry precedenti.
- Non monitora l'upgrade e non elimina automaticamente la copia usata da Setup.
- Nessun bypass può garantire supporto hardware, aggiornamenti o compatibilità con future versioni di Windows 11.
