[CmdletBinding()]
param(
    [switch]$DryRun,
    [switch]$KeepMounted,
    [ValidateNotNullOrEmpty()]
    [string]$WorkDirectory = 'C:\Win11ISO',
    [ValidateNotNullOrEmpty()]
    [string]$OutputIso = 'C:\Windows11Modded.iso'
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

Set-Variable -Name WinBreakName -Value 'WinBreak' -Option Constant -Scope Script
Set-Variable -Name WinBreakVersion -Value '0.1.0' -Option Constant -Scope Script
Set-Variable -Name WinBreakDescription -Value 'Windows 11 Requirements Patcher' -Option Constant -Scope Script
Set-Variable -Name WinBreakAuthor -Value 'Federico Girolami / CodeCorn Technology' -Option Constant -Scope Script
Set-Variable -Name WinBreakIsoNamePattern -Value '(?i)^win(?:dows)?[\s._-]*11.*\.iso$' -Option Constant -Scope Script

$script:WinBreakLogPath = $null
$script:WinBreakLogRoot = 'C:\WinBreak\logs'
$script:WinBreakBackupRoot = 'C:\WinBreak\backup'
$script:WinBreakCleanupFailed = $false

function Write-WinBreakLog {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [AllowEmptyString()]
        [string]$Message,

        [ValidateSet('INFO', 'SUCCESS', 'WARN', 'ERROR', 'DEBUG')]
        [string]$Level = 'INFO',

        [switch]$NoConsole
    )

    $timestamp = Get-Date -Format 'yyyy-MM-dd HH:mm:ss'
    $line = '[{0}] [{1}] {2}' -f $timestamp, $Level, $Message

    if (-not $NoConsole) {
        $color = switch ($Level) {
            'SUCCESS' { 'Green' }
            'WARN' { 'Yellow' }
            'ERROR' { 'Red' }
            'DEBUG' { 'DarkGray' }
            default { 'Gray' }
        }
        Write-Host $Message -ForegroundColor $color
    }

    if (-not [string]::IsNullOrWhiteSpace($script:WinBreakLogPath)) {
        try {
            Add-Content -LiteralPath $script:WinBreakLogPath -Value $line -Encoding UTF8 -ErrorAction Stop
        }
        catch {
            Write-Host ('Impossibile aggiornare il log: {0}' -f $_.Exception.Message) -ForegroundColor Yellow
        }
    }
}

function Initialize-WinBreakLogging {
    [CmdletBinding()]
    param(
        [string]$LogRoot = $script:WinBreakLogRoot
    )

    if (-not (Test-Path -LiteralPath $LogRoot -PathType Container)) {
        New-Item -ItemType Directory -Path $LogRoot -Force | Out-Null
    }

    $logTimestamp = Get-Date
    do {
        $fileName = 'WinBreak-{0}.log' -f $logTimestamp.ToString('yyyyMMdd-HHmmss')
        $script:WinBreakLogPath = Join-Path -Path $LogRoot -ChildPath $fileName
        $logTimestamp = $logTimestamp.AddSeconds(1)
    } while (Test-Path -LiteralPath $script:WinBreakLogPath)
    New-Item -ItemType File -Path $script:WinBreakLogPath -ErrorAction Stop | Out-Null
    return $script:WinBreakLogPath
}

function Get-WinBreakConsoleWidth {
    [CmdletBinding()]
    param()

    try {
        $width = [Console]::WindowWidth
        if ($width -ge 20) {
            return $width
        }
    }
    catch {
        # Alcuni host non espongono WindowWidth.
    }

    return 80
}

function Write-WinBreakBanner {
    [CmdletBinding()]
    param()

    $width = Get-WinBreakConsoleWidth
    Write-Host ''

    if ($width -lt 68) {
        Write-Host $script:WinBreakName -ForegroundColor Cyan
        Write-Host $script:WinBreakDescription -ForegroundColor DarkCyan
        Write-Host ('Versione {0}' -f $script:WinBreakVersion) -ForegroundColor Gray
        Write-Host $script:WinBreakAuthor -ForegroundColor Gray
        Write-Host '███ ███' -ForegroundColor Cyan
        Write-Host '███ ███' -ForegroundColor Cyan
        Write-Host ''
        Write-Host '███ ███' -ForegroundColor Cyan
        Write-Host '███ ███' -ForegroundColor Cyan
        Write-Host ''
        return
    }

    $leftLines = @(
        $script:WinBreakName,
        $script:WinBreakDescription,
        ('Versione {0}' -f $script:WinBreakVersion),
        $script:WinBreakAuthor,
        ''
    )
    $logoLines = @(
        '██████ ██████',
        '██████ ██████',
        '             ',
        '██████ ██████',
        '██████ ██████'
    )
    $leftWidth = 48

    for ($index = 0; $index -lt $logoLines.Count; $index++) {
        $leftText = $leftLines[$index].PadRight($leftWidth)
        $leftColor = if ($index -eq 0) { 'Cyan' } elseif ($index -eq 1) { 'DarkCyan' } else { 'Gray' }
        Write-Host $leftText -NoNewline -ForegroundColor $leftColor
        Write-Host $logoLines[$index] -ForegroundColor Cyan
    }
    Write-Host ''
}

function Test-WinBreakAdministrator {
    [CmdletBinding()]
    param()

    try {
        $identity = [Security.Principal.WindowsIdentity]::GetCurrent()
        $principal = New-Object Security.Principal.WindowsPrincipal($identity)
        return $principal.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
    }
    catch {
        return $false
    }
}

function Test-WinBreakInteractiveHost {
    [CmdletBinding()]
    param()

    try {
        return (-not [Console]::IsInputRedirected)
    }
    catch {
        return $Host.Name -notmatch 'ServerRemoteHost'
    }
}

function Pause-WinBreak {
    [CmdletBinding()]
    param(
        [string]$Message = 'PREMERE UN TASTO PER USCIRE...'
    )

    Write-Host $Message -ForegroundColor Gray
    try {
        [void][Console]::ReadKey($true)
    }
    catch {
        [void](Read-Host)
    }
}

function Format-WinBreakSize {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [long]$Bytes
    )

    if ($Bytes -ge 1TB) { return ('{0:N2} TB' -f ($Bytes / 1TB)) }
    if ($Bytes -ge 1GB) { return ('{0:N2} GB' -f ($Bytes / 1GB)) }
    if ($Bytes -ge 1MB) { return ('{0:N2} MB' -f ($Bytes / 1MB)) }
    if ($Bytes -ge 1KB) { return ('{0:N2} KB' -f ($Bytes / 1KB)) }
    return ('{0} byte' -f $Bytes)
}

function Test-WinBreakIsoFileName {
    [CmdletBinding()]
    param(
        [AllowNull()]
        [string]$Name
    )

    if ([string]::IsNullOrWhiteSpace($Name)) {
        return $false
    }

    return ([IO.Path]::GetExtension($Name) -ieq '.iso' -and $Name -match $script:WinBreakIsoNamePattern)
}

function Select-WinBreakUniqueIsoCandidate {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [AllowEmptyCollection()]
        [object[]]$Candidates
    )

    $seen = @{}
    $unique = New-Object System.Collections.Generic.List[object]

    foreach ($candidate in @($Candidates)) {
        if ($null -eq $candidate) { continue }
        $property = $candidate.PSObject.Properties['FullName']
        if ($null -eq $property) { continue }
        $fullName = [string]$property.Value
        if ([string]::IsNullOrWhiteSpace($fullName)) { continue }

        if (-not $seen.ContainsKey($fullName)) {
            $seen[$fullName] = $true
            [void]$unique.Add($candidate)
        }
    }

    return @($unique | Sort-Object -Property @{ Expression = { ([string]$_.FullName).ToUpperInvariant() } })
}

function Get-WinBreakIsoCandidates {
    [CmdletBinding()]
    param(
        [string[]]$SearchDirectories = @('C:\', (Join-Path -Path $env:USERPROFILE -ChildPath 'Downloads'))
    )

    $candidates = New-Object System.Collections.Generic.List[object]

    foreach ($directory in @($SearchDirectories)) {
        if ([string]::IsNullOrWhiteSpace($directory)) { continue }
        if (-not (Test-Path -LiteralPath $directory -PathType Container)) { continue }

        try {
            $items = @(Get-ChildItem -LiteralPath $directory -Force -ErrorAction Stop)
            foreach ($item in $items) {
                if ($item.PSIsContainer) { continue }
                if (-not (Test-WinBreakIsoFileName -Name $item.Name)) { continue }
                if (-not (Test-Path -LiteralPath $item.FullName -PathType Leaf)) { continue }
                [void]$candidates.Add($item)
            }
        }
        catch {
            Write-WinBreakLog -Message ('Directory ISO non leggibile: {0} ({1})' -f $directory, $_.Exception.Message) -Level DEBUG
        }
    }

    return @(Select-WinBreakUniqueIsoCandidate -Candidates $candidates.ToArray())
}

function ConvertTo-WinBreakMenuChoice {
    [CmdletBinding()]
    param(
        [AllowNull()]
        [string]$InputValue,

        [ValidateRange(0, 2147483647)]
        [int]$CandidateCount
    )

    $value = if ($null -eq $InputValue) { '' } else { $InputValue.Trim() }
    if ($value -ieq 'P') {
        return [pscustomobject]@{ Kind = 'Path'; Index = $null }
    }
    if ($value -ieq 'Q') {
        return [pscustomobject]@{ Kind = 'Quit'; Index = $null }
    }

    $number = 0
    if ([int]::TryParse($value, [ref]$number) -and $number -ge 1 -and $number -le $CandidateCount) {
        return [pscustomobject]@{ Kind = 'Index'; Index = ($number - 1) }
    }

    return [pscustomobject]@{ Kind = 'Invalid'; Index = $null }
}

function Test-WinBreakFullyQualifiedPath {
    [CmdletBinding()]
    param(
        [AllowNull()]
        [string]$Path
    )

    if ([string]::IsNullOrWhiteSpace($Path)) {
        return $false
    }

    if ([IO.Path]::DirectorySeparatorChar -eq '\') {
        if ($Path -match '^[A-Za-z]:[\\/]') { return $true }
        if ($Path -match '^\\\\[^\\/]+[\\/][^\\/]+(?:[\\/].*)?$') { return $true }
        if ($Path -match '^\\\\\?\\[A-Za-z]:\\') { return $true }
        if ($Path -match '^\\\\\?\\UNC\\[^\\]+\\[^\\]+(?:\\.*)?$') { return $true }
        return $false
    }

    return $Path.StartsWith([string][IO.Path]::DirectorySeparatorChar, [StringComparison]::Ordinal)
}

function ConvertFrom-WinBreakPathInput {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [AllowEmptyString()]
        [string]$InputPath,

        [string]$UserProfile = ([Environment]::GetFolderPath('UserProfile')),

        [string]$BasePath = (Get-Location).ProviderPath,

        [switch]$RequireAbsolute
    )

    $value = $InputPath.Trim()
    if ($value.Length -ge 2) {
        $first = $value.Substring(0, 1)
        $last = $value.Substring($value.Length - 1, 1)
        if (($first -eq '"' -and $last -eq '"') -or ($first -eq "'" -and $last -eq "'")) {
            $value = $value.Substring(1, $value.Length - 2).Trim()
        }
    }

    $value = [Environment]::ExpandEnvironmentVariables($value)
    $value = [regex]::Replace(
        $value,
        '(?i)\$env:([A-Za-z_][A-Za-z0-9_]*)',
        [Text.RegularExpressions.MatchEvaluator]{
            param($match)
            $environmentValue = [Environment]::GetEnvironmentVariable($match.Groups[1].Value)
            if ($null -eq $environmentValue) { return $match.Value }
            return $environmentValue
        }
    )

    if ([string]::IsNullOrWhiteSpace($UserProfile)) {
        $UserProfile = $HOME
    }
    if ($value -eq '~') {
        $value = $UserProfile
    }
    elseif ($value -match '^~[\\/]') {
        $value = Join-Path -Path $UserProfile -ChildPath $value.Substring(2)
    }

    if ([string]::IsNullOrWhiteSpace($value)) {
        return ''
    }

    if ($RequireAbsolute -and -not (Test-WinBreakFullyQualifiedPath -Path $value)) {
        throw 'Il percorso deve essere assoluto.'
    }
    if (-not [IO.Path]::IsPathRooted($value)) {
        $value = Join-Path -Path $BasePath -ChildPath $value
    }

    return [IO.Path]::GetFullPath($value)
}

