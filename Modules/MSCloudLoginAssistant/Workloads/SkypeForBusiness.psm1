# this is constant between different clouds
$sfbAndTeamsAdminResourceGuidId = "48ac35b8-9aa8-4d74-927d-1f4a14a0b239"

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

    # the Teams module supports Sfb remote connections so we must first connect to it
    # but the thing is, it does not support connections with application permissions so we must do some magic
    # and patch the auth process to provide our own access token on behalf of the service user
    Connect-MSCloudLoginTeams


    # patching is performed via a custom dll that uses Harmony to change the auth behaviour
    [SysKit.MsGraphAuthModulePatching.MsTeamsModulePatcher]::DoPatching([SysKit.MsGraphAuthModulePatching.MsTeamsAuthDelegate] {
            $authResult = Get-OnBehalfOfAuthResult -TargetUri $sfbAndTeamsAdminResourceGuidId -UserPrincipalName $userprincipalNameToUse
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
