#requires -Version 7.2
$ErrorActionPreference = 'Stop'
Import-Module (Join-Path $PSScriptRoot '../src/Ibcmd.DevOps/Ibcmd.DevOps.psd1') -Force

$outputDirectory = './artifacts/article-dry-run/config-xml'
$logPath = './artifacts/article-dry-run/export.log'
if (Test-Path './artifacts/article-dry-run') {
    throw 'Для проверки отсутствия файлов нужен свободный путь ./artifacts/article-dry-run.'
}

# Фиктивные параметры: DryRun не читает этот config и не запускает ibcmd.
$result = Export-1CConfigurationXml `
    -IbcmdPath 'ibcmd' `
    -ConnectionArguments @('--config=./config/demo.yml', '--password=DEMO-ONLY') `
    -OutputDirectory $outputDirectory `
    -LogPath $logPath `
    -SensitiveValues @('DEMO-ONLY') `
    -Sync -DryRun -Confirm:$false

$checks = [ordered]@{
    Command = $result.Command
    DryRun = $result.DryRun
    ExitCode = $result.ExitCode
    OutputDirectoryExists = Test-Path -LiteralPath $outputDirectory
    LogExists = Test-Path -LiteralPath $logPath
    SecretMasked = -not $result.Command.Contains('DEMO-ONLY')
}
if (-not $checks.DryRun -or $null -ne $checks.ExitCode -or
    $checks.OutputDirectoryExists -or $checks.LogExists -or -not $checks.SecretMasked) {
    throw 'Результат DryRun не соответствует ожидаемому.'
}
$checks | ConvertTo-Json
