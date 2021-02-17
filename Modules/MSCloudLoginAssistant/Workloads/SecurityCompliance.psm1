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

    $existingSessions = Get-PSSession | Where-Object -FilterScript { ($_.ComputerName -like '*.ps.compliance.protection*' -or $_.ComputerName -like "*$scHost*" ) }
    [array]$activeSessions = $existingSessions | Where-Object -FilterScript { $_.State -eq 'Opened' }
    [array] $sessionsToClose = $existingSessions | Where-Object -FilterScript { $_.State -ne 'Opened' }
    for ($i = 0; $i -lt $sessionsToClose.Length; $i++)
    {
        Write-Verbose "Closing session $($sessionsToClose[$i].Name)"
        Remove-Session $sessionsToClose[$i]
    }
    if ($activeSessions.Length -ge 1)
    {
        #  Write-Verbose -Message "Found {$($activeSessions.Length)} existing Security and Compliance Session"
        $command = Get-Command "Get-ComplianceSearch" -ErrorAction 'SilentlyContinue'
        if ($null -ne $command)
        {
            return
        }
        $SCModule = Import-PSSession $activeSessions[0] -DisableNameChecking -AllowClobber
        Import-Module $SCModule -Global | Out-Null
        return
    }

    $CurrentVerbosePreference = $VerbosePreference
    $CurrentInformationPreference = $InformationPreference
    $CurrentWarningPreference = $WarningPreference
    $VerbosePreference = "SilentlyContinue"
    $InformationPreference = "SilentlyContinue"
    $WarningPreference = "SilentlyContinue"
    try
    {
        Connect-IPPSSession -Credential $Global:o365Credential `
            -ConnectionUri $ConnectionUrl `
            -AzureADAuthorizationEndpointUri $authorizationUrl `
            -Verbose:$false -ErrorAction Stop | Out-Null
    }
    finally
    {
        $VerbosePreference = $CurrentVerbosePreference
        $InformationPreference = $CurrentInformationPreference
        $WarningPreference = $CurrentWarningPreference
    }


}
