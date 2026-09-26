#requires -Version 7.2
param(
    [string]$IbcmdPath = 'ibcmd',
    [string]$TargetCf = './artifacts/demo.cf'
)

$module = Join-Path $PSScriptRoot '../src/Ibcmd.DevOps/Ibcmd.DevOps.psd1'
Import-Module $module -Force

# Пример с автономным сервером: параметры подключения и точные имена ключей
# должны соответствовать `ibcmd --help` вашей версии платформы.
$connectionArguments = @(
    '--config=/secure/1c/demo.yml',
    '--user=ci-user',
    '--password=DO-NOT-COMMIT'
)

Save-1CConfigurationFile `
    -IbcmdPath $IbcmdPath `
    -ConnectionArguments $connectionArguments `
    -OutputCfPath $TargetCf `
    -SensitiveValues @('DO-NOT-COMMIT') `
    -DryRun `
    -Confirm:$false
