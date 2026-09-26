#requires -Version 7.2
param(
    [Parameter(Mandatory)][string]$ConfigPath,
    [Parameter(Mandatory)][string]$CfPath,
    [string]$IbcmdPath = 'ibcmd',
    [switch]$Apply,
    [switch]$ForceApply
)

$module = Join-Path $PSScriptRoot '../src/Ibcmd.DevOps/Ibcmd.DevOps.psd1'
Import-Module $module -Force

Install-1CConfigurationFile `
    -IbcmdPath $IbcmdPath `
    -ConnectionArguments @("--config=$ConfigPath") `
    -CfPath $CfPath `
    -Apply:$Apply `
    -ForceApply:$ForceApply `
    -LogPath './artifacts/logs/install-cf.log' `
    -Confirm
