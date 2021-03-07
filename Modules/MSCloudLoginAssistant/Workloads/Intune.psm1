function Connect-MSCloudLoginIntune
{
    [CmdletBinding()]
    param(
    )


    if (!(Get-Module Microsoft.Graph.Intune))
    {
        Import-Module -Name Microsoft.Graph.Intune -DisableNameChecking -Force | out-null
    }

    if ($Global:UseApplicationIdentity)
    {
       
        try
        {
            Enable-AppDomainLoadAnyVersionResolution
            if (!('Microsoft.Intune.PowerShellGraphSDK.PowerShellCmdlets.ODataCmdletBase' -as [Type]))
            {
                $rootDir = [System.IO.Path]::GetDirectoryName((Get-Module Microsoft.Graph.Intune).Path).TrimEnd('\')
                $intunePsSdkPath = $rootDir + "\bin\Microsoft.Intune.PowerShellGraphSDK.dll"
                Add-Type -Path $intunePsSdkPath
            }
            

            # the official Connect-Graph cmdlet does not support certificates ouside the my personal store for the current user
            # and for delegated access it only supports device code auth
            # since we already have the authentication context that we can use to authenticate to graph
            # we redirect it by replacing the auth implementation in runtime
            [SysKit.MsGraphAuthModulePatching.MsGraphIntuneAuthModulePatcher]::DoPatching([SysKit.MsGraphAuthModulePatching.MsGraphIntuneAuthDelegate] {
                    $graphEndpoint = Get-AzureEnvironmentEndpoint -AzureCloudEnvironmentName $Global:appIdentityParams.AzureCloudEnvironmentName -EndpointName MsGraphEndpointResourceId
                    $authResult = Get-AppIdentityAuthResult -TargetUri $graphEndpoint

                    $result = New-Object 'SysKit.MsGraphAuthModulePatching.MsGraphIntuneAuthResult'

                    $result.AccessTokenType = "Bearer"
                    $result.AccessToken = $authResult.AccessToken
                    $result.ExpiresOn = $authResult.ExpiresOn

                    return $result                    
                })
        }
        finally
        {
            Disable-AppDomainLoadAnyVersionResolution
        }

        Write-Verbose "Connected to MicrosoftGraph using application identity with certificate thumbprint"
    }
    else
    {
        throw "Not implemented"
    }
}