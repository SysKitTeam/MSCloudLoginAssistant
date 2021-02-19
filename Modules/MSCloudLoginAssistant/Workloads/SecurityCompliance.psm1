function Connect-MSCloudLoginSecurityCompliance
{
    [CmdletBinding()]
    param()
    if ($Global:UseApplicationIdentity -and $null -eq $Global:o365Credential)
    {
        throw "The SecurityComplianceCenter Platform does not support connecting with application identity."
    }

    $WarningPreference = 'SilentlyContinue'
    $ProgressPreference = 'SilentlyContinue'
    $InformationPreference = 'Continue'
    $authorizationUrl = Get-AzureEnvironmentEndpoint -AzureCloudEnvironmentName $Global:appIdentityParams.AzureCloudEnvironmentName -EndpointName ActiveDirectory
    $authorizationUrl += "common"
    $ConnectionUrl = Get-AzureEnvironmentEndpoint -AzureCloudEnvironmentName $Global:appIdentityParams.AzureCloudEnvironmentName -EndpointName SecurityAndCompliancePsConnection
    $uriObj = [Uri]::new($ConnectionUrl)
    $scHost = $uriObj.Host

    
    $maxConnectionsSearchString = "Fail to create a runspace because you have exceeded the maximum number of connections allowed"
    
    Ensure-RemotePsSession -RemoteSessionName "Security and Compliance" `
        -TestModuleLoadedCommand "Get-ComplianceSearch" `
        -MaxConnectionsMessageSearchString $maxConnectionsSearchString `
        -ExistingSessionPredicate { ($_.ComputerName -like '*.ps.compliance.protection*' -or $_.ComputerName -like "*$scHost*" ) } `
        -CreateSessionScriptBlock {
        Connect-IPPSSession -Credential $Global:o365Credential `
            -ConnectionUri $ConnectionUrl `
            -AzureADAuthorizationEndpointUri $authorizationUrl `
            -Verbose:$false -ErrorAction Stop | Out-Null
    }
}
