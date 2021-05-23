function Connect-MSCloudLoginSkypeForBusiness
{
    [CmdletBinding()]
    param()
    if ($Global:UseApplicationIdentity -and $null -eq $Global:o365Credential -and $null -eq $global:appIdentityParams.OnBehalfOfUserPrincipalName)
    {
        throw "The SkypeForBusiness Platform does not support connecting with application identity."
    }

    if (!$Global:UseApplicationIdentity -and $null -eq $Global:o365Credential)
    {
        $Global:o365Credential = Get-Credential -Message "Cloud Credential"
    }

    Connect-MSCloudLoginTeams


    try
    {
        Enable-AppDomainLoadAnyVersionResolution
        # if (!('Microsoft.Teams.ConfigApi.Cmdlets.TpmCmdletHost' -as [Type]))
        # {
        #     $rootDir = [System.IO.Path]::GetDirectoryName((Get-Module MicrosoftTeams).Path).TrimEnd('\')
        #     $csAuthCmdlets = $rootDir + "\bin\Microsoft.Teams.ConfigAPI.Cmdlets.private.dll"
        #     Add-Type -Path $csAuthCmdlets
        # }

        [SysKit.MsGraphAuthModulePatching.MsTeamsModulePatcher]::DoPatching([SysKit.MsGraphAuthModulePatching.MsTeamsAuthDelegate] {

                #repeating just in case
                $authResult = Get-OnBehalfOfAuthResult -TargetUri "48ac35b8-9aa8-4d74-927d-1f4a14a0b239" -UserPrincipalName $userprincipalNameToUse

                $result = New-Object 'SysKit.MsGraphAuthModulePatching.MsTeamsAuthResult'

                $teamsEnvironmentName = Get-PsModuleAzureEnvironmentName -AzureCloudEnvironmentName $Global:appIdentityParams.AzureCloudEnvironmentName -Platform "MicrosoftTeams"
                $configurationApiEnv = [Microsoft.Teams.ConfigApi.Cmdlets.DeploymentConfiguration]::MapTeamsEnvironmentNameToConfigApiEnvironment($teamsEnvironmentName)
                $configurationApiEndpoint = [Microsoft.Teams.ConfigApi.Cmdlets.DeploymentConfiguration]::ConfigApiEnvironmentToEndpoints[$configurationApiEnv]

                $administeredDomain = $authResult.UserInfo.DisplayableId.Split('@')[1]

                $result.AccessToken = $authResult.AccessToken
                $result.UserName = $authResult.UserInfo.DisplayableId
                $result.UniqueId = $authResult.UserInfo.UniqueId
                $result.TenantId = $authResult.TenantId
                $result.AdministeredDomain = $administeredDomain
                $result.ConfigApiEnvironment = $configurationApiEnv
                $result.ConfigApiEndpoint = $configurationApiEndpoint

                return $result
            })
    }
    finally
    {
        Disable-AppDomainLoadAnyVersionResolution
    }

}
