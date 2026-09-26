#requires -Version 7.2
param(
    [string]$IbcmdPath = 'ibcmd'
)

$module = Join-Path $PSScriptRoot '../src/Ibcmd.DevOps/Ibcmd.DevOps.psd1'
Import-Module $module -Force

$availability = Test-IbcmdAvailable -IbcmdPath $IbcmdPath
$availability | Format-List
if (-not $availability.Available) {
    throw "ibcmd не найден. Передайте -IbcmdPath или добавьте каталог платформы в PATH."
}

Get-IbcmdHelp -IbcmdPath $IbcmdPath
Get-IbcmdHelp -IbcmdPath $IbcmdPath -CommandPath @('infobase', 'config')
