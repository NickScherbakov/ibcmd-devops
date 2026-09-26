Set-StrictMode -Version Latest

function ConvertTo-IbcmdDisplayCommand {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)][string]$Executable,
        [Parameter(Mandatory)][string[]]$ArgumentList,
        [string[]]$SensitiveValues = @()
    )

    $display = @($Executable) + @($ArgumentList)
    $line = ($display | ForEach-Object {
        if ($_ -match '[\s"'']') { '"{0}"' -f ($_ -replace '"', '\"') } else { $_ }
    }) -join ' '

    foreach ($secret in $SensitiveValues) {
        if (-not [string]::IsNullOrEmpty($secret)) {
            $line = $line.Replace($secret, '<redacted>')
        }
    }
    return $line
}

function Invoke-Ibcmd {
    <#
    .SYNOPSIS
    Запускает ibcmd с массивом аргументов, журналированием и контролем exit code.
    .DESCRIPTION
    Требует PowerShell 7.2+; использует ProcessStartInfo.ArgumentList, чтобы не собирать
    одну небезопасную командную строку. Секреты можно исключить из журналов через
    SensitiveValues. DryRun печатает команду без запуска.
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)][string[]]$ArgumentList,
        [string]$IbcmdPath = 'ibcmd',
        [string]$LogPath,
        [string[]]$SensitiveValues = @(),
        [switch]$DryRun,
        [switch]$AllowNonZeroExitCode
    )

    $displayCommand = ConvertTo-IbcmdDisplayCommand `
        -Executable $IbcmdPath `
        -ArgumentList $ArgumentList `
        -SensitiveValues $SensitiveValues

    if ($DryRun) {
        [pscustomobject]@{
            Command  = $displayCommand
            ExitCode = $null
            StdOut   = ''
            StdErr   = ''
            DryRun   = $true
        }
        return
    }

    if ($LogPath) {
        $parent = Split-Path -Parent $LogPath
        if ($parent) { New-Item -ItemType Directory -Path $parent -Force | Out-Null }
    }

    $startInfo = [System.Diagnostics.ProcessStartInfo]::new()
    $startInfo.FileName = $IbcmdPath
    $startInfo.UseShellExecute = $false
    $startInfo.RedirectStandardOutput = $true
    $startInfo.RedirectStandardError = $true
    foreach ($argument in $ArgumentList) {
        [void]$startInfo.ArgumentList.Add([string]$argument)
    }

    $process = [System.Diagnostics.Process]::new()
    $process.StartInfo = $startInfo

    try {
        if (-not $process.Start()) {
            throw "Не удалось запустить $IbcmdPath"
        }
        $stdoutTask = $process.StandardOutput.ReadToEndAsync()
        $stderrTask = $process.StandardError.ReadToEndAsync()
        $process.WaitForExit()
        $stdout = $stdoutTask.GetAwaiter().GetResult()
        $stderr = $stderrTask.GetAwaiter().GetResult()
        $exitCode = $process.ExitCode
    }
    finally {
        $process.Dispose()
    }

    if ($LogPath) {
        $record = @(
            ('[{0}] {1}' -f (Get-Date -Format 'yyyy-MM-dd HH:mm:ssK'), $displayCommand),
            $stdout,
            $stderr,
            ('exitCode={0}' -f $exitCode),
            ''
        ) -join [Environment]::NewLine
        Add-Content -LiteralPath $LogPath -Value $record -Encoding utf8
    }

    $result = [pscustomobject]@{
        Command  = $displayCommand
        ExitCode = $exitCode
        StdOut   = $stdout
        StdErr   = $stderr
        DryRun   = $false
    }

    if (($exitCode -ne 0) -and -not $AllowNonZeroExitCode) {
        $message = "ibcmd завершился с кодом $exitCode. Команда: $displayCommand"
        if ($stderr) { $message += [Environment]::NewLine + $stderr.Trim() }
        throw $message
    }

    return $result
}

function Test-IbcmdAvailable {
    [CmdletBinding()]
    param([string]$IbcmdPath = 'ibcmd')

    $command = Get-Command -Name $IbcmdPath -ErrorAction SilentlyContinue
    if ($command) {
        [pscustomobject]@{ Available = $true; Path = $command.Source }
    }
    elseif (Test-Path -LiteralPath $IbcmdPath -PathType Leaf) {
        [pscustomobject]@{ Available = $true; Path = (Resolve-Path $IbcmdPath).Path }
    }
    else {
        [pscustomobject]@{ Available = $false; Path = $IbcmdPath }
    }
}

function Get-IbcmdHelp {
    [CmdletBinding()]
    param(
        [string[]]$CommandPath = @(),
        [string]$IbcmdPath = 'ibcmd',
        [string]$LogPath
    )

    Invoke-Ibcmd -IbcmdPath $IbcmdPath -ArgumentList (@($CommandPath) + '--help') `
        -LogPath $LogPath -AllowNonZeroExitCode
}