function Get-WinBreakCanonicalPath {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [string]$Path
    )

    $fullPath = [IO.Path]::GetFullPath($Path)
    $root = [IO.Path]::GetPathRoot($fullPath)
    if (-not [string]::IsNullOrWhiteSpace($root) -and $fullPath -ieq $root) {
        return $root
    }

    return $fullPath.TrimEnd([char[]]@([IO.Path]::DirectorySeparatorChar, [IO.Path]::AltDirectorySeparatorChar))
}

function Test-WinBreakPathIsWithin {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [string]$Path,

        [Parameter(Mandatory = $true)]
        [string]$ParentPath
    )

    $candidate = Get-WinBreakCanonicalPath -Path $Path
    $parent = Get-WinBreakCanonicalPath -Path $ParentPath
    if ($candidate.Equals($parent, [StringComparison]::OrdinalIgnoreCase)) {
        return $true
    }

    $separator = [string][IO.Path]::DirectorySeparatorChar
    if ($parent.EndsWith($separator, [StringComparison]::Ordinal)) {
        return $candidate.StartsWith($parent, [StringComparison]::OrdinalIgnoreCase)
    }

    return $candidate.StartsWith(($parent + $separator), [StringComparison]::OrdinalIgnoreCase)
}

function Test-WinBreakPathHasReparsePoint {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [string]$Path
    )

    $current = Get-WinBreakCanonicalPath -Path $Path
    while (-not [string]::IsNullOrWhiteSpace($current)) {
        if (Test-Path -LiteralPath $current) {
            $item = Get-Item -LiteralPath $current -Force -ErrorAction Stop
            if (($item.Attributes -band [IO.FileAttributes]::ReparsePoint) -ne 0) {
                return $true
            }
        }

        $parentInfo = [IO.Directory]::GetParent($current)
        if ($null -eq $parentInfo) { break }
        $parent = Get-WinBreakCanonicalPath -Path $parentInfo.FullName
        if ($parent.Equals($current, [StringComparison]::OrdinalIgnoreCase)) { break }
        $current = $parent
    }

    return $false
}

function Get-WinBreakPathCompletions {
    [CmdletBinding()]
    param(
        [AllowEmptyString()]
        [string]$InputText,

        [string]$UserProfile = ([Environment]::GetFolderPath('UserProfile'))
    )

    try {
        $working = $InputText.Trim()
        if ($working.StartsWith('"')) {
            $working = $working.TrimStart('"')
            if ($working.EndsWith('"')) { $working = $working.Substring(0, $working.Length - 1) }
        }

        if ([string]::IsNullOrWhiteSpace($working)) {
            $expanded = (Get-Location).ProviderPath
            $endsWithSeparator = $true
        }
        else {
            $expanded = ConvertFrom-WinBreakPathInput -InputPath $working -UserProfile $UserProfile
            $endsWithSeparator = $working.EndsWith('\') -or $working.EndsWith('/')
        }
        if ($endsWithSeparator) {
            $parent = $expanded
            $leaf = ''
        }
        else {
            $parent = Split-Path -Path $expanded -Parent
            $leaf = Split-Path -Path $expanded -Leaf
        }

        if ([string]::IsNullOrWhiteSpace($parent) -or -not (Test-Path -LiteralPath $parent -PathType Container)) {
            return @()
        }

        $matches = New-Object System.Collections.Generic.List[object]
        foreach ($item in @(Get-ChildItem -LiteralPath $parent -Force -ErrorAction Stop)) {
            if (-not $item.Name.StartsWith($leaf, [StringComparison]::OrdinalIgnoreCase)) { continue }
            $rank = if (-not $item.PSIsContainer -and $item.Extension -ieq '.iso') { 0 } elseif ($item.PSIsContainer) { 1 } else { 2 }
            [void]$matches.Add([pscustomobject]@{ Item = $item; Rank = $rank })
        }

        $results = New-Object System.Collections.Generic.List[string]
        foreach ($match in @($matches | Sort-Object -Property Rank, @{ Expression = { $_.Item.Name.ToUpperInvariant() } })) {
            $completed = $match.Item.FullName
            if ($match.Item.PSIsContainer) {
                $completed += [IO.Path]::DirectorySeparatorChar
            }
            [void]$results.Add($completed)
        }
        return $results.ToArray()
    }
    catch {
        return @()
    }
}

function Read-PathWithCompletion {
    [CmdletBinding()]
    param(
        [string]$Prompt = 'Percorso ISO: '
    )

    if (-not (Test-WinBreakInteractiveHost)) {
        return Read-Host $Prompt
    }

    $buffer = ''
    $previousLength = 0
    $completionSeed = $null
    $completionMatches = @()
    $completionIndex = -1
    $lastCompletion = $null

    function Write-InputBuffer {
        param([string]$Text)
        $paddingLength = [Math]::Max(0, $previousLength - $Text.Length)
        [Console]::Write("`r{0}{1}{2}" -f $Prompt, $Text, (' ' * $paddingLength))
        [Console]::Write("`r{0}{1}" -f $Prompt, $Text)
    }

    try {
        [Console]::Write($Prompt)
        while ($true) {
            $key = [Console]::ReadKey($true)

            if (($key.Modifiers -band [ConsoleModifiers]::Control) -and $key.Key -eq [ConsoleKey]::C) {
                [Console]::WriteLine()
                throw (New-Object OperationCanceledException('Operazione annullata dall''utente.'))
            }

            switch ($key.Key) {
                ([ConsoleKey]::Enter) {
                    [Console]::WriteLine()
                    return $buffer
                }
                ([ConsoleKey]::Escape) {
                    [Console]::WriteLine()
                    return $null
                }
                ([ConsoleKey]::Backspace) {
                    if ($buffer.Length -gt 0) {
                        $previousLength = $buffer.Length
                        $buffer = $buffer.Substring(0, $buffer.Length - 1)
                        $completionSeed = $null
                        $completionMatches = @()
                        $completionIndex = -1
                        $lastCompletion = $null
                        Write-InputBuffer -Text $buffer
                    }
                }
                ([ConsoleKey]::Tab) {
                    if ($null -eq $completionSeed -or $buffer -ne $lastCompletion) {
                        $completionSeed = $buffer
                        $completionMatches = @(Get-WinBreakPathCompletions -InputText $completionSeed)
                        $completionIndex = -1
                    }
                    if ($completionMatches.Count -gt 0) {
                        $completionIndex = ($completionIndex + 1) % $completionMatches.Count
                        $previousLength = $buffer.Length
                        $buffer = [string]$completionMatches[$completionIndex]
                        $lastCompletion = $buffer
                        Write-InputBuffer -Text $buffer
                    }
                }
                default {
                    if (-not [char]::IsControl($key.KeyChar)) {
                        $previousLength = $buffer.Length
                        $buffer += $key.KeyChar
                        $completionSeed = $null
                        $completionMatches = @()
                        $completionIndex = -1
                        $lastCompletion = $null
                        Write-InputBuffer -Text $buffer
                    }
                }
            }
        }
    }
    catch [OperationCanceledException] {
        throw
    }
    catch {
        Write-Host ''
        return Read-Host $Prompt
    }
}

function Show-WinBreakIsoMenu {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [AllowEmptyCollection()]
        [object[]]$Candidates
    )

    while ($true) {
        Write-Host 'ISO DI WINDOWS 11 RILEVATE' -ForegroundColor Cyan
        if ($Candidates.Count -eq 0) {
            Write-Host 'Nessuna ISO corrispondente trovata nelle directory previste.' -ForegroundColor Yellow
        }

        for ($index = 0; $index -lt $Candidates.Count; $index++) {
            $candidate = $Candidates[$index]
            Write-Host ('[{0}] {1}' -f ($index + 1), $candidate.FullName) -ForegroundColor Gray
            Write-Host ('    Nome: {0} | Dimensione: {1} | Modificata: {2}' -f $candidate.Name, (Format-WinBreakSize -Bytes $candidate.Length), $candidate.LastWriteTime.ToString('yyyy-MM-dd HH:mm:ss')) -ForegroundColor DarkCyan
        }
        Write-Host '[P] Digita percorso' -ForegroundColor Gray
        Write-Host '[Q] Esci' -ForegroundColor Gray

        $parsed = ConvertTo-WinBreakMenuChoice -InputValue (Read-Host 'Scelta') -CandidateCount $Candidates.Count
        switch ($parsed.Kind) {
            'Index' {
                try {
                    $resolvedPath = Resolve-WinBreakIsoPath -Path $Candidates[$parsed.Index].FullName
                    return [pscustomobject]@{ Cancelled = $false; Path = $resolvedPath }
                }
                catch {
                    Write-WinBreakLog -Message ('ISO non valida: {0}' -f $_.Exception.Message) -Level WARN
                }
            }
            'Path' {
                $typedPath = Read-PathWithCompletion -Prompt 'Percorso ISO: '
                if ($null -ne $typedPath -and -not [string]::IsNullOrWhiteSpace($typedPath)) {
                    try {
                        $resolvedPath = Resolve-WinBreakIsoPath -Path $typedPath
                        return [pscustomobject]@{ Cancelled = $false; Path = $resolvedPath }
                    }
                    catch {
                        Write-WinBreakLog -Message ('ISO non valida: {0}' -f $_.Exception.Message) -Level WARN
                    }
                }
            }
            'Quit' {
                return [pscustomobject]@{ Cancelled = $true; Path = $null }
            }
            default {
                Write-Host 'Scelta non valida.' -ForegroundColor Yellow
            }
        }
    }
}

