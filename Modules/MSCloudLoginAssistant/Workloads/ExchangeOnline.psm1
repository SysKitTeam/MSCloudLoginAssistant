function Connect-MSCloudLoginExchangeOnline
{
    [CmdletBinding()]
    param()
    $WarningPreference = 'SilentlyContinue'
    $ProgressPreference = 'SilentlyContinue'

    $ExoEnvName = Get-PsModuleAzureEnvironmentName -AzureCloudEnvironmentName $Global:appIdentityParams.AzureCloudEnvironmentName -Platform "ExchangeOnline"
    $ApplicationId = $Global:appIdentityParams.AppId
    $TenantId = $Global:appIdentityParams.Tenant
    $CertificateThumbprint = $Global:appIdentityParams.CertificateThumbprint
    $authorizationUrl = Get-AzureEnvironmentEndpoint -AzureCloudEnvironmentName $Global:appIdentityParams.AzureCloudEnvironmentName -EndpointName ActiveDirectory
    $authorizationUrl += "common"
    $psConnectionUri = Get-AzureEnvironmentEndpoint -AzureCloudEnvironmentName $Global:appIdentityParams.AzureCloudEnvironmentName -EndpointName ExchangePsConnection
    $uriObj = [Uri]::new($psConnectionUri)
    $exchangeHost = $uriObj.Host
    $existingSessions = Get-PSSession | Where-Object -FilterScript { ($_.ComputerName -like '*outlook.office*' -or $_.ComputerName -like "*$exchangeHost*" ) }
    [array]$activeSessions = $existingSessions | Where-Object -FilterScript { $_.State -eq 'Opened' }
    [array] $sessionsToClose = $existingSessions | Where-Object -FilterScript { $_.State -ne 'Opened' }
    for ($i = 0; $i -lt $sessionsToClose.Length; $i++)
    {
        Write-Verbose "Closing session $($sessionsToClose[$i].Name)"
        Remove-Session $sessionsToClose[$i]
    }

    if ($activeSessions.Length -ge 1)
    {
        Write-Verbose -Message "Found {$($activeSessions.Length)} existing Exchange Online Session"
        $command = Get-Command "Get-AcceptedDomain" -ErrorAction 'SilentlyContinue'
        if ($null -ne $command)
        {
            return
        }
        $EXOModule = Import-PSSession $activeSessions[0] -DisableNameChecking -AllowClobber
        Import-Module $EXOModule -Global | Out-Null
        return
    }
    Write-Verbose -Message "No active Exchange Online session found."

    #endregion
    if (-not [String]::IsNullOrEmpty($ApplicationId) -and `
            -not [String]::IsNullOrEmpty($TenantId) -and `
            -not [String]::IsNullOrEmpty($CertificateThumbprint))
    {
        $Organization = Get-MSCloudLoginOrganizationName -ApplicationId $ApplicationId `
            -TenantId $TenantId `
            -CertificateThumbprint $CertificateThumbprint
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
                Write-Verbose -Message "Attempting to connect to Exchange Online using AAD App {$ApplicationID}"
                Connect-ExchangeOnline -AppId $ApplicationId `
                    -Organization $Organization `
                    -CertificateThumbprint $CertificateThumbprint `
                    -ShowBanner:$false `
                    -ShowProgress:$false `
                    -ConnectionUri $psConnectionUri `
                    -AzureADAuthorizationEndpointUri $AuthorizationUrl `
                    -ExchangeEnvironmentName $ExoEnvName `
                    -Verbose:$false | Out-Null
                $createdSession = $true
                Write-Verbose -Message "Successfully connected to Exchange Online using AAD App {$ApplicationID}"
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
            throw "The maximum retry attempt to create a EXO managment connection has been exceeded."
        }
    }
    else
    {
        throw "Connecting without an application identity is not supported"
    }
}
