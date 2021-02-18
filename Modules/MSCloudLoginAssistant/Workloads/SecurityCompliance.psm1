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


    $connectionTriesCounter = 0
    $maxAttempts = 10
    $createdSession = $false
    do
    {
        $CurrentVerbosePreference = $VerbosePreference
        $CurrentInformationPreference = $InformationPreference
        $CurrentWarningPreference = $WarningPreference
        $VerbosePreference = "SilentlyContinue"
        $InformationPreference = "SilentlyContinue"
        $WarningPreference = "SilentlyContinue"

        $connectionTriesCounter++

        try
        {
            Connect-IPPSSession -Credential $Global:o365Credential `
                -ConnectionUri $ConnectionUrl `
                -AzureADAuthorizationEndpointUri $authorizationUrl `
                -Verbose:$false -ErrorAction Stop | Out-Null
            $createdSession = $true
            Write-Verbose -Message "Successfully connected to the Security And Compliance center"
        }
        catch
        {
            # unfortunatelly there is nothing except the error message that could uniquely identify this case, hello potential localization issues
            $isMaxAllowedConnectionsError = $null -ne $_.Exception -and $_.Exception.Message.Contains('Fail to create a runspace because you have exceeded the maximum number of connections allowed')
            if (!$isMaxAllowedConnectionsError)
            {
                throw
            }
        }
        finally
        {
            $VerbosePreference = $CurrentVerbosePreference
            $InformationPreference = $CurrentInformationPreference
            $WarningPreference = $CurrentWarningPreference
        }

        $shouldRetryConnection = !$createdSession -and $connectionTriesCounter -le $maxAttempts
        if ($shouldRetryConnection)
        {
            Write-Information "[$connectionTriesCounter/$maxAttempts] Too many existing workspaces. Waiting an additional 70 seconds for sessions to free up."
            Start-Sleep -Seconds 70
        }
    } while ($shouldRetryConnection)

    if (!$createdSession)
    {
        throw "The maximum retry attempt to create a Security And Complinace connection has been exceeded."
    }
}