function Resolve-WinBreakIsoPath {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [string]$Path
    )

    $normalized = ConvertFrom-WinBreakPathInput -InputPath $Path -RequireAbsolute
    if ([string]::IsNullOrWhiteSpace($normalized) -or -not [IO.Path]::IsPathRooted($normalized)) {
        throw 'Il percorso ISO deve essere assoluto.'
    }
    if (-not (Test-Path -LiteralPath $normalized -PathType Leaf)) {
        throw ('Il file ISO non esiste o non è un file: {0}' -f $normalized)
    }
    if ([IO.Path]::GetExtension($normalized) -ine '.iso') {
        throw 'Il file selezionato non ha estensione .iso.'
    }

    $resolved = Resolve-Path -LiteralPath $normalized -ErrorAction Stop
    if ($resolved.Provider.Name -ne 'FileSystem') {
        throw 'Il percorso ISO non appartiene al file system.'
    }
    $file = Get-Item -LiteralPath $resolved.ProviderPath -Force -ErrorAction Stop
    if ($file.PSIsContainer) {
        throw 'È stata selezionata una directory al posto di un file ISO.'
    }
    if ($file.Length -le 0) {
        throw 'Il file ISO è vuoto.'
    }

    return $file.FullName
}

function Mount-WinBreakIso {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [string]$IsoPath,

        [ValidateRange(1, 120)]
        [int]$TimeoutSeconds = 20,

        [switch]$KeepMounted,

        [switch]$DryRun
    )

    if ($DryRun) {
        Write-WinBreakLog -Message ('[DRYRUN] Mount-DiskImage -ImagePath "{0}"' -f $IsoPath) -Level INFO
        return [pscustomobject]@{
            ImagePath = $IsoPath
            DiskImage = $null
            Root = $null
            DriveLetter = $null
            MountedByWinBreak = $true
            Dismounted = $false
            DryRun = $true
        }
    }

    $mountedByWinBreak = $false
    try {
        $diskImage = Get-DiskImage -ImagePath $IsoPath -ErrorAction Stop
        if (-not $diskImage.Attached) {
            Write-WinBreakLog -Message ('Montaggio ISO: {0}' -f $IsoPath) -Level INFO
            Mount-DiskImage -ImagePath $IsoPath -ErrorAction Stop | Out-Null
            $mountedByWinBreak = $true
            $diskImage = Get-DiskImage -ImagePath $IsoPath -ErrorAction Stop
        }
        else {
            Write-WinBreakLog -Message 'La ISO è già montata: verrà riutilizzata e non sarà smontata automaticamente.' -Level WARN
        }

        $stopwatch = [Diagnostics.Stopwatch]::StartNew()
        $selectedVolume = $null
        while ($stopwatch.Elapsed.TotalSeconds -lt $TimeoutSeconds) {
            $diskImage = Get-DiskImage -ImagePath $IsoPath -ErrorAction Stop
            $volumes = @($diskImage | Get-Volume -ErrorAction SilentlyContinue | Where-Object { $null -ne $_.DriveLetter })
            if ($volumes.Count -gt 0) {
                $selectedVolume = @($volumes | Sort-Object -Property @{ Expression = { [string]$_.DriveLetter } } | Where-Object {
                    Test-Path -LiteralPath ('{0}:\' -f $_.DriveLetter) -PathType Container
                } | Select-Object -First 1)
                if ($selectedVolume.Count -gt 0) {
                    $selectedVolume = $selectedVolume[0]
                    break
                }
            }
            Start-Sleep -Milliseconds 500
        }
        $stopwatch.Stop()

        if ($null -eq $selectedVolume) {
            throw ('La ISO è montata ma non è stata assegnata una lettera di unità entro {0} secondi.' -f $TimeoutSeconds)
        }

        $driveLetter = [string]$selectedVolume.DriveLetter
        $root = '{0}:\' -f $driveLetter
        Write-WinBreakLog -Message ('ISO disponibile in {0}' -f $root) -Level SUCCESS
        return [pscustomobject]@{
            ImagePath = $IsoPath
            DiskImage = $diskImage
            Root = $root
            DriveLetter = $driveLetter
            MountedByWinBreak = $mountedByWinBreak
            Dismounted = $false
            DryRun = $false
        }
    }
    catch {
        if ($mountedByWinBreak -and -not $KeepMounted) {
            try {
                Dismount-DiskImage -ImagePath $IsoPath -ErrorAction Stop | Out-Null
                Write-WinBreakLog -Message 'ISO smontata dopo un errore di mount.' -Level WARN
            }
            catch {
                Write-WinBreakLog -Message ('Cleanup mount non riuscito: {0}' -f $_.Exception.Message) -Level ERROR
            }
        }
        elseif ($mountedByWinBreak -and $KeepMounted) {
            Write-WinBreakLog -Message ('Il mount non è stato completato, ma la ISO resta montata per -KeepMounted: {0}' -f $IsoPath) -Level WARN
        }
        throw
    }
}

function Dismount-WinBreakIso {
    [CmdletBinding()]
    param(
        [AllowNull()]
        [psobject]$MountInfo,

        [switch]$KeepMounted,

        [switch]$DryRun
    )

    if ($null -eq $MountInfo) { return }
    if (-not $MountInfo.MountedByWinBreak) { return }
    if ($MountInfo.Dismounted) { return }

    if ($KeepMounted) {
        Write-WinBreakLog -Message ('ISO lasciata montata su richiesta: {0}' -f $MountInfo.ImagePath) -Level WARN
        return
    }
    if ($DryRun -or $MountInfo.DryRun) {
        Write-WinBreakLog -Message ('[DRYRUN] Dismount-DiskImage -ImagePath "{0}"' -f $MountInfo.ImagePath) -Level INFO
        $MountInfo.Dismounted = $true
        $MountInfo.MountedByWinBreak = $false
        return
    }

    $current = Get-DiskImage -ImagePath $MountInfo.ImagePath -ErrorAction Stop
    if ($current.Attached) {
        Dismount-DiskImage -ImagePath $MountInfo.ImagePath -ErrorAction Stop | Out-Null
        Write-WinBreakLog -Message 'ISO smontata correttamente.' -Level SUCCESS
    }
    $MountInfo.Dismounted = $true
    $MountInfo.MountedByWinBreak = $false
}

function Get-WinBreakObjectPropertyValue {
    [CmdletBinding()]
    param(
        [AllowNull()]
        [object]$InputObject,

        [Parameter(Mandatory = $true)]
        [string]$PropertyName,

        [AllowNull()]
        [object]$DefaultValue = $null
    )

    if ($null -eq $InputObject) { return $DefaultValue }
    $property = $InputObject.PSObject.Properties[$PropertyName]
    if ($null -eq $property -or $null -eq $property.Value) { return $DefaultValue }
    return $property.Value
}

function ConvertTo-WinBreakArchitectureName {
    [CmdletBinding()]
    param(
        [AllowNull()]
        [object]$Architecture
    )

    $value = [string]$Architecture
    switch ($value.ToUpperInvariant()) {
        '0' { return 'x86' }
        '5' { return 'ARM' }
        '6' { return 'IA64' }
        '9' { return 'x64' }
        '12' { return 'ARM64' }
        'AMD64' { return 'x64' }
        default {
            if ([string]::IsNullOrWhiteSpace($value)) { return 'Sconosciuta' }
            return $value
        }
    }
}

function Get-WinBreakBuildNumber {
    [CmdletBinding()]
    param(
        [AllowNull()]
        [object]$Version
    )

    if ($null -eq $Version) { return -1 }
    try {
        $parsed = if ($Version -is [Version]) { $Version } else { New-Object Version([string]$Version) }
        return [int]$parsed.Build
    }
    catch {
        return -1
    }
}

function Test-WinBreakWindows11Build {
    [CmdletBinding()]
    param(
        [AllowNull()]
        [object]$Version
    )

    return (Get-WinBreakBuildNumber -Version $Version) -ge 22000
}

function Get-WinBreakWindowsEditions {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [string]$PayloadPath
    )

    $summaries = @(Get-WindowsImage -ImagePath $PayloadPath -ErrorAction Stop)
    $editions = New-Object System.Collections.Generic.List[object]

    foreach ($summary in $summaries) {
        $imageIndex = [int](Get-WinBreakObjectPropertyValue -InputObject $summary -PropertyName 'ImageIndex' -DefaultValue 0)
        if ($imageIndex -le 0) { continue }

        $details = Get-WindowsImage -ImagePath $PayloadPath -Index $imageIndex -ErrorAction Stop
        $version = Get-WinBreakObjectPropertyValue -InputObject $details -PropertyName 'Version' -DefaultValue ''
        $imageName = Get-WinBreakObjectPropertyValue -InputObject $details -PropertyName 'ImageName' -DefaultValue (Get-WinBreakObjectPropertyValue -InputObject $summary -PropertyName 'ImageName' -DefaultValue '')
        $editionId = Get-WinBreakObjectPropertyValue -InputObject $details -PropertyName 'EditionId' -DefaultValue 'Sconosciuta'
        $architecture = ConvertTo-WinBreakArchitectureName -Architecture (Get-WinBreakObjectPropertyValue -InputObject $details -PropertyName 'Architecture' -DefaultValue '')

        [void]$editions.Add([pscustomobject]@{
            ImageIndex = $imageIndex
            ImageName = [string]$imageName
            EditionId = [string]$editionId
            Architecture = $architecture
            Version = [string]$version
            BuildNumber = Get-WinBreakBuildNumber -Version $version
        })
    }

    return $editions.ToArray()
}

function Test-WinBreakWindows11Media {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [string]$RootPath
    )

    $errors = New-Object System.Collections.Generic.List[string]
    $requiredEntries = @(
        @{ RelativePath = 'setup.exe'; Type = 'Leaf' },
        @{ RelativePath = 'boot\etfsboot.com'; Type = 'Leaf' },
        @{ RelativePath = 'efi\microsoft\boot'; Type = 'Container' },
        @{ RelativePath = 'sources\boot.wim'; Type = 'Leaf' }
    )

    foreach ($entry in $requiredEntries) {
        $entryPath = Join-Path -Path $RootPath -ChildPath $entry.RelativePath
        if (-not (Test-Path -LiteralPath $entryPath -PathType $entry.Type)) {
            [void]$errors.Add(('Elemento richiesto mancante: {0}' -f $entry.RelativePath))
        }
    }

    $payloadPath = $null
    foreach ($relativePayload in @('sources\install.wim', 'sources\install.esd', 'sources\install.swm')) {
        $candidate = Join-Path -Path $RootPath -ChildPath $relativePayload
        if (Test-Path -LiteralPath $candidate -PathType Leaf) {
            $payloadPath = $candidate
            break
        }
    }
    if ($null -eq $payloadPath) {
        [void]$errors.Add('Payload install.wim, install.esd o install.swm non trovato.')
    }

    $editions = @()
    if ($errors.Count -eq 0) {
        try {
            $editions = @(Get-WinBreakWindowsEditions -PayloadPath $payloadPath)
            if ($editions.Count -eq 0) {
                [void]$errors.Add('Il payload non contiene immagini leggibili.')
            }
            elseif (@($editions | Where-Object { $_.BuildNumber -lt 22000 }).Count -gt 0) {
                [void]$errors.Add('Almeno unʼimmagine ha un build non leggibile o precedente a Windows 11 (22000).')
            }
        }
        catch {
            [void]$errors.Add(('Metadati del payload non leggibili: {0}' -f $_.Exception.Message))
        }
    }

    return [pscustomobject]@{
        IsValid = ($errors.Count -eq 0)
        RootPath = $RootPath
        PayloadPath = $payloadPath
        Editions = $editions
        Errors = $errors.ToArray()
    }
}