function Export-1CInfobaseImage {
    <#
    .SYNOPSIS
    Выгружает образ информационной базы в DT командой ibcmd infobase dump.
    .NOTES
    DT-выгрузка не считается полноценной стратегией резервного копирования.
    По официальной документации во время dump не должно быть соединений с базой.
    #>
    [CmdletBinding(SupportsShouldProcess, ConfirmImpact = 'High')]
    param(
        [Parameter(Mandatory)][string[]]$ConnectionArguments,
        [Parameter(Mandatory)][string]$OutputPath,
        [string]$IbcmdPath = 'ibcmd',
        [string]$LogPath,
        [string[]]$SensitiveValues = @(),
        [switch]$DryRun
    )

    if (-not $DryRun) {
        $parent = Split-Path -Parent $OutputPath
        if ($parent) { New-Item -ItemType Directory -Path $parent -Force | Out-Null }
    }

    $arguments = @('infobase', 'dump') + $ConnectionArguments + @($OutputPath)
    if ($PSCmdlet.ShouldProcess($OutputPath, 'Создать DT-образ информационной базы')) {
        Invoke-Ibcmd -IbcmdPath $IbcmdPath -ArgumentList $arguments -LogPath $LogPath `
            -SensitiveValues $SensitiveValues -DryRun:$DryRun
    }
}

function Export-1CConfigurationXml {
    [CmdletBinding(SupportsShouldProcess)]
    param(
        [Parameter(Mandatory)][string[]]$ConnectionArguments,
        [Parameter(Mandatory)][string]$OutputDirectory,
        [string]$IbcmdPath = 'ibcmd',
        [string]$LogPath,
        [string[]]$SensitiveValues = @(),
        [switch]$Sync,
        [switch]$DryRun
    )

    if (-not $DryRun) { New-Item -ItemType Directory -Path $OutputDirectory -Force | Out-Null }
    $arguments = @('infobase', 'config', 'export') + $ConnectionArguments
    if ($Sync) { $arguments += '--sync' }
    $arguments += $OutputDirectory

    if ($PSCmdlet.ShouldProcess($OutputDirectory, 'Экспортировать конфигурацию в XML')) {
        Invoke-Ibcmd -IbcmdPath $IbcmdPath -ArgumentList $arguments -LogPath $LogPath `
            -SensitiveValues $SensitiveValues -DryRun:$DryRun
    }
}

