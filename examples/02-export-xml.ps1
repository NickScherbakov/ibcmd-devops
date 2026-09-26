#requires -Version 7.2
param(
    [Parameter(Mandatory)][string]$ConfigPath,
    [string]$OutputDirectory = './artifacts/config-xml',
    [string]$IbcmdPath = 'ibcmd'
)

$module = Join-Path $PSScriptRoot '../src/Ibcmd.DevOps/Ibcmd.DevOps.psd1'
Import-Module $module -Force

Export-1CConfigurationXml `
    -IbcmdPath $IbcmdPath `
    -ConnectionArguments @("--config=$ConfigPath") `
    -OutputDirectory $OutputDirectory `
    -Sync `
    -LogPath './artifacts/logs/export-xml.log' `
    -Confirm