function Write-WinBreakEditions {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [object[]]$Editions
    )

    Write-WinBreakLog -Message 'Edizioni Windows rilevate:' -Level INFO
    $table = $Editions | Select-Object ImageIndex, ImageName, EditionId, Architecture, Version | Format-Table -AutoSize | Out-String -Width 220
    Write-Host $table.TrimEnd() -ForegroundColor DarkCyan
    foreach ($edition in $Editions) {
        Write-WinBreakLog -Message ('ImageIndex={0}; ImageName={1}; EditionId={2}; Architecture={3}; Version={4}' -f $edition.ImageIndex, $edition.ImageName, $edition.EditionId, $edition.Architecture, $edition.Version) -Level DEBUG -NoConsole
    }
}

function Get-WinBreakRegistryDefinitions {
    [CmdletBinding()]
    param()

    return @(
        [pscustomobject]@{
            RegPath = 'HKLM\SYSTEM\Setup\LabConfig'
            ProviderPath = 'Registry::HKEY_LOCAL_MACHINE\SYSTEM\Setup\LabConfig'
            ValueName = 'BypassTPMCheck'
        },
        [pscustomobject]@{
            RegPath = 'HKLM\SYSTEM\Setup\LabConfig'
            ProviderPath = 'Registry::HKEY_LOCAL_MACHINE\SYSTEM\Setup\LabConfig'
            ValueName = 'BypassSecureBootCheck'
        },
        [pscustomobject]@{
            RegPath = 'HKLM\SYSTEM\Setup\MoSetup'
            ProviderPath = 'Registry::HKEY_LOCAL_MACHINE\SYSTEM\Setup\MoSetup'
            ValueName = 'AllowUpgradesWithUnsupportedTPMOrCPU'
        }
    )
}

function Get-WinBreakRegistryState {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [psobject]$Definition
    )

    $keyExists = Test-Path -LiteralPath $Definition.ProviderPath
    $valueExists = $false
    $previousValue = $null
    $previousKind = $null

    if ($keyExists) {
        $registryKey = Get-Item -LiteralPath $Definition.ProviderPath -ErrorAction Stop
        $matchingNames = @($registryKey.GetValueNames() | Where-Object { $_ -ieq $Definition.ValueName })
        if ($matchingNames.Count -gt 0) {
            $properties = Get-ItemProperty -LiteralPath $Definition.ProviderPath -Name $Definition.ValueName -ErrorAction Stop
            $property = $properties.PSObject.Properties[$Definition.ValueName]
            if ($null -eq $property) {
                throw ('Impossibile leggere il valore Registry {0}\{1}.' -f $Definition.RegPath, $Definition.ValueName)
            }
            $valueExists = $true
            $previousValue = $property.Value
            $previousKind = [string]$registryKey.GetValueKind($Definition.ValueName)
        }
    }

    return [pscustomobject]@{
        RegPath = $Definition.RegPath
        ProviderPath = $Definition.ProviderPath
        ValueName = $Definition.ValueName
        KeyExisted = $keyExists
        ValueExisted = $valueExists
        PreviousValue = $previousValue
        PreviousKind = $previousKind
    }
}

function Backup-WinBreakRegistryState {
    [CmdletBinding()]
    param(
        [string]$BackupRoot = $script:WinBreakBackupRoot,

        [object[]]$Definitions = (Get-WinBreakRegistryDefinitions)
    )

    $states = New-Object System.Collections.Generic.List[object]
    foreach ($definition in $Definitions) {
        $state = Get-WinBreakRegistryState -Definition $definition
        [void]$states.Add($state)
        Write-WinBreakLog -Message ('Stato Registry: {0}\{1}; chiave={2}; valore={3}; precedente={4}; tipo={5}' -f $state.RegPath, $state.ValueName, $state.KeyExisted, $state.ValueExisted, $state.PreviousValue, $state.PreviousKind) -Level DEBUG
    }

    if (-not (Test-Path -LiteralPath $BackupRoot -PathType Container)) {
        New-Item -ItemType Directory -Path $BackupRoot -Force | Out-Null
    }
    $backupName = 'registry-{0}-{1}.json' -f (Get-Date -Format 'yyyyMMdd-HHmmss-fff'), ([Guid]::NewGuid().ToString('N').Substring(0, 8))
    $backupPath = Join-Path -Path $BackupRoot -ChildPath $backupName
    @($states.ToArray()) | ConvertTo-Json -Depth 5 | Set-Content -LiteralPath $backupPath -Encoding UTF8 -NoNewline
    if (-not (Test-Path -LiteralPath $backupPath -PathType Leaf)) {
        throw 'Creazione del backup Registry non riuscita.'
    }
    Write-WinBreakLog -Message ('Backup Registry creato: {0}' -f $backupPath) -Level SUCCESS

    return [pscustomobject]@{
        Path = $backupPath
        States = $states.ToArray()
    }
}

function Test-WinBreakRegistryValue {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [psobject]$Definition
    )

    $properties = Get-ItemProperty -LiteralPath $Definition.ProviderPath -Name $Definition.ValueName -ErrorAction Stop
    $property = $properties.PSObject.Properties[$Definition.ValueName]
    if ($null -eq $property -or [int]$property.Value -ne 1) {
        throw ('Verifica Registry fallita per {0}\{1}: valore diverso da 1.' -f $Definition.RegPath, $Definition.ValueName)
    }
    $registryKey = Get-Item -LiteralPath $Definition.ProviderPath -ErrorAction Stop
    $kind = [string]$registryKey.GetValueKind($Definition.ValueName)
    if ($kind -ne 'DWord') {
        throw ('Verifica Registry fallita per {0}\{1}: tipo {2}, atteso DWord.' -f $Definition.RegPath, $Definition.ValueName, $kind)
    }
    return $true
}

function Format-WinBreakCommandLine {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [string]$FilePath,

        [Parameter(Mandatory = $true)]
        [AllowEmptyCollection()]
        [string[]]$ArgumentList
    )

    $displayFilePath = if ($FilePath -match '[\s"]') {
        '"{0}"' -f ($FilePath -replace '"', '\"')
    }
    else {
        $FilePath
    }
    $displayArguments = foreach ($argument in $ArgumentList) {
        if ($argument -match '[\s"]') {
            '"{0}"' -f ($argument -replace '"', '\"')
        }
        else {
            $argument
        }
    }
    return (($displayFilePath) + ' ' + ($displayArguments -join ' ')).Trim()
}

function Invoke-WinBreakNativeCommand {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [string]$FilePath,

        [Parameter(Mandatory = $true)]
        [AllowEmptyCollection()]
        [string[]]$ArgumentList
    )

    $previousErrorActionPreference = $ErrorActionPreference
    $output = @()
    $exitCode = $null
    $invocationError = $null
    try {
        $ErrorActionPreference = 'Continue'
        $output = @(& $FilePath @ArgumentList 2>&1)
        $exitCode = $LASTEXITCODE
    }
    catch {
        $invocationError = $_
    }
    finally {
        $ErrorActionPreference = $previousErrorActionPreference
    }
    if ($null -ne $invocationError) {
        throw $invocationError
    }
    if ($null -eq $exitCode) {
        throw ('Impossibile determinare lʼexit code di {0}.' -f $FilePath)
    }
    return [pscustomobject]@{
        ExitCode = $exitCode
        Output = $output
    }
}

function Set-WinBreakRegistryBypasses {
    [CmdletBinding()]
    param(
        [switch]$DryRun,

        [string]$BackupRoot = $script:WinBreakBackupRoot
    )

    $definitions = @(Get-WinBreakRegistryDefinitions)
    if ($DryRun) {
        Write-WinBreakLog -Message ('[DRYRUN] Backup JSON dello stato Registry in {0}' -f $BackupRoot) -Level INFO
        foreach ($definition in $definitions) {
            $arguments = @('add', $definition.RegPath, '/v', $definition.ValueName, '/t', 'REG_DWORD', '/d', '1', '/f')
            Write-WinBreakLog -Message ('[DRYRUN] {0}' -f (Format-WinBreakCommandLine -FilePath 'reg.exe' -ArgumentList $arguments)) -Level INFO
        }
        return [pscustomobject]@{ Changed = $false; Planned = $true; BackupPath = $null }
    }

    $backup = Backup-WinBreakRegistryState -BackupRoot $BackupRoot -Definitions $definitions
    foreach ($definition in $definitions) {
        $matchingStates = @($backup.States | Where-Object { $_.ProviderPath -eq $definition.ProviderPath -and $_.ValueName -eq $definition.ValueName })
        if ($matchingStates.Count -ne 1) {
            throw ('Backup Registry incompleto per {0}\{1}.' -f $definition.RegPath, $definition.ValueName)
        }
        $state = $matchingStates[0]
        $alreadyCorrect = $false
        if ($state.ValueExisted -and $state.PreviousKind -eq 'DWord') {
            try {
                $alreadyCorrect = ([Convert]::ToInt64($state.PreviousValue) -eq 1)
            }
            catch {
                $alreadyCorrect = $false
            }
        }

        if ($alreadyCorrect) {
            Write-WinBreakLog -Message ('Registry già configurato: {0}\{1}' -f $definition.RegPath, $definition.ValueName) -Level DEBUG
        }
        else {
            $arguments = @('add', $definition.RegPath, '/v', $definition.ValueName, '/t', 'REG_DWORD', '/d', '1', '/f')
            Write-WinBreakLog -Message (Format-WinBreakCommandLine -FilePath 'reg.exe' -ArgumentList $arguments) -Level INFO
            $result = Invoke-WinBreakNativeCommand -FilePath 'reg.exe' -ArgumentList $arguments
            foreach ($line in $result.Output) {
                Write-WinBreakLog -Message ([string]$line) -Level DEBUG -NoConsole
            }
            if ($result.ExitCode -ne 0) {
                throw ('reg.exe ha restituito exit code {0} per {1}.' -f $result.ExitCode, $definition.ValueName)
            }
        }

        [void](Test-WinBreakRegistryValue -Definition $definition)
        Write-WinBreakLog -Message ('Registry verificato: {0}\{1} = DWORD 1' -f $definition.RegPath, $definition.ValueName) -Level SUCCESS
    }

    return [pscustomobject]@{ Changed = $true; Planned = $false; BackupPath = $backup.Path }
}

