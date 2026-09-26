@{
    RootModule        = 'Ibcmd.DevOps.psm1'
    ModuleVersion     = '0.1.0'
    GUID              = '9c0d28bd-c3e0-4f08-91ed-4893d29b41fb'
    Author            = 'Alex Khazaroff and AI co-author'
    CompanyName       = 'Community project'
    Copyright         = 'Copyright (c) 2026 Alex Khazaroff'
    Description       = 'Experimental PowerShell wrappers for controlled ibcmd automation in heterogeneous 1C:Enterprise landscapes.'
    PowerShellVersion = '7.2'
    FunctionsToExport = @(
        'Invoke-Ibcmd',
        'Test-IbcmdAvailable',
        'Get-IbcmdHelp',
        'Export-1CInfobaseImage',
        'Export-1CConfigurationXml',
        'Import-1CConfigurationXml',
        'Save-1CConfigurationFile',
        'Install-1CConfigurationFile'
    )
    CmdletsToExport   = @()
    VariablesToExport = @()
    AliasesToExport   = @()
    PrivateData = @{
        PSData = @{
            Tags       = @('1C', 'ibcmd', 'DevOps', 'PowerShell')
            ProjectUri = 'https://github.com/OWNER/Ibcmd.DevOps'
            ReleaseNotes = 'Prototype 0.1.0. Requires validation against the target 1C:Enterprise platform version.'
        }
    }
}
