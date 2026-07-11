Describe 'WinBreak - parsing sintattico' {
    BeforeAll {
        Set-StrictMode -Version Latest
        $ErrorActionPreference = 'Stop'
        $projectRoot = Split-Path -Parent $PSScriptRoot
        $script:WinBreakScriptPath = Join-Path -Path $projectRoot -ChildPath 'WinBreak.ps1'
    }

    It 'non contiene errori di parsing PowerShell' {
        $tokens = $null
        $parseErrors = $null
        $ast = [System.Management.Automation.Language.Parser]::ParseFile(
            $script:WinBreakScriptPath,
            [ref]$tokens,
            [ref]$parseErrors
        )

        ($null -eq $ast) | Should -Be $false
        @($parseErrors).Count | Should -Be 0
    }
}

Describe 'WinBreak - test unitari non distruttivi' {
    BeforeAll {
        Set-StrictMode -Version Latest
        $ErrorActionPreference = 'Stop'
        $projectRoot = Split-Path -Parent $PSScriptRoot
        $script:WinBreakScriptPath = Join-Path -Path $projectRoot -ChildPath 'WinBreak.ps1'
        # WinBreak.ps1 non esegue Invoke-WinBreak quando viene caricato con dot-source.
        . $script:WinBreakScriptPath
        $script:WinBreakLogPath = $null
    }

    BeforeEach {
        $script:WinBreakLogPath = $null
    }
    Context 'Directory runtime portabile' {
        It 'colloca log e backup accanto a WinBreak.ps1' {
            $expectedRoot = [IO.Path]::GetFullPath($projectRoot)

            $script:WinBreakRoot |
                Should -Be $expectedRoot

            $script:WinBreakLogRoot |
                Should -Be (Join-Path $expectedRoot 'logs')

            $script:WinBreakBackupRoot |
                Should -Be (Join-Path $expectedRoot 'backup')
        }

        It 'non contiene più percorsi runtime hardcoded in C:\WinBreak' {
            $script:WinBreakLogRoot |
                Should -Not -Be 'C:\WinBreak\logs'

            $script:WinBreakBackupRoot |
                Should -Not -Be 'C:\WinBreak\backup'
        }
    }
    Context 'Nomi ISO' {
        It 'accetta i nomi Windows 11 previsti senza distinguere maiuscole e minuscole' {
            $validNames = @(
                'Win11.iso',
                'Windows 11 24H2 Italian.iso',
                'windows_11_it.ISO',
                'WIN-11.24H2.iso',
                'windows.11-preview.Iso'
            )

            foreach ($name in $validNames) {
                Test-WinBreakIsoFileName -Name $name | Should -Be $true
            }
        }

        It 'rifiuta nomi non conformi e false estensioni ISO' {
            $invalidNames = @(
                'Win10.iso',
                'MyWin11.iso',
                'WindowsServer11.iso',
                'Win11.iso.bak',
                'Win11',
                'not-windows.iso',
                ''
            )

            foreach ($name in $invalidNames) {
                Test-WinBreakIsoFileName -Name $name | Should -Be $false
            }
            Test-WinBreakIsoFileName -Name $null | Should -Be $false
        }
    }

    Context 'Deduplicazione candidati ISO' {
        It 'deduplica FullName senza distinzione di case, conserva il primo oggetto e ordina deterministicamente' {
            $firstDuplicate = [pscustomobject]@{ FullName = 'C:\Zeta\Win11.iso'; Marker = 'first' }
            $candidates = @(
                $firstDuplicate,
                [pscustomobject]@{ FullName = 'C:\Alpha\Windows 11.iso'; Marker = 'alpha' },
                [pscustomobject]@{ FullName = 'c:\zeta\WIN11.ISO'; Marker = 'duplicate' },
                [pscustomobject]@{ FullName = 'C:\Middle\Win-11.iso'; Marker = 'middle' },
                $null,
                [pscustomobject]@{ Name = 'senza-fullname.iso' },
                [pscustomobject]@{ FullName = ''; Marker = 'empty' }
            )

            $actual = @(Select-WinBreakUniqueIsoCandidate -Candidates $candidates)

            $actual.Count | Should -Be 3
            ($actual.FullName -join '|') | Should -Be 'C:\Alpha\Windows 11.iso|C:\Middle\Win-11.iso|C:\Zeta\Win11.iso'
            $actual[2].Marker | Should -Be 'first'

            $secondRun = @(Select-WinBreakUniqueIsoCandidate -Candidates $candidates)
            ($secondRun.FullName -join '|') | Should -Be ($actual.FullName -join '|')
        }
    }

    Context 'Parsing del menu ISO' {
        It 'converte una scelta numerica valida in un indice zero-based' {
            $first = ConvertTo-WinBreakMenuChoice -InputValue '1' -CandidateCount 2
            $second = ConvertTo-WinBreakMenuChoice -InputValue ' 2 ' -CandidateCount 2

            $first.Kind | Should -Be 'Index'
            $first.Index | Should -Be 0
            $second.Kind | Should -Be 'Index'
            $second.Index | Should -Be 1
        }

        It 'riconosce P e Q senza distinguere maiuscole e minuscole' {
            foreach ($value in @('p', 'P')) {
                (ConvertTo-WinBreakMenuChoice -InputValue $value -CandidateCount 2).Kind | Should -Be 'Path'
            }
            foreach ($value in @('q', 'Q')) {
                (ConvertTo-WinBreakMenuChoice -InputValue $value -CandidateCount 2).Kind | Should -Be 'Quit'
            }
        }

        It 'rifiuta scelte vuote, fuori intervallo o non intere' {
            foreach ($value in @('', ' ', '0', '3', '-1', '1.0', 'abc')) {
                (ConvertTo-WinBreakMenuChoice -InputValue $value -CandidateCount 2).Kind | Should -Be 'Invalid'
            }
            (ConvertTo-WinBreakMenuChoice -InputValue $null -CandidateCount 2).Kind | Should -Be 'Invalid'
        }
    }

    Context 'Normalizzazione dei percorsi' {
        It 'rimuove spazi e virgolette preservando un percorso assoluto con spazi' {
            $absolutePath = Join-Path -Path $TestDrive -ChildPath 'ISO Files\Windows 11.iso'
            $inputValue = '  "{0}"  ' -f $absolutePath

            $actual = ConvertFrom-WinBreakPathInput -InputPath $inputValue -UserProfile $TestDrive -BasePath $TestDrive

            $actual | Should -Be ([IO.Path]::GetFullPath($absolutePath))
        }

        It 'espande tilde rispetto al profilo utente iniettato' {
            $profile_ = Join-Path -Path $TestDrive -ChildPath 'Test User'
            $expected = [IO.Path]::GetFullPath((Join-Path -Path $profile_ -ChildPath 'Downloads\Win11.iso'))

            ConvertFrom-WinBreakPathInput -InputPath '~\Downloads\Win11.iso' -UserProfile $profile_ -BasePath $TestDrive |
            Should -Be $expected
        }

        It 'espande variabili ambiente sia in formato percentuale sia PowerShell' {
            $variableName = 'WINBREAK_PESTER_PROFILE'
            $previousValue = [Environment]::GetEnvironmentVariable($variableName)
            $profile_ = Join-Path -Path $TestDrive -ChildPath 'Environment Profile'
            try {
                [Environment]::SetEnvironmentVariable($variableName, $profile_)
                $expected = [IO.Path]::GetFullPath((Join-Path -Path $profile_ -ChildPath 'Downloads\Win11.iso'))

                ConvertFrom-WinBreakPathInput -InputPath '%WINBREAK_PESTER_PROFILE%\Downloads\Win11.iso' -UserProfile $TestDrive -BasePath $TestDrive |
                Should -Be $expected
                ConvertFrom-WinBreakPathInput -InputPath '$env:WINBREAK_PESTER_PROFILE\Downloads\Win11.iso' -UserProfile $TestDrive -BasePath $TestDrive |
                Should -Be $expected
            }
            finally {
                [Environment]::SetEnvironmentVariable($variableName, $previousValue)
            }
        }

        It 'risolve un percorso relativo rispetto alla base iniettata' {
            $expected = [IO.Path]::GetFullPath((Join-Path -Path $TestDrive -ChildPath 'relative\Win11.iso'))

            ConvertFrom-WinBreakPathInput -InputPath 'relative\Win11.iso' -UserProfile $TestDrive -BasePath $TestDrive |
            Should -Be $expected
        }

        It 'impedisce a Resolve-WinBreakIsoPath di accettare un percorso relativo' {
            { Resolve-WinBreakIsoPath -Path 'relative\Win11.iso' } | Should -Throw
        }

        It 'distingue i percorsi pienamente qualificati da quelli relativi a unità o radice corrente' {
            Test-WinBreakFullyQualifiedPath -Path ([IO.Path]::GetFullPath($TestDrive)) | Should -Be $true
            Test-WinBreakFullyQualifiedPath -Path 'relative\Win11.iso' | Should -Be $false
            Test-WinBreakFullyQualifiedPath -Path 'C:relative.iso' | Should -Be $false
            Test-WinBreakFullyQualifiedPath -Path '\root-relative.iso' | Should -Be $false

            if ([IO.Path]::DirectorySeparatorChar -eq '\') {
                Test-WinBreakFullyQualifiedPath -Path 'C:\Win11.iso' | Should -Be $true
                Test-WinBreakFullyQualifiedPath -Path '\\server\share\Win11.iso' | Should -Be $true
            }
        }

        It 'restituisce una stringa vuota per input vuoto' {
            ConvertFrom-WinBreakPathInput -InputPath '   ' -UserProfile $TestDrive -BasePath $TestDrive | Should -Be ''
        }
    }
    Context 'Argomenti robocopy' {
        It 'gestisce una radice volume non montata senza risolverla come PSDrive' {
            $driveName = @(
                'Q',
                'R',
                'S',
                'T',
                'U',
                'V',
                'W',
                'X',
                'Y',
                'Z'
            ) |
            Where-Object {
                $null -eq (
                    Get-PSDrive `
                        -Name $_ `
                        -PSProvider FileSystem `
                        -ErrorAction SilentlyContinue
                )
            } |
            Select-Object -First 1

            if ([string]::IsNullOrWhiteSpace($driveName)) {
                throw 'Nessuna lettera di unità libera disponibile per il test.'
            }

            $sourceRoot = '{0}:\' -f $driveName
            $destination = Join-Path $TestDrive 'robocopy-destination'

            $actual = @(
                New-WinBreakRobocopyArguments `
                    -SourcePath $sourceRoot `
                    -DestinationPath $destination
            )

            $actual.Count | Should -Be 6
            $actual[0] | Should -Be ($sourceRoot + '.')
            $actual[1] | Should -Be (
                Get-WinBreakCanonicalPath -Path $destination
            )
            $actual[2] | Should -Be '/MIR'
            $actual[3] | Should -Be '/R:2'
            $actual[4] | Should -Be '/W:2'
            $actual[5] | Should -Be '/XJ'

            foreach ($argument in $actual) {
                ([string]$argument).Contains('"') | Should -Be $false
            }
        }
    }
    Context 'Exit code robocopy' {
        It 'considera non bloccanti tutti e soli i codici da 0 a 7' {
            foreach ($exitCode in (0..7)) {
                Test-WinBreakRobocopyExitCode -ExitCode $exitCode | Should -Be $true
            }
            foreach ($exitCode in @(-1, 8, 16, 255)) {
                Test-WinBreakRobocopyExitCode -ExitCode $exitCode | Should -Be $false
            }
        }
    }

    Context 'Controlli di sicurezza del cleanup' {
        It 'accetta una work directory ordinaria quando output e directory protette sono esterni' {
            $work = Join-Path $TestDrive 'cleanup-safe-work'
            New-Item -ItemType Directory -Path $work -Force | Out-Null
            $parameters = @{
                Path                  = $work
                ExpectedWorkDirectory = $work
                OutputIso             = (Join-Path $TestDrive 'cleanup-output\result.iso')
                UserProfile           = (Join-Path $TestDrive 'protected-profile')
                SystemRoot            = (Join-Path $TestDrive 'protected-system')
                ProgramFiles          = (Join-Path $TestDrive 'protected-program-files')
                ProgramFilesX86       = (Join-Path $TestDrive 'protected-program-files-x86')
                ProgramData           = (Join-Path $TestDrive 'protected-program-data')
                BackupRoot            = (Join-Path $TestDrive 'protected-winbreak')
            }

            (Test-WinBreakCleanupPath @parameters).IsSafe | Should -Be $true
        }

        It 'rifiuta valori vuoti, un percorso diverso da quello atteso e la radice del volume' {
            $protected = @{
                OutputIso       = (Join-Path $TestDrive 'outside\result.iso')
                UserProfile     = (Join-Path $TestDrive 'profile-mismatch')
                SystemRoot      = (Join-Path $TestDrive 'system-mismatch')
                ProgramFiles    = (Join-Path $TestDrive 'program-files-mismatch')
                ProgramFilesX86 = (Join-Path $TestDrive 'program-files-x86-mismatch')
                ProgramData     = (Join-Path $TestDrive 'program-data-mismatch')
                BackupRoot      = (Join-Path $TestDrive 'backup-mismatch')
            }
            $work = Join-Path $TestDrive 'expected-work'
            $other = Join-Path $TestDrive 'other-work'
            $root = [IO.Path]::GetPathRoot([IO.Path]::GetFullPath($TestDrive))

            (Test-WinBreakCleanupPath -Path '' -ExpectedWorkDirectory $work @protected).IsSafe | Should -Be $false
            (Test-WinBreakCleanupPath -Path $other -ExpectedWorkDirectory $work @protected).IsSafe | Should -Be $false
            (Test-WinBreakCleanupPath -Path $root -ExpectedWorkDirectory $root @protected).IsSafe | Should -Be $false
        }

        It 'rifiuta il profilo utente e le directory di sistema protette' {
            $profile_ = Join-Path $TestDrive 'protected-user-profile'
            $systemRoot = Join-Path $TestDrive 'protected-windows'
            $programFiles = Join-Path $TestDrive 'protected-pf'
            $programFilesX86 = Join-Path $TestDrive 'protected-pfx86'
            $programData = Join-Path $TestDrive 'protected-pd'
            $backupRoot = Join-Path $TestDrive 'protected-backup'
            $protectedCandidates = @($profile_, $systemRoot, $programFiles, $programFilesX86, $programData, $backupRoot)

            foreach ($candidate in $protectedCandidates) {
                $result = Test-WinBreakCleanupPath `
                    -Path $candidate `
                    -ExpectedWorkDirectory $candidate `
                    -OutputIso (Join-Path $TestDrive 'outside-protected\result.iso') `
                    -UserProfile $profile_ `
                    -SystemRoot $systemRoot `
                    -ProgramFiles $programFiles `
                    -ProgramFilesX86 $programFilesX86 `
                    -ProgramData $programData `
                    -BackupRoot $backupRoot

                $result.IsSafe | Should -Be $false
            }
        }

        It 'rifiuta una work directory che contiene la ISO di output' {
            $work = Join-Path $TestDrive 'cleanup-containing-output'
            New-Item -ItemType Directory -Path $work -Force | Out-Null

            $result = Test-WinBreakCleanupPath `
                -Path $work `
                -ExpectedWorkDirectory $work `
                -OutputIso (Join-Path $work 'Windows11Modded.iso') `
                -UserProfile (Join-Path $TestDrive 'profile-output') `
                -SystemRoot (Join-Path $TestDrive 'system-output') `
                -ProgramFiles (Join-Path $TestDrive 'pf-output') `
                -ProgramFilesX86 (Join-Path $TestDrive 'pfx86-output') `
                -ProgramData (Join-Path $TestDrive 'pd-output') `
                -BackupRoot (Join-Path $TestDrive 'backup-output')

            $result.IsSafe | Should -Be $false
        }
    }

    Context 'Argomenti oscdimg' {
        It 'costruisce sette argomenti distinti senza virgolette incorporate anche con percorsi contenenti spazi' {
            $work = Join-Path $TestDrive 'work with spaces'
            $output = Join-Path $TestDrive 'output with spaces\Windows 11.iso'
            $bios = Join-Path $work 'boot\etfsboot.com'
            $uefi = Join-Path $work 'efi\microsoft\boot\efisys_noprompt.bin'

            $actual = @(New-WinBreakOscdimgArguments `
                    -WorkDirectory $work `
                    -OutputIso $output `
                    -BiosBootFile $bios `
                    -UefiBootFile $uefi)

            $actual.Count | Should -Be 7
            $actual[0] | Should -Be '-m'
            $actual[1] | Should -Be '-o'
            $actual[2] | Should -Be '-u2'
            $actual[3] | Should -Be '-udfver102'
            $actual[4] | Should -Be ('-bootdata:2#p0,e,b{0}#pEF,e,b{1}' -f $bios, $uefi)
            $actual[5] | Should -Be (Get-WinBreakCanonicalPath -Path $work)
            $actual[6] | Should -Be (Get-WinBreakCanonicalPath -Path $output)
            foreach ($argument in $actual) {
                ([string]$argument).Contains('"') | Should -Be $false
            }
        }
    }

    Context 'Rilevamento build Windows 11' {
        It 'applica esattamente la soglia build 22000' {
            Test-WinBreakWindows11Build -Version '10.0.21999.999' | Should -Be $false
            Test-WinBreakWindows11Build -Version '10.0.22000.1' | Should -Be $true
            Test-WinBreakWindows11Build -Version ([version]'10.0.22631.1') | Should -Be $true
            Test-WinBreakWindows11Build -Version '10.0.26100.1' | Should -Be $true
        }

        It 'rifiuta versioni mancanti o illeggibili' {
            Test-WinBreakWindows11Build -Version $null | Should -Be $false
            Test-WinBreakWindows11Build -Version '' | Should -Be $false
            Test-WinBreakWindows11Build -Version 'non-versione' | Should -Be $false
        }
    }

    Context 'DryRun delle funzioni operative' {
        BeforeEach {
            Mock -CommandName Write-WinBreakLog -MockWith { }
        }

        It 'non monta né interroga immagini disco e non inventa una lettera in DryRun' {
            Mock -CommandName Get-DiskImage -MockWith {
                throw 'Get-DiskImage non deve essere chiamato in DryRun.'
            }

            Mock -CommandName Mount-DiskImage -MockWith {
                throw 'Mount-DiskImage non deve essere chiamato in DryRun.'
            }

            Mock -CommandName Get-Volume -MockWith {
                throw 'Get-Volume non deve essere chiamato in DryRun.'
            }

            $result = Mount-WinBreakIso `
                -IsoPath 'C:\Fake\Win11.iso' `
                -DryRun

            $result.DryRun | Should -Be $true
            ($null -eq $result.Root) | Should -Be $true
            ($null -eq $result.DriveLetter) | Should -Be $true
            ($null -eq $result.DiskImage) | Should -Be $true

            Assert-MockCalled `
                -CommandName Get-DiskImage `
                -Times 0 `
                -Exactly `
                -Scope It

            Assert-MockCalled `
                -CommandName Mount-DiskImage `
                -Times 0 `
                -Exactly `
                -Scope It

            Assert-MockCalled `
                -CommandName Get-Volume `
                -Times 0 `
                -Exactly `
                -Scope It
        }

        It 'non smonta né interroga una immagine disco' {
            Mock -CommandName Get-DiskImage -MockWith { throw 'Get-DiskImage non deve essere chiamato in DryRun.' }
            Mock -CommandName Dismount-DiskImage -MockWith { throw 'Dismount-DiskImage non deve essere chiamato in DryRun.' }
            $mountInfo = [pscustomobject]@{
                ImagePath         = 'C:\Fake\Win11.iso'
                MountedByWinBreak = $true
                Dismounted        = $false
                DryRun            = $false
            }

            Dismount-WinBreakIso -MountInfo $mountInfo -DryRun

            Assert-MockCalled -CommandName Get-DiskImage -Times 0 -Exactly -Scope It
            Assert-MockCalled -CommandName Dismount-DiskImage -Times 0 -Exactly -Scope It
        }

        It 'non esegue reg.exe e non crea il backup Registry' {
            Mock -CommandName Invoke-WinBreakNativeCommand -MockWith { throw 'reg.exe non deve essere eseguito in DryRun.' }
            Mock -CommandName Backup-WinBreakRegistryState -MockWith { throw 'Il backup Registry non deve essere creato in DryRun.' }
            $backupRoot = Join-Path $TestDrive 'registry-dryrun-backup'

            $result = Set-WinBreakRegistryBypasses -DryRun -BackupRoot $backupRoot

            $result.Planned | Should -Be $true
            Test-Path -LiteralPath $backupRoot | Should -Be $false
            Assert-MockCalled -CommandName Invoke-WinBreakNativeCommand -Times 0 -Exactly -Scope It
            Assert-MockCalled -CommandName Backup-WinBreakRegistryState -Times 0 -Exactly -Scope It
        }

        It 'non crea la work directory mancante' {
            $work = Join-Path $TestDrive 'missing-work-directory'
            Mock -CommandName New-Item -MockWith { throw 'New-Item non deve essere chiamato in DryRun.' }

            $result = Initialize-WinBreakWorkDirectory -Path $work -OutputIso (Join-Path $TestDrive 'outside-work.iso') -DryRun

            $result | Should -Be (Get-WinBreakCanonicalPath -Path $work)
            Test-Path -LiteralPath $work | Should -Be $false
            Assert-MockCalled -CommandName New-Item -Times 0 -Exactly -Scope It
        }
        It 'non richiede una SourceRoot reale e non costruisce gli argomenti operativi in DryRun' {
            Mock -CommandName New-WinBreakRobocopyArguments -MockWith {
                throw 'Gli argomenti operativi non devono essere costruiti in DryRun.'
            }

            Mock -CommandName Invoke-WinBreakNativeCommand -MockWith {
                throw 'Robocopy non deve essere eseguito in DryRun.'
            }

            $destination = Join-Path $TestDrive 'dryrun-destination'

            $result = Copy-WinBreakMedia `
                -SourceRoot $null `
                -WorkDirectory $destination `
                -DryRun

            $result.Success | Should -Be $true
            $result.Planned | Should -Be $true
            ($null -eq $result.ExitCode) | Should -Be $true

            Test-Path `
                -LiteralPath $destination `
                -PathType Container |
            Should -Be $false

            Assert-MockCalled `
                -CommandName New-WinBreakRobocopyArguments `
                -Times 0 `
                -Exactly `
                -Scope It

            Assert-MockCalled `
                -CommandName Invoke-WinBreakNativeCommand `
                -Times 0 `
                -Exactly `
                -Scope It

            Assert-MockCalled `
                -CommandName Write-WinBreakLog `
                -Times 1 `
                -Exactly `
                -Scope It `
                -ParameterFilter {
                $Level -eq 'INFO' -and
                -not [string]::IsNullOrWhiteSpace($Message) -and
                $Message.Contains('robocopy.exe') -and
                $Message.Contains('<RADICE-ISO-MONTATA>')
            }
        }

        It 'rifiuta una SourceRoot nulla fuori dal DryRun' {
            Mock -CommandName New-WinBreakRobocopyArguments -MockWith {
                throw 'Gli argomenti non devono essere costruiti senza SourceRoot.'
            }

            Mock -CommandName Invoke-WinBreakNativeCommand -MockWith {
                throw 'Robocopy non deve essere eseguito senza SourceRoot.'
            }

            $destination = Join-Path $TestDrive 'real-run-destination'

            {
                Copy-WinBreakMedia `
                    -SourceRoot $null `
                    -WorkDirectory $destination
            } | Should -Throw

            Test-Path `
                -LiteralPath $destination `
                -PathType Container |
            Should -Be $false

            Assert-MockCalled `
                -CommandName New-WinBreakRobocopyArguments `
                -Times 0 `
                -Exactly `
                -Scope It

            Assert-MockCalled `
                -CommandName Invoke-WinBreakNativeCommand `
                -Times 0 `
                -Exactly `
                -Scope It
        }
        It 'non esegue oscdimg, non cerca il tool e non apre Explorer' {
            Mock -CommandName Invoke-WinBreakNativeCommand -MockWith { throw 'oscdimg non deve essere eseguito in DryRun.' }
            Mock -CommandName Find-WinBreakOscdimg -MockWith { throw 'oscdimg non deve essere cercato in DryRun.' }
            Mock -CommandName Start-Process -MockWith { throw 'Explorer non deve essere aperto in DryRun.' }
            $work = Join-Path $TestDrive 'build-dryrun-work'
            $output = Join-Path $TestDrive 'build-dryrun-output\Windows11.iso'

            $result = Build-WinBreakIso -WorkDirectory $work -OutputIso $output -DryRun

            $result.Status | Should -Be 'Planned'
            Test-Path -LiteralPath $output | Should -Be $false
            Assert-MockCalled -CommandName Invoke-WinBreakNativeCommand -Times 0 -Exactly -Scope It
            Assert-MockCalled -CommandName Find-WinBreakOscdimg -Times 0 -Exactly -Scope It
            Assert-MockCalled -CommandName Start-Process -Times 0 -Exactly -Scope It
        }

        It 'non avvia setup.exe e non esegue il countdown' {
            Mock -CommandName Start-Process -MockWith { throw 'setup.exe non deve essere avviato in DryRun.' }
            Mock -CommandName Invoke-WinBreakCountdown -MockWith { throw 'Il countdown non deve partire in DryRun.' }
            $work = Join-Path $TestDrive 'upgrade-dryrun-work'

            Start-WinBreakUpgrade -WorkDirectory $work -DryRun | Should -Be $true

            Assert-MockCalled -CommandName Start-Process -Times 0 -Exactly -Scope It
            Assert-MockCalled -CommandName Invoke-WinBreakCountdown -Times 0 -Exactly -Scope It
        }

        It 'non elimina la work directory' {
            $work = Join-Path $TestDrive 'cleanup-dryrun-work'
            New-Item -ItemType Directory -Path $work -Force | Out-Null
            Set-Content -LiteralPath (Join-Path $work 'sentinel.txt') -Value 'keep' -Encoding Ascii
            Mock -CommandName Remove-Item -MockWith { throw 'Remove-Item non deve essere chiamato in DryRun.' }

            Remove-WinBreakWorkDirectorySafely `
                -Path $work `
                -ExpectedWorkDirectory $work `
                -OutputIso (Join-Path $TestDrive 'cleanup-dryrun-output\result.iso') `
                -DryRun | Should -Be $true

            Test-Path -LiteralPath (Join-Path $work 'sentinel.txt') -PathType Leaf | Should -Be $true
            Assert-MockCalled -CommandName Remove-Item -Times 0 -Exactly -Scope It
        }
    }

    Context 'Gestione appraiserres.dll in TestDrive' {
        BeforeEach {
            Mock -CommandName Write-WinBreakLog -MockWith { }
        }

        It 'crea un backup verificato e rimuove solo appraiserres.dll quando presente' {
            $work = Join-Path $TestDrive 'appraiser-present-work'
            $sources = Join-Path $work 'sources'
            $backupRoot = Join-Path $TestDrive 'appraiser-present-backup'
            New-Item -ItemType Directory -Path $sources -Force | Out-Null
            $target = Join-Path $sources 'appraiserres.dll'
            $decoy = Join-Path $sources 'appraiser.dll'
            Set-Content -LiteralPath $target -Value 'appraiserres test payload' -Encoding Ascii
            Set-Content -LiteralPath $decoy -Value 'must remain' -Encoding Ascii
            $expectedHash = (Get-FileHash -LiteralPath $target -Algorithm SHA256).Hash

            $result = Remove-WinBreakAppraiser -WorkDirectory $work -BackupRoot $backupRoot

            $result.Continued | Should -Be $true
            $result.Removed | Should -Be $true
            $result.Planned | Should -Be $false
            Test-Path -LiteralPath $target | Should -Be $false
            Test-Path -LiteralPath $decoy -PathType Leaf | Should -Be $true
            Test-Path -LiteralPath $result.BackupPath -PathType Leaf | Should -Be $true
            (Get-FileHash -LiteralPath $result.BackupPath -Algorithm SHA256).Hash | Should -Be $expectedHash
            Test-WinBreakPathIsWithin -Path $result.BackupPath -ParentPath $work | Should -Be $false
        }

        It 'chiede conferma e continua senza modifiche quando appraiserres.dll è assente' {
            $work = Join-Path $TestDrive 'appraiser-absent-continue-work'
            $sources = Join-Path $work 'sources'
            $backupRoot = Join-Path $TestDrive 'appraiser-absent-continue-backup'
            New-Item -ItemType Directory -Path $sources -Force | Out-Null
            $decoy = Join-Path $sources 'appraiser.dll'
            Set-Content -LiteralPath $decoy -Value 'must remain' -Encoding Ascii
            Mock -CommandName Read-WinBreakConfirmation -MockWith { return $true }

            $result = Remove-WinBreakAppraiser -WorkDirectory $work -BackupRoot $backupRoot

            $result.Continued | Should -Be $true
            $result.Removed | Should -Be $false
            $result.Planned | Should -Be $false
            Test-Path -LiteralPath $decoy -PathType Leaf | Should -Be $true
            Test-Path -LiteralPath $backupRoot | Should -Be $false
            Assert-MockCalled -CommandName Read-WinBreakConfirmation -Times 1 -Exactly -Scope It
        }

        It 'propaga il rifiuto quando appraiserres.dll è assente' {
            $work = Join-Path $TestDrive 'appraiser-absent-cancel-work'
            $sources = Join-Path $work 'sources'
            $backupRoot = Join-Path $TestDrive 'appraiser-absent-cancel-backup'
            New-Item -ItemType Directory -Path $sources -Force | Out-Null
            Mock -CommandName Read-WinBreakConfirmation -MockWith { return $false }

            $result = Remove-WinBreakAppraiser -WorkDirectory $work -BackupRoot $backupRoot

            $result.Continued | Should -Be $false
            $result.Removed | Should -Be $false
            Test-Path -LiteralPath $backupRoot | Should -Be $false
            Assert-MockCalled -CommandName Read-WinBreakConfirmation -Times 1 -Exactly -Scope It
        }

        It 'in DryRun lascia il file presente, non crea backup e non chiede conferma' {
            $work = Join-Path $TestDrive 'appraiser-dryrun-work'
            $sources = Join-Path $work 'sources'
            $backupRoot = Join-Path $TestDrive 'appraiser-dryrun-backup'
            New-Item -ItemType Directory -Path $sources -Force | Out-Null
            $target = Join-Path $sources 'appraiserres.dll'
            Set-Content -LiteralPath $target -Value 'keep in dryrun' -Encoding Ascii
            Mock -CommandName Copy-Item -MockWith { throw 'Copy-Item non deve essere chiamato in DryRun.' }
            Mock -CommandName Remove-Item -MockWith { throw 'Remove-Item non deve essere chiamato in DryRun.' }
            Mock -CommandName Read-WinBreakConfirmation -MockWith { throw 'Non serve conferma quando il file esiste.' }

            $result = Remove-WinBreakAppraiser -WorkDirectory $work -BackupRoot $backupRoot -DryRun

            $result.Planned | Should -Be $true
            $result.Removed | Should -Be $false
            Test-Path -LiteralPath $target -PathType Leaf | Should -Be $true
            Test-Path -LiteralPath $backupRoot | Should -Be $false
            Assert-MockCalled -CommandName Copy-Item -Times 0 -Exactly -Scope It
            Assert-MockCalled -CommandName Remove-Item -Times 0 -Exactly -Scope It
            Assert-MockCalled -CommandName Read-WinBreakConfirmation -Times 0 -Exactly -Scope It
        }

        It 'in DryRun con file assente non richiede input e pianifica la continuazione' {
            $work = Join-Path $TestDrive 'appraiser-absent-dryrun-work'
            New-Item -ItemType Directory -Path (Join-Path $work 'sources') -Force | Out-Null
            Mock -CommandName Read-WinBreakConfirmation -MockWith { throw 'La conferma non deve essere richiesta in DryRun.' }

            $result = Remove-WinBreakAppraiser -WorkDirectory $work -BackupRoot (Join-Path $TestDrive 'unused-backup') -DryRun

            $result.Continued | Should -Be $true
            $result.Removed | Should -Be $false
            $result.Planned | Should -Be $true
            Assert-MockCalled -CommandName Read-WinBreakConfirmation -Times 0 -Exactly -Scope It
        }
    }
}