function Read-WinBreakConfirmation {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [string]$Prompt
    )

    while ($true) {
        $answer = (Read-Host $Prompt).Trim()
        if ($answer -ieq 'S') { return $true }
        if ($answer -ieq 'N') { return $false }
        Write-Host 'Rispondere S oppure N.' -ForegroundColor Yellow
    }
}

function Resolve-WinBreakDirectoryPath {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [string]$Path
    )

    $normalized = ConvertFrom-WinBreakPathInput -InputPath $Path -RequireAbsolute
    if ([string]::IsNullOrWhiteSpace($normalized) -or -not [IO.Path]::IsPathRooted($normalized)) {
        throw 'La directory di lavoro deve avere un percorso assoluto.'
    }
    return Get-WinBreakCanonicalPath -Path $normalized
}

function Test-WinBreakCleanupPath {
    [CmdletBinding()]
    param(
        [AllowNull()]
        [AllowEmptyString()]
        [string]$Path,

        [AllowNull()]
        [AllowEmptyString()]
        [string]$ExpectedWorkDirectory,

        [AllowNull()]
        [AllowEmptyString()]
        [string]$OutputIso,

        [string]$UserProfile = ([Environment]::GetFolderPath('UserProfile')),
        [string]$SystemRoot = $env:SystemRoot,
        [string]$ProgramFiles = $env:ProgramFiles,
        [string]$ProgramFilesX86 = ${env:ProgramFiles(x86)},
        [string]$ProgramData = $env:ProgramData,
        [string]$BackupRoot = 'C:\WinBreak'
    )

    if ([string]::IsNullOrWhiteSpace($Path) -or [string]::IsNullOrWhiteSpace($ExpectedWorkDirectory)) {
        return [pscustomobject]@{ IsSafe = $false; Reason = 'Percorso vuoto o directory attesa non definita.' }
    }

    try {
        $candidate = Get-WinBreakCanonicalPath -Path $Path
        $expected = Get-WinBreakCanonicalPath -Path $ExpectedWorkDirectory
    }
    catch {
        return [pscustomobject]@{ IsSafe = $false; Reason = 'Percorso non valido.' }
    }

    if (-not $candidate.Equals($expected, [StringComparison]::OrdinalIgnoreCase)) {
        return [pscustomobject]@{ IsSafe = $false; Reason = 'Il percorso non coincide con la work directory attesa.' }
    }

    try {
        if (Test-WinBreakPathHasReparsePoint -Path $candidate) {
            return [pscustomobject]@{ IsSafe = $false; Reason = 'La work directory o un suo antenato è un reparse point.' }
        }
    }
    catch {
        return [pscustomobject]@{ IsSafe = $false; Reason = 'Impossibile verificare gli antenati della work directory.' }
    }

    $root = [IO.Path]::GetPathRoot($candidate)
    if ([string]::IsNullOrWhiteSpace($root) -or $candidate.Equals($root, [StringComparison]::OrdinalIgnoreCase)) {
        return [pscustomobject]@{ IsSafe = $false; Reason = 'Una radice di unità non può essere eliminata.' }
    }

    $protectedExactOrAncestor = @($UserProfile)
    foreach ($protectedPath in $protectedExactOrAncestor) {
        if ([string]::IsNullOrWhiteSpace($protectedPath)) { continue }
        try {
            $protected = Get-WinBreakCanonicalPath -Path $protectedPath
            if ($candidate.Equals($protected, [StringComparison]::OrdinalIgnoreCase) -or (Test-WinBreakPathIsWithin -Path $protected -ParentPath $candidate)) {
                return [pscustomobject]@{ IsSafe = $false; Reason = 'Il percorso coincide con il profilo utente o con un suo antenato.' }
            }
        }
        catch { }
    }

    $systemPaths = @($SystemRoot, $ProgramFiles, $ProgramFilesX86, $ProgramData, $BackupRoot)
    foreach ($systemPath in $systemPaths) {
        if ([string]::IsNullOrWhiteSpace($systemPath)) { continue }
        try {
            $protected = Get-WinBreakCanonicalPath -Path $systemPath
            if ((Test-WinBreakPathIsWithin -Path $candidate -ParentPath $protected) -or (Test-WinBreakPathIsWithin -Path $protected -ParentPath $candidate)) {
                return [pscustomobject]@{ IsSafe = $false; Reason = ('Il percorso interessa una directory protetta: {0}' -f $protected) }
            }
        }
        catch { }
    }

    if (-not [string]::IsNullOrWhiteSpace($OutputIso)) {
        try {
            $output = Get-WinBreakCanonicalPath -Path $OutputIso
            if (Test-WinBreakPathHasReparsePoint -Path $output) {
                return [pscustomobject]@{ IsSafe = $false; Reason = 'La ISO di output o un suo antenato è un reparse point.' }
            }
            if (Test-WinBreakPathIsWithin -Path $output -ParentPath $candidate) {
                return [pscustomobject]@{ IsSafe = $false; Reason = 'La ISO di output si trova dentro la work directory.' }
            }
        }
        catch {
            return [pscustomobject]@{ IsSafe = $false; Reason = 'Percorso della ISO di output non valido.' }
        }
    }

    if (Test-Path -LiteralPath $candidate) {
        try {
            $item = Get-Item -LiteralPath $candidate -Force -ErrorAction Stop
            if (-not $item.PSIsContainer) {
                return [pscustomobject]@{ IsSafe = $false; Reason = 'La work directory non è una directory.' }
            }
        }
        catch {
            return [pscustomobject]@{ IsSafe = $false; Reason = 'Impossibile verificare la work directory.' }
        }
    }

    return [pscustomobject]@{ IsSafe = $true; Reason = 'Percorso verificato.' }
}

function Remove-WinBreakWorkDirectorySafely {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [string]$Path,

        [Parameter(Mandatory = $true)]
        [string]$ExpectedWorkDirectory,

        [string]$OutputIso,

        [switch]$DryRun
    )

    $safety = Test-WinBreakCleanupPath -Path $Path -ExpectedWorkDirectory $ExpectedWorkDirectory -OutputIso $OutputIso
    if (-not $safety.IsSafe) {
        throw ('Eliminazione rifiutata: {0}' -f $safety.Reason)
    }

    if ($DryRun) {
        Write-WinBreakLog -Message ('[DRYRUN] Remove-Item -LiteralPath "{0}" -Recurse -Force' -f $Path) -Level INFO
        return $true
    }

    if (-not (Test-Path -LiteralPath $Path -PathType Container)) {
        return $true
    }
    $resolved = (Resolve-Path -LiteralPath $Path -ErrorAction Stop).ProviderPath
    $secondCheck = Test-WinBreakCleanupPath -Path $resolved -ExpectedWorkDirectory $ExpectedWorkDirectory -OutputIso $OutputIso
    if (-not $secondCheck.IsSafe) {
        throw ('Eliminazione rifiutata al controllo finale: {0}' -f $secondCheck.Reason)
    }

    Remove-Item -LiteralPath $resolved -Recurse -Force -ErrorAction Stop
    if (Test-Path -LiteralPath $resolved) {
        throw ('Impossibile eliminare la work directory: {0}' -f $resolved)
    }
    Write-WinBreakLog -Message ('Work directory eliminata: {0}' -f $resolved) -Level SUCCESS
    return $true
}

function Initialize-WinBreakWorkDirectory {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [string]$Path,

        [string]$OutputIso,

        [switch]$DryRun
    )

    $currentPath = $Path
    while ($true) {
        $resolved = Resolve-WinBreakDirectoryPath -Path $currentPath
        $workSafety = Test-WinBreakCleanupPath -Path $resolved -ExpectedWorkDirectory $resolved -OutputIso $OutputIso
        if (-not $workSafety.IsSafe) {
            throw ('Work directory non sicura: {0}' -f $workSafety.Reason)
        }

        if (-not (Test-Path -LiteralPath $resolved)) {
            if ($DryRun) {
                Write-WinBreakLog -Message ('[DRYRUN] Creazione work directory: {0}' -f $resolved) -Level INFO
            }
            else {
                New-Item -ItemType Directory -Path $resolved -Force | Out-Null
                Write-WinBreakLog -Message ('Work directory creata: {0}' -f $resolved) -Level SUCCESS
            }
            return $resolved
        }

        if (-not (Test-Path -LiteralPath $resolved -PathType Container)) {
            throw ('Il percorso della work directory è occupato da un file: {0}' -f $resolved)
        }

        $firstItem = Get-ChildItem -LiteralPath $resolved -Force -ErrorAction Stop | Select-Object -First 1
        if ($null -eq $firstItem) {
            Write-WinBreakLog -Message ('Work directory vuota riutilizzata: {0}' -f $resolved) -Level INFO
            return $resolved
        }

        Write-Host 'La work directory esiste e non è vuota.' -ForegroundColor Yellow
        Write-Host '[1] Elimina e ricrea' -ForegroundColor Gray
        Write-Host '[2] Scegli unʼaltra directory' -ForegroundColor Gray
        Write-Host '[3] Annulla' -ForegroundColor Gray
        $choice = (Read-Host 'Scelta').Trim()
        switch ($choice) {
            '1' {
                [void](Remove-WinBreakWorkDirectorySafely -Path $resolved -ExpectedWorkDirectory $resolved -OutputIso $OutputIso -DryRun:$DryRun)
                if (-not $DryRun) {
                    New-Item -ItemType Directory -Path $resolved -Force | Out-Null
                }
                return $resolved
            }
            '2' {
                $newPath = Read-PathWithCompletion -Prompt 'Nuova work directory: '
                if ($null -ne $newPath -and -not [string]::IsNullOrWhiteSpace($newPath)) {
                    try {
                        $candidatePath = Resolve-WinBreakDirectoryPath -Path $newPath
                        $candidateSafety = Test-WinBreakCleanupPath -Path $candidatePath -ExpectedWorkDirectory $candidatePath -OutputIso $OutputIso
                        if (-not $candidateSafety.IsSafe) {
                            throw ('Percorso non sicuro: {0}' -f $candidateSafety.Reason)
                        }
                        $currentPath = $candidatePath
                    }
                    catch {
                        Write-WinBreakLog -Message ('Work directory non valida: {0}' -f $_.Exception.Message) -Level WARN
                    }
                }
            }
            '3' { return $null }
            default { Write-Host 'Scelta non valida.' -ForegroundColor Yellow }
        }
    }
}

function Get-WinBreakRequiredSpace {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [string]$SourcePath
    )

    $sum = (Get-ChildItem -LiteralPath $SourcePath -Recurse -Force -ErrorAction Stop | Where-Object { -not $_.PSIsContainer } | Measure-Object -Property Length -Sum).Sum
    if ($null -eq $sum) { return [long]0 }
    return [long]$sum
}

function Get-WinBreakAvailableSpace {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [string]$Path
    )

    $root = [IO.Path]::GetPathRoot((Get-WinBreakCanonicalPath -Path $Path))
    if ([string]::IsNullOrWhiteSpace($root)) {
        throw ('Impossibile determinare lʼunità di destinazione per {0}.' -f $Path)
    }
    $drive = New-Object IO.DriveInfo($root)
    return [long]$drive.AvailableFreeSpace
}

