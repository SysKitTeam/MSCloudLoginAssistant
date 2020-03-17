#
# Module manifest for module 'MSCloudLoginAssistant'
#
# Generated by: Team Office365DSC
#
# Generated on: 28/01/2020
#

@{

    # Script module or binary module file associated with this manifest.
    RootModule = 'MSCloudLoginAssistant.psm1'

    # Version number of this module.
    ModuleVersion = '1.0.2'

    # Supported PSEditions
    # CompatiblePSEditions = @()

    # ID used to uniquely identify this module
    GUID = 'ca0435a6-ea50-4aa6-8f97-5d031fdc5abe'

    # Author of this module
    Author = 'Microsoft Corporation'

    # Company or vendor of this module
    CompanyName = 'Microsoft Corporation'

    # Copyright statement for this module
    Copyright = '(c) 2020 Microsoft Corporation. All rights reserved.'

    # Description of the functionality provided by this module
    Description = 'Checks the current status of connections to (and as required, prompts for login to) various Microsoft Cloud platforms.'

    # Minimum version of the Windows PowerShell engine required by this module
    PowerShellVersion = '5.1'

    # Name of the Windows PowerShell host required by this module
    # PowerShellHostName = ''

    # Minimum version of the Windows PowerShell host required by this module
    # PowerShellHostVersion = ''

    # Minimum version of Microsoft .NET Framework required by this module. This prerequisite is valid for the PowerShell Desktop edition only.
    DotNetFrameworkVersion = '4.7.2'

    # Minimum version of the common language runtime (CLR) required by this module. This prerequisite is valid for the PowerShell Desktop edition only.
    # CLRVersion = ''

    # Processor architecture (None, X86, Amd64) required by this module
    # ProcessorArchitecture = ''

    # Modules that must be imported into the global environment prior to importing this module
    RequiredModules = @(@{
        ModuleName      = "AzureAD"
        RequiredVersion = "2.0.2.4"	
    })

    # Assemblies that must be loaded prior to importing this module    
    # RequiredAssemblies = @()

    # Script files (.ps1) that are run in the caller's environment prior to importing this module.
    # ScriptsToProcess = @()

    # Type files (.ps1xml) to be loaded when importing this module
    # TypesToProcess = @()

    # Format files (.ps1xml) to be loaded when importing this module
    # FormatsToProcess = @()

    # Modules to import as nested modules of the module specified in RootModule/ModuleToProcess
    NestedModules     = @(
        'Workloads\Azure.psm1',
        'Workloads\AzureAD.psm1',
        'Workloads\ExchangeOnline.psm1',
        'Workloads\MSOnline.psm1',
        'Workloads\PnP.psm1',
        'Workloads\PowerPlatform.psm1',
        'Workloads\SecurityCompliance.psm1',
        'Workloads\SharePointOnline.psm1',
        'Workloads\SkypeForBusiness.psm1',
        'Workloads\Teams.psm1',
        'Utilities\Adal.psm1'
    )

    # Functions to export from this module, for best performance, do not use wildcards and do not delete the entry, use an empty array if there are no functions to export.
    #FunctionsToExport = ''

    # Cmdlets to export from this module, for best performance, do not use wildcards and do not delete the entry, use an empty array if there are no cmdlets to export.
    CmdletsToExport = @('Test-MSCloudLogin', 'Get-SPOAdminUrl')

    # Variables to export from this module
    VariablesToExport = '*'

    # Aliases to export from this module, for best performance, do not use wildcards and do not delete the entry, use an empty array if there are no aliases to export.
    AliasesToExport = @()

    # DSC resources to export from this module
    # DscResourcesToExport = @()

    # List of all modules packaged with this module
    # ModuleList = @()

    # List of all files packaged with this module
    # FileList = @()

    # Private data to pass to the module specified in RootModule/ModuleToProcess. This may also contain a PSData hashtable with additional module metadata used by PowerShell.
    PrivateData = @{

        PSData = @{

            # Tags applied to this module. These help with module discovery in online galleries.
            Tags = 'Azure', 'Az', 'AzureAD', 'Cloud', 'Office365', 'PnP', 'MicrosoftTeams', "ExchangeOnline", "SharePointOnline"

            # A URL to the license for this module.
            # LicenseUri = ''

            # A URL to the main website for this project.
            ProjectUri = 'https://github.com/Microsoft/MSCloudLoginAssistant'

            # A URL to an icon representing this module.
            # IconUri = ''

            # ReleaseNotes of this module
            # ReleaseNotes = ''
            # Prerelease string of this module
            # Prerelease = '-pre'
            # External dependent modules of this module
            # ExternalModuleDependencies = @()

        } # End of PSData hashtable

    } # End of PrivateData hashtable

    # HelpInfo URI of this module
    # HelpInfoURI = ''

    # Default prefix for commands exported from this module. Override the default prefix using Import-Module -Prefix.
    # DefaultCommandPrefix = ''

}