function Import-1CConfigurationXml {
    <#
    .NOTES
    Полный import полностью заменяет конфигурацию в целевой инфобазе.
    Поэтому требуется явный ключ AllowReplace.
    #>
    [CmdletBinding(SupportsShouldProcess, ConfirmImpact = 'High')]
    param(
        [Parameter(Mandatory)][string[]]$ConnectionArguments,
        [Parameter(Mandatory)][string]$InputDirectory,
        [Parameter(Mandatory)][switch]$AllowReplace,
        [string]$IbcmdPath = 'ibcmd',
        [string]$LogPath,
        [string[]]$SensitiveValues = @(),
        [switch]$DryRun
    )

    if (-not $DryRun -and -not (Test-Path -LiteralPath $InputDirectory -PathType Container)) {
        throw "Каталог XML не найден: $InputDirectory"
    }

    $arguments = @('infobase', 'config', 'import') + $ConnectionArguments + @($InputDirectory)
    if ($PSCmdlet.ShouldProcess($InputDirectory, 'Полностью заменить конфигурацию из XML')) {
        Invoke-Ibcmd -IbcmdPath $IbcmdPath -ArgumentList $arguments -LogPath $LogPath `
            -SensitiveValues $SensitiveValues -DryRun:$DryRun
    }
}

function Save-1CConfigurationFile {
    [CmdletBinding(SupportsShouldProcess)]
    param(
        [Parameter(Mandatory)][string[]]$ConnectionArguments,
        [Parameter(Mandatory)][string]$OutputCfPath,
        [string]$IbcmdPath = 'ibcmd',
        [string]$LogPath,
        [string[]]$SensitiveValues = @(),
        [switch]$DryRun
    )

    if (-not $DryRun) {
        $parent = Split-Path -Parent $OutputCfPath
        if ($parent) { New-Item -ItemType Directory -Path $parent -Force | Out-Null }
    }

    $arguments = @('infobase', 'config', 'save') + $ConnectionArguments + @($OutputCfPath)
    if ($PSCmdlet.ShouldProcess($OutputCfPath, 'Сохранить конфигурацию в CF')) {
        Invoke-Ibcmd -IbcmdPath $IbcmdPath -ArgumentList $arguments -LogPath $LogPath `
            -SensitiveValues $SensitiveValues -DryRun:$DryRun
    }
}

function Install-1CConfigurationFile {
    <#
    .SYNOPSIS
    Загружает CF и, при явном ключе Apply, обновляет конфигурацию базы данных.
    #>
    [CmdletBinding(SupportsShouldProcess, ConfirmImpact = 'High')]
    param(
        [Parameter(Mandatory)][string[]]$ConnectionArguments,
        [Parameter(Mandatory)][string]$CfPath,
        [switch]$Apply,
        [switch]$ForceApply,
        [string]$IbcmdPath = 'ibcmd',
        [string]$LogPath,
        [string[]]$SensitiveValues = @(),
        [switch]$DryRun
    )

    if (-not $DryRun -and -not (Test-Path -LiteralPath $CfPath -PathType Leaf)) {
        throw "CF-файл не найден: $CfPath"
    }

    $loadArguments = @('infobase', 'config', 'load') + $ConnectionArguments + @($CfPath)
    if ($PSCmdlet.ShouldProcess($CfPath, 'Загрузить CF в информационную базу')) {
        Invoke-Ibcmd -IbcmdPath $IbcmdPath -ArgumentList $loadArguments -LogPath $LogPath `
            -SensitiveValues $SensitiveValues -DryRun:$DryRun
    }

    if ($Apply) {
        $applyArguments = @('infobase', 'config', 'apply') + $ConnectionArguments
        if ($ForceApply) { $applyArguments += '--force' }
        if ($PSCmdlet.ShouldProcess('конфигурация базы данных', 'Применить изменения и выполнить необходимую реструктуризацию')) {
            Invoke-Ibcmd -IbcmdPath $IbcmdPath -ArgumentList $applyArguments -LogPath $LogPath `
                -SensitiveValues $SensitiveValues -DryRun:$DryRun
        }
    }
}

Export-ModuleMember -Function @(
    'Invoke-Ibcmd',
    'Test-IbcmdAvailable',
    'Get-IbcmdHelp',
    'Export-1CInfobaseImage',
    'Export-1CConfigurationXml',
    'Import-1CConfigurationXml',
    'Save-1CConfigurationFile',
    'Install-1CConfigurationFile'
)