function Test-WinBreakRobocopyExitCode {
    [CmdletBinding()]
    param(
        [int]$ExitCode
    )

    return ($ExitCode -ge 0 -and $ExitCode -le 7)
}

function New-WinBreakRobocopyArguments {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [string]$SourcePath,

        [Parameter(Mandatory = $true)]
        [string]$DestinationPath
    )

    $source = Get-WinBreakCanonicalPath -Path $SourcePath
    $sourceRoot = [IO.Path]::GetPathRoot($source)
    if ($source -ieq $sourceRoot) {
        $source = Join-Path -Path $source -ChildPath '.'
    }
    $destination = Get-WinBreakCanonicalPath -Path $DestinationPath
    return @($source, $destination, '/MIR', '/R:2', '/W:2', '/XJ')
}

function Copy-WinBreakMedia {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [string]$SourceRoot,

        [Parameter(Mandatory = $true)]
        [string]$WorkDirectory,

        [switch]$DryRun
    )

    $arguments = New-WinBreakRobocopyArguments -SourcePath $SourceRoot -DestinationPath $WorkDirectory
    $command = Format-WinBreakCommandLine -FilePath 'robocopy.exe' -ArgumentList $arguments
    Write-WinBreakLog -Message $command -Level INFO

    if ($DryRun) {
        Write-WinBreakLog -Message '[DRYRUN] Robocopy non eseguito.' -Level INFO
        return [pscustomobject]@{ Success = $true; Planned = $true; ExitCode = $null }
    }

    $source = Get-WinBreakCanonicalPath -Path $SourceRoot
    $destination = Get-WinBreakCanonicalPath -Path $WorkDirectory
    if (-not (Test-Path -LiteralPath $source -PathType Container)) {
        throw ('Sorgente ISO non accessibile: {0}' -f $source)
    }
    if (-not (Test-Path -LiteralPath $destination -PathType Container)) {
        throw ('Work directory non accessibile: {0}' -f $destination)
    }
    if ($source.Equals($destination, [StringComparison]::OrdinalIgnoreCase)) {
        throw 'Sorgente e destinazione coincidono.'
    }
    if (Test-WinBreakPathIsWithin -Path $destination -ParentPath $source) {
        throw 'La work directory non può trovarsi dentro la ISO montata.'
    }
    if (Test-WinBreakPathHasReparsePoint -Path $destination) {
        throw 'La work directory non può attraversare reparse point.'
    }

    $requiredSpace = Get-WinBreakRequiredSpace -SourcePath $source
    $availableSpace = Get-WinBreakAvailableSpace -Path $destination
    Write-WinBreakLog -Message ('Spazio richiesto stimato: {0}; disponibile: {1}' -f (Format-WinBreakSize -Bytes $requiredSpace), (Format-WinBreakSize -Bytes $availableSpace)) -Level INFO
    if ($availableSpace -lt $requiredSpace) {
        throw ('Spazio insufficiente: servono almeno {0}, disponibili {1}.' -f (Format-WinBreakSize -Bytes $requiredSpace), (Format-WinBreakSize -Bytes $availableSpace))
    }

    $result = Invoke-WinBreakNativeCommand -FilePath 'robocopy.exe' -ArgumentList $arguments
    foreach ($line in $result.Output) {
        Write-WinBreakLog -Message ([string]$line) -Level DEBUG -NoConsole
    }
    Write-WinBreakLog -Message ('Exit code robocopy: {0}' -f $result.ExitCode) -Level DEBUG
    if (-not (Test-WinBreakRobocopyExitCode -ExitCode $result.ExitCode)) {
        throw ('Robocopy ha restituito un errore bloccante (exit code {0}).' -f $result.ExitCode)
    }

    foreach ($check in @(
        @{ Path = (Join-Path $destination 'setup.exe'); Type = 'Leaf' },
        @{ Path = (Join-Path $destination 'sources'); Type = 'Container' },
        @{ Path = (Join-Path $destination 'boot'); Type = 'Container' }
    )) {
        if (-not (Test-Path -LiteralPath $check.Path -PathType $check.Type)) {
            throw ('Verifica post-copia fallita: {0}' -f $check.Path)
        }
    }

    Write-WinBreakLog -Message 'Contenuto ISO copiato e verificato.' -Level SUCCESS
    return [pscustomobject]@{ Success = $true; Planned = $false; ExitCode = $result.ExitCode }
}

function Remove-WinBreakAppraiser {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [string]$WorkDirectory,

        [switch]$DryRun,

        [string]$BackupRoot = $script:WinBreakBackupRoot
    )

    $sourcesDirectory = Join-Path -Path $WorkDirectory -ChildPath 'sources'
    $appraiserPath = Join-Path -Path $sourcesDirectory -ChildPath 'appraiserres.dll'
    if (-not (Test-Path -LiteralPath $appraiserPath -PathType Leaf)) {
        Write-WinBreakLog -Message ('appraiserres.dll non è presente: {0}' -f $appraiserPath) -Level WARN
        if ($DryRun) {
            Write-WinBreakLog -Message '[DRYRUN] Sarebbe richiesta conferma prima di continuare.' -Level INFO
            return [pscustomobject]@{ Continued = $true; Removed = $false; Planned = $true; BackupPath = $null }
        }
        $continue = Read-WinBreakConfirmation -Prompt 'Continuare senza appraiserres.dll? [S/N]'
        return [pscustomobject]@{ Continued = $continue; Removed = $false; Planned = $false; BackupPath = $null }
    }

    $file = Get-Item -LiteralPath $appraiserPath -Force -ErrorAction Stop
    $hash = (Get-FileHash -LiteralPath $appraiserPath -Algorithm SHA256 -ErrorAction Stop).Hash
    Write-WinBreakLog -Message ('appraiserres.dll: dimensione={0}; SHA256={1}' -f $file.Length, $hash) -Level INFO

    if ($DryRun) {
        Write-WinBreakLog -Message ('[DRYRUN] Backup e rimozione di {0}' -f $appraiserPath) -Level INFO
        return [pscustomobject]@{ Continued = $true; Removed = $false; Planned = $true; BackupPath = $null }
    }

    if (Test-WinBreakPathIsWithin -Path $BackupRoot -ParentPath $WorkDirectory) {
        throw 'La directory di backup di appraiserres.dll deve trovarsi fuori dalla work directory.'
    }
    $backupFolderName = '{0}-{1}' -f (Get-Date -Format 'yyyyMMdd-HHmmss-fff'), ([Guid]::NewGuid().ToString('N').Substring(0, 8))
    $backupDirectory = Join-Path -Path $BackupRoot -ChildPath $backupFolderName
    New-Item -ItemType Directory -Path $backupDirectory -ErrorAction Stop | Out-Null
    $backupPath = Join-Path -Path $backupDirectory -ChildPath 'appraiserres.dll'
    Copy-Item -LiteralPath $appraiserPath -Destination $backupPath -Force -ErrorAction Stop
    if (-not (Test-Path -LiteralPath $backupPath -PathType Leaf)) {
        throw 'Backup di appraiserres.dll non riuscito; il file originale non è stato rimosso.'
    }
    $backupHash = (Get-FileHash -LiteralPath $backupPath -Algorithm SHA256 -ErrorAction Stop).Hash
    if ($backupHash -ne $hash) {
        throw 'Il backup di appraiserres.dll non supera la verifica SHA256.'
    }

    Remove-Item -LiteralPath $appraiserPath -Force -ErrorAction Stop
    if (Test-Path -LiteralPath $appraiserPath) {
        throw 'appraiserres.dll risulta ancora presente dopo la rimozione.'
    }

    Write-WinBreakLog -Message ('appraiserres.dll rimosso; backup: {0}' -f $backupPath) -Level SUCCESS
    return [pscustomobject]@{ Continued = $true; Removed = $true; Planned = $false; BackupPath = $backupPath }
}

function Find-WinBreakOscdimg {
    [CmdletBinding()]
    param()

    $command = Get-Command -Name 'oscdimg.exe' -CommandType Application -ErrorAction SilentlyContinue | Select-Object -First 1
    if ($null -ne $command) {
        return $command.Source
    }

    $fixedCandidates = @(
        'C:\Program Files (x86)\Windows Kits\10\Assessment and Deployment Kit\Deployment Tools\amd64\Oscdimg\oscdimg.exe',
        'C:\Program Files (x86)\Windows Kits\10\Assessment and Deployment Kit\Deployment Tools\x86\Oscdimg\oscdimg.exe',
        'C:\Program Files\Windows Kits\10\Assessment and Deployment Kit\Deployment Tools\amd64\Oscdimg\oscdimg.exe',
        'C:\Program Files\Windows Kits\10\Assessment and Deployment Kit\Deployment Tools\x86\Oscdimg\oscdimg.exe'
    )
    foreach ($candidate in $fixedCandidates) {
        if (Test-Path -LiteralPath $candidate -PathType Leaf) {
            return (Get-Item -LiteralPath $candidate -Force).FullName
        }
    }

    $controlledPatterns = @(
        'C:\Program Files (x86)\Windows Kits\10\Assessment and Deployment Kit\Deployment Tools\*\Oscdimg\oscdimg.exe',
        'C:\Program Files\Windows Kits\10\Assessment and Deployment Kit\Deployment Tools\*\Oscdimg\oscdimg.exe'
    )
    $matches = New-Object System.Collections.Generic.List[string]
    foreach ($pattern in $controlledPatterns) {
        foreach ($item in @(Get-Item -Path $pattern -Force -ErrorAction SilentlyContinue)) {
            if (-not $item.PSIsContainer) { [void]$matches.Add($item.FullName) }
        }
    }
    $sortedMatches = @($matches | Sort-Object)
    if ($sortedMatches.Count -eq 0) {
        return $null
    }
    return $sortedMatches[0]
}

function Resolve-WinBreakOutputIsoPath {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [string]$Path
    )

    $normalized = ConvertFrom-WinBreakPathInput -InputPath $Path -RequireAbsolute
    if ([string]::IsNullOrWhiteSpace($normalized) -or -not [IO.Path]::IsPathRooted($normalized)) {
        throw 'Il percorso della ISO di output deve essere assoluto.'
    }
    if ([IO.Path]::GetExtension($normalized) -ine '.iso') {
        throw 'La ISO di output deve avere estensione .iso.'
    }
    return Get-WinBreakCanonicalPath -Path $normalized
}

function Resolve-WinBreakOutputConflict {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [string]$OutputIso,

        [Parameter(Mandatory = $true)]
        [string]$WorkDirectory,

        [switch]$DryRun
    )

    $output = Resolve-WinBreakOutputIsoPath -Path $OutputIso
    while (Test-Path -LiteralPath $output) {
        Write-Host ('La ISO di output esiste già: {0}' -f $output) -ForegroundColor Yellow
        Write-Host '[1] Sovrascrivi' -ForegroundColor Gray
        Write-Host '[2] Cambia percorso' -ForegroundColor Gray
        Write-Host '[3] Annulla' -ForegroundColor Gray
        $choice = (Read-Host 'Scelta').Trim()

        if ($choice -eq '1') {
            if ($DryRun) {
                Write-WinBreakLog -Message ('[DRYRUN] Remove-Item -LiteralPath "{0}" -Force' -f $output) -Level INFO
            }
            else {
                Remove-Item -LiteralPath $output -Force -ErrorAction Stop
                Write-WinBreakLog -Message ('ISO di output precedente rimossa: {0}' -f $output) -Level INFO
            }
            return [pscustomobject]@{ Cancelled = $false; Path = $output }
        }
        if ($choice -eq '2') {
            $newOutput = Read-PathWithCompletion -Prompt 'Nuovo percorso ISO: '
            if ($null -ne $newOutput -and -not [string]::IsNullOrWhiteSpace($newOutput)) {
                try {
                    $candidateOutput = Resolve-WinBreakOutputIsoPath -Path $newOutput
                    if (Test-WinBreakPathIsWithin -Path $candidateOutput -ParentPath $WorkDirectory) {
                        throw 'La ISO di output non può trovarsi dentro la work directory.'
                    }
                    if (Test-WinBreakPathHasReparsePoint -Path $candidateOutput) {
                        throw 'Il percorso di output non può attraversare reparse point.'
                    }
                    $output = $candidateOutput
                }
                catch {
                    Write-WinBreakLog -Message ('Percorso output non valido: {0}' -f $_.Exception.Message) -Level WARN
                }
            }
            continue
        }
        if ($choice -eq '3') {
            return [pscustomobject]@{ Cancelled = $true; Path = $output }
        }
        Write-Host 'Scelta non valida.' -ForegroundColor Yellow
    }

    return [pscustomobject]@{ Cancelled = $false; Path = $output }
}

function New-WinBreakOscdimgArguments {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [string]$WorkDirectory,

        [Parameter(Mandatory = $true)]
        [string]$OutputIso,

        [Parameter(Mandatory = $true)]
        [string]$BiosBootFile,

        [Parameter(Mandatory = $true)]
        [string]$UefiBootFile
    )

    $bootData = '-bootdata:2#p0,e,b{0}#pEF,e,b{1}' -f $BiosBootFile, $UefiBootFile
    return @('-m', '-o', '-u2', '-udfver102', $bootData, (Get-WinBreakCanonicalPath -Path $WorkDirectory), (Get-WinBreakCanonicalPath -Path $OutputIso))
}

function Build-WinBreakIso {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [string]$WorkDirectory,

        [Parameter(Mandatory = $true)]
        [string]$OutputIso,

        [switch]$DryRun,

        [AllowNull()]
        [string]$OscdimgPath
    )

    $work = Resolve-WinBreakDirectoryPath -Path $WorkDirectory
    $output = Resolve-WinBreakOutputIsoPath -Path $OutputIso
    if ((Test-WinBreakPathHasReparsePoint -Path $work) -or (Test-WinBreakPathHasReparsePoint -Path $output)) {
        throw 'Work directory e percorso di output non possono attraversare reparse point.'
    }
    if (Test-WinBreakPathIsWithin -Path $output -ParentPath $work) {
        throw 'La ISO di output non può trovarsi dentro la work directory.'
    }

    $biosBootFile = Join-Path -Path $work -ChildPath 'boot\etfsboot.com'
    $primaryUefiFile = Join-Path -Path $work -ChildPath 'efi\microsoft\boot\efisys.bin'
    $fallbackUefiFile = Join-Path -Path $work -ChildPath 'efi\microsoft\boot\efisys_noprompt.bin'

    if ($DryRun) {
        $conflict = Resolve-WinBreakOutputConflict -OutputIso $output -WorkDirectory $work -DryRun
        if ($conflict.Cancelled) {
            return [pscustomobject]@{ Status = 'Cancelled'; OutputIso = $conflict.Path; Hash = $null; Size = 0 }
        }
        $output = $conflict.Path
        $outputParent = Split-Path -Path $output -Parent
        if (-not (Test-Path -LiteralPath $outputParent -PathType Container)) {
            Write-WinBreakLog -Message ('[DRYRUN] New-Item -ItemType Directory -Path "{0}" -Force' -f $outputParent) -Level INFO
        }
        $uefiBootFile = if ((Test-Path -LiteralPath $primaryUefiFile -PathType Leaf) -or -not (Test-Path -LiteralPath $fallbackUefiFile -PathType Leaf)) { $primaryUefiFile } else { $fallbackUefiFile }
        $tool = if ([string]::IsNullOrWhiteSpace($OscdimgPath)) { '<oscdimg.exe>' } else { $OscdimgPath }
        $arguments = New-WinBreakOscdimgArguments -WorkDirectory $work -OutputIso $output -BiosBootFile $biosBootFile -UefiBootFile $uefiBootFile
        Write-WinBreakLog -Message ('[DRYRUN] {0}' -f (Format-WinBreakCommandLine -FilePath $tool -ArgumentList $arguments)) -Level INFO
        return [pscustomobject]@{ Status = 'Planned'; OutputIso = $output; Hash = $null; Size = 0 }
    }

    if ([string]::IsNullOrWhiteSpace($OscdimgPath)) {
        $OscdimgPath = Find-WinBreakOscdimg
    }
    if ([string]::IsNullOrWhiteSpace($OscdimgPath)) {
        Write-WinBreakLog -Message 'oscdimg.exe non trovato. Installare Windows ADK selezionando Deployment Tools, quindi riprovare.' -Level WARN
        return [pscustomobject]@{ Status = 'MissingTool'; OutputIso = $output; Hash = $null; Size = 0 }
    }
    if (-not (Test-Path -LiteralPath $OscdimgPath -PathType Leaf)) {
        throw ('oscdimg.exe non è accessibile: {0}' -f $OscdimgPath)
    }
    if (-not (Test-Path -LiteralPath $biosBootFile -PathType Leaf)) {
        throw ('File di boot BIOS mancante: {0}' -f $biosBootFile)
    }

    $uefiBootFile = $primaryUefiFile
    if (-not (Test-Path -LiteralPath $uefiBootFile -PathType Leaf)) {
        if (Test-Path -LiteralPath $fallbackUefiFile -PathType Leaf) {
            $uefiBootFile = $fallbackUefiFile
            Write-WinBreakLog -Message ('efisys.bin non trovato; verrà usato {0}.' -f $fallbackUefiFile) -Level WARN
        }
        else {
            throw 'Né efisys.bin né efisys_noprompt.bin sono presenti nella work directory.'
        }
    }

    $conflict = Resolve-WinBreakOutputConflict -OutputIso $output -WorkDirectory $work
    if ($conflict.Cancelled) {
        return [pscustomobject]@{ Status = 'Cancelled'; OutputIso = $conflict.Path; Hash = $null; Size = 0 }
    }
    $output = $conflict.Path

    $outputParent = Split-Path -Path $output -Parent
    if (-not (Test-Path -LiteralPath $outputParent -PathType Container)) {
        New-Item -ItemType Directory -Path $outputParent -Force | Out-Null
        Write-WinBreakLog -Message ('Directory output creata: {0}' -f $outputParent) -Level SUCCESS
    }

    $arguments = New-WinBreakOscdimgArguments -WorkDirectory $work -OutputIso $output -BiosBootFile $biosBootFile -UefiBootFile $uefiBootFile
    Write-WinBreakLog -Message (Format-WinBreakCommandLine -FilePath $OscdimgPath -ArgumentList $arguments) -Level INFO
    $result = Invoke-WinBreakNativeCommand -FilePath $OscdimgPath -ArgumentList $arguments
    foreach ($line in $result.Output) {
        Write-WinBreakLog -Message ([string]$line) -Level DEBUG -NoConsole
    }
    if ($result.ExitCode -ne 0) {
        throw ('oscdimg ha restituito exit code {0}.' -f $result.ExitCode)
    }
    if (-not (Test-Path -LiteralPath $output -PathType Leaf)) {
        throw 'oscdimg ha terminato senza creare il file ISO atteso.'
    }
    $file = Get-Item -LiteralPath $output -Force -ErrorAction Stop
    if ($file.Length -le 0) {
        throw 'La ISO creata è vuota.'
    }
    $hash = (Get-FileHash -LiteralPath $output -Algorithm SHA256 -ErrorAction Stop).Hash
    Write-WinBreakLog -Message ('ISO creata: {0}' -f $output) -Level SUCCESS
    Write-WinBreakLog -Message ('Dimensione: {0}' -f (Format-WinBreakSize -Bytes $file.Length)) -Level SUCCESS
    Write-WinBreakLog -Message ('SHA256: {0}' -f $hash) -Level SUCCESS

    try {
        Start-Process -FilePath 'explorer.exe' -ArgumentList ('/select,"{0}"' -f $output) -ErrorAction Stop | Out-Null
    }
    catch {
        Write-WinBreakLog -Message ('ISO valida, ma Explorer non può evidenziarla: {0}' -f $_.Exception.Message) -Level WARN
    }
    return [pscustomobject]@{ Status = 'Success'; OutputIso = $output; Hash = $hash; Size = $file.Length }
}

function Invoke-WinBreakCountdown {
    [CmdletBinding()]
    param(
        [ValidateRange(1, 60)]
        [int]$Seconds = 10,

        [ConsoleKey]$CancelKey = [ConsoleKey]::A
    )

    Write-Host ('Premere {0} per annullare il conto alla rovescia.' -f $CancelKey) -ForegroundColor Yellow
    for ($remaining = $Seconds; $remaining -ge 1; $remaining--) {
        Write-Host ("`rAvvio tra {0} secondi... " -f $remaining) -NoNewline -ForegroundColor Cyan
        for ($poll = 0; $poll -lt 10; $poll++) {
            try {
                if ([Console]::KeyAvailable) {
                    $key = [Console]::ReadKey($true)
                    if ($key.Key -eq $CancelKey) {
                        Write-Host ''
                        Write-WinBreakLog -Message 'Avvio annullato durante il conto alla rovescia.' -Level WARN
                        return $false
                    }
                }
            }
            catch {
                # Il countdown continua negli host che non espongono KeyAvailable.
            }
            Start-Sleep -Milliseconds 100
        }
    }
    try {
        if ([Console]::KeyAvailable) {
            $finalKey = [Console]::ReadKey($true)
            if ($finalKey.Key -eq $CancelKey) {
                Write-Host ''
                Write-WinBreakLog -Message 'Avvio annullato durante il conto alla rovescia.' -Level WARN
                return $false
            }
        }
    }
    catch {
        # Nessun controllo finale disponibile in questo host.
    }
    Write-Host ''
    return $true
}

function Start-WinBreakUpgrade {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [string]$WorkDirectory,

        [switch]$DryRun
    )

    $work = Resolve-WinBreakDirectoryPath -Path $WorkDirectory
    $setupPath = Join-Path -Path $work -ChildPath 'setup.exe'
    if (-not $DryRun -and -not (Test-Path -LiteralPath $setupPath -PathType Leaf)) {
        throw ('setup.exe non trovato: {0}' -f $setupPath)
    }

    Write-Host 'VERRÀ APERTO IL NORMALE INSTALLER GRAFICO DI WINDOWS 11.' -ForegroundColor Cyan
    Write-Host ('WINBREAK NON ELIMINERÀ {0} DURANTE LʼAGGIORNAMENTO.' -f $work) -ForegroundColor Yellow
    Write-WinBreakLog -Message 'Il setup verrà avviato senza argomenti.' -Level INFO

    if ($DryRun) {
        Write-WinBreakLog -Message ('[DRYRUN] Start-Process -FilePath "{0}" -WorkingDirectory "{1}"' -f $setupPath, $work) -Level INFO
        return $true
    }
    if (-not (Invoke-WinBreakCountdown -Seconds 10 -CancelKey A)) {
        return $false
    }

    Start-Process -FilePath $setupPath -WorkingDirectory $work | Out-Null
    Write-WinBreakLog -Message 'Installer grafico avviato. WinBreak non attenderà la fine dellʼaggiornamento.' -Level SUCCESS
    Write-WinBreakLog -Message ('Dopo lʼaggiornamento eliminare manualmente, quando sicuro: {0}' -f $work) -Level WARN
    return $true
}

function Show-WinBreakFinalMenu {
    [CmdletBinding()]
    param()

    while ($true) {
        Write-Host ''
        Write-Host 'OPERAZIONE FINALE' -ForegroundColor Cyan
        Write-Host '[1] Avvia aggiornamento Windows 11' -ForegroundColor Gray
        Write-Host '[2] Crea ISO modificata' -ForegroundColor Gray
        Write-Host '[3] Esci senza avviare nulla' -ForegroundColor Gray
        $choice = (Read-Host 'Scelta').Trim()

        if ($choice -eq '1') {
            if (Read-WinBreakConfirmation -Prompt 'Confermare lʼavvio del normale setup.exe? [S/N]') { return 1 }
        }
        elseif ($choice -eq '2') {
            if (Read-WinBreakConfirmation -Prompt 'Confermare la creazione della nuova ISO? [S/N]') { return 2 }
        }
        elseif ($choice -eq '3') {
            return 3
        }
        else {
            Write-Host 'Scelta non valida.' -ForegroundColor Yellow
        }
    }
}

function Invoke-WinBreakCore {
    [CmdletBinding()]
    param(
        [switch]$DryRun,
        [switch]$KeepMounted,
        [string]$WorkDirectory = 'C:\Win11ISO',
        [string]$OutputIso = 'C:\Windows11Modded.iso'
    )

    Write-WinBreakBanner
    if (-not (Test-WinBreakAdministrator)) {
        Write-Host 'RUNNAMI COME ADMINISTRATOR!' -ForegroundColor Red
        Write-Host 'PREMERE UN TASTO PER USCIRE...' -ForegroundColor Gray
        try { [void][Console]::ReadKey($true) } catch { [void](Read-Host) }
        return 1
    }

    $mountInfo = $null
    $pauseAlreadyShown = $false
    try {
        $logPath = Initialize-WinBreakLogging
        Write-WinBreakLog -Message ('{0} {1} avviato. Log: {2}' -f $script:WinBreakName, $script:WinBreakVersion, $logPath) -Level INFO
        Write-WinBreakLog -Message ('Parametri: DryRun={0}; KeepMounted={1}; WorkDirectory={2}; OutputIso={3}' -f $DryRun, $KeepMounted, $WorkDirectory, $OutputIso) -Level DEBUG
        if ($DryRun) {
            Write-WinBreakLog -Message 'MODALITÀ DRYRUN: nessuna operazione distruttiva o processo operativo verrà eseguito.' -Level WARN
        }

        $searchDirectories = @('C:\', (Join-Path -Path $env:USERPROFILE -ChildPath 'Downloads'))
        $candidates = @(Get-WinBreakIsoCandidates -SearchDirectories $searchDirectories)
        $selection = Show-WinBreakIsoMenu -Candidates $candidates
        if ($selection.Cancelled) {
            Write-WinBreakLog -Message 'Operazione annullata dallʼutente.' -Level INFO
            return 0
        }

        $isoPath = Resolve-WinBreakIsoPath -Path $selection.Path
        $isoFile = Get-Item -LiteralPath $isoPath -Force
        Write-WinBreakLog -Message ('ISO selezionata: {0}; dimensione={1}; modificata={2}' -f $isoPath, (Format-WinBreakSize -Bytes $isoFile.Length), $isoFile.LastWriteTime.ToString('yyyy-MM-dd HH:mm:ss')) -Level INFO

        $mountInfo = Mount-WinBreakIso -IsoPath $isoPath -KeepMounted:$KeepMounted -DryRun:$DryRun
        if ($DryRun) {
            Write-WinBreakLog -Message '[DRYRUN] Struttura e metadati non sono dichiarati verificati perché la ISO non viene montata.' -Level WARN
        }
        else {
            $media = Test-WinBreakWindows11Media -RootPath $mountInfo.Root
            if (-not $media.IsValid) {
                foreach ($validationError in $media.Errors) {
                    Write-WinBreakLog -Message $validationError -Level ERROR
                }
                Write-Host ('Log: {0}' -f $script:WinBreakLogPath) -ForegroundColor Gray
                Write-Host 'NON È UNA ISO DI WINDOWS 11 REALE E INTEGRA.' -ForegroundColor Red
                Write-WinBreakLog -Message 'NON È UNA ISO DI WINDOWS 11 REALE E INTEGRA.' -Level ERROR -NoConsole
                $pauseAlreadyShown = $true
                Pause-WinBreak -Message 'PREMERE UN TASTO PER USCIRE...'
                return 2
            }
            Write-WinBreakLog -Message 'Struttura e metadati Windows 11 verificati (controllo strutturale, non crittografico).' -Level SUCCESS
            Write-WinBreakEditions -Editions $media.Editions
        }

        [void](Set-WinBreakRegistryBypasses -DryRun:$DryRun)
        $resolvedWorkDirectory = Initialize-WinBreakWorkDirectory -Path $WorkDirectory -OutputIso $OutputIso -DryRun:$DryRun
        if ($null -eq $resolvedWorkDirectory) {
            Write-WinBreakLog -Message 'Preparazione work directory annullata.' -Level INFO
            return 0
        }

        $sourceRoot = if ($DryRun) {
            'X:\'
        }
        else {
            $mountInfo.Root
        }
        [void](Copy-WinBreakMedia -SourceRoot $sourceRoot -WorkDirectory $resolvedWorkDirectory -DryRun:$DryRun)

        if ($mountInfo.MountedByWinBreak -and -not $KeepMounted) {
            Dismount-WinBreakIso -MountInfo $mountInfo -DryRun:$DryRun
        }

        $patchResult = Remove-WinBreakAppraiser -WorkDirectory $resolvedWorkDirectory -DryRun:$DryRun
        if (-not $patchResult.Continued) {
            Write-WinBreakLog -Message 'Operazione annullata: appraiserres.dll era già assente.' -Level WARN
            return 0
        }

        while ($true) {
            $finalChoice = Show-WinBreakFinalMenu
            if ($finalChoice -eq 1) {
                [void](Start-WinBreakUpgrade -WorkDirectory $resolvedWorkDirectory -DryRun:$DryRun)
                return 0
            }
            if ($finalChoice -eq 2) {
                $buildResult = Build-WinBreakIso -WorkDirectory $resolvedWorkDirectory -OutputIso $OutputIso -DryRun:$DryRun
                if ($buildResult.Status -eq 'MissingTool' -or $buildResult.Status -eq 'Cancelled') {
                    continue
                }
                if ($buildResult.Status -eq 'Success') {
                    if (Read-WinBreakConfirmation -Prompt ('Rimuovere ora {0}? [S/N]' -f $resolvedWorkDirectory)) {
                        [void](Remove-WinBreakWorkDirectorySafely -Path $resolvedWorkDirectory -ExpectedWorkDirectory $resolvedWorkDirectory -OutputIso $buildResult.OutputIso)
                    }
                }
                return 0
            }
            Write-WinBreakLog -Message ('Work directory conservata: {0}' -f $resolvedWorkDirectory) -Level INFO
            return 0
        }
    }
    catch {
        $summary = $_.Exception.Message
        Write-Host ('ERRORE: {0}' -f $summary) -ForegroundColor Red
        Write-WinBreakLog -Message ('Errore fatale: {0}' -f $_.Exception.ToString()) -Level ERROR -NoConsole
        if ($null -ne $_.InvocationInfo -and -not [string]::IsNullOrWhiteSpace($_.InvocationInfo.PositionMessage)) {
            Write-WinBreakLog -Message $_.InvocationInfo.PositionMessage -Level DEBUG -NoConsole
        }
        if (-not [string]::IsNullOrWhiteSpace($script:WinBreakLogPath)) {
            Write-Host ('Log: {0}' -f $script:WinBreakLogPath) -ForegroundColor Gray
        }
        if (Test-WinBreakInteractiveHost) {
            $pauseAlreadyShown = $true
            Pause-WinBreak -Message 'PREMERE UN TASTO PER USCIRE...'
        }
        return 1
    }
    finally {
        if ($null -ne $mountInfo) {
            try {
                Dismount-WinBreakIso -MountInfo $mountInfo -KeepMounted:$KeepMounted -DryRun:$DryRun
            }
            catch {
                $script:WinBreakCleanupFailed = $true
                Write-Host ('ERRORE DI CLEANUP: impossibile smontare la ISO: {0}' -f $_.Exception.Message) -ForegroundColor Red
                Write-WinBreakLog -Message ('Impossibile smontare la ISO durante il cleanup: {0}' -f $_.Exception.Message) -Level ERROR
                if (-not [string]::IsNullOrWhiteSpace($script:WinBreakLogPath)) {
                    Write-Host ('Log: {0}' -f $script:WinBreakLogPath) -ForegroundColor Gray
                }
                if (-not $pauseAlreadyShown -and (Test-WinBreakInteractiveHost)) {
                    Pause-WinBreak -Message 'PREMERE UN TASTO PER USCIRE...'
                }
            }
        }
    }
}

function Invoke-WinBreak {
    [CmdletBinding()]
    param(
        [switch]$DryRun,
        [switch]$KeepMounted,
        [string]$WorkDirectory = 'C:\Win11ISO',
        [string]$OutputIso = 'C:\Windows11Modded.iso'
    )

    $script:WinBreakCleanupFailed = $false
    $exitCode = Invoke-WinBreakCore -DryRun:$DryRun -KeepMounted:$KeepMounted -WorkDirectory $WorkDirectory -OutputIso $OutputIso
    if ($script:WinBreakCleanupFailed) {
        return 1
    }
    return [int]$exitCode
}

if ($MyInvocation.InvocationName -ne '.') {
    $exitCode = Invoke-WinBreak -DryRun:$DryRun -KeepMounted:$KeepMounted -WorkDirectory $WorkDirectory -OutputIso $OutputIso
    exit $exitCode
}
