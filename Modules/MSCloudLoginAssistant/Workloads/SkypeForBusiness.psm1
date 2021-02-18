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

    $userprincipalNameToUse = ""
    if ($null -eq $Global:o365Credential)
    {
        $userprincipalNameToUse = $global:appIdentityParams.OnBehalfOfUserPrincipalName
    }
    else
    {
        $userprincipalNameToUse = $Global:o365Credential.UserName
    }

    $adminDomain = $userprincipalNameToUse.Split('@')[1]
    if ($userprincipalNameToUse.Split('@')[1] -like '*.de')
    {
        $Global:CloudEnvironment = 'Germany'
        Write-Warning 'Microsoft Teams is not supported in the Germany Cloud'
        return
    }

    $existingSessions = Get-PSSession | Where-Object -FilterScript { $_.Name -like 'SfBPowerShellSession*' }
    [array]$activeSessions = $existingSessions | Where-Object -FilterScript { $_.State -eq 'Opened' }
    [array] $sessionsToClose = $existingSessions | Where-Object -FilterScript { $_.State -ne 'Opened' }
    for ($i = 0; $i -lt $sessionsToClose.Length; $i++)
    {
        $sessionName = $sessionsToClose[$i].Name
        Write-Verbose "Closing remote powershell session $sessionName"
        Remove-Session $sessionsToClose[$i]
    }

    if ($activeSessions.Length -ge 1)
    {
        #  Write-Verbose -Message "Found {$($activeSessions.Length)} existing Security and Compliance Session"
        $command = Get-Command "Get-CsTeamsClientConfiguration" -ErrorAction 'SilentlyContinue'
        if ($null -ne $command)
        {
            return
        }

        $sfbModule = Import-PSSession $activeSessions[0] -DisableNameChecking -AllowClobber
        Import-Module $sfbModule -Global | Out-Null
        return
    }

    $connectionTriesCounter = 0
    $maxAttempts = 10
    $createdSession = $false
    $CurrentVerbosePreference = $VerbosePreference
    $CurrentInformationPreference = $InformationPreference
    $CurrentWarningPreference = $WarningPreference
    do
    {
        $connectionTriesCounter++

        try
        {
            Write-Verbose "Creating a new Session to Skype for Business Servers"
            $ErrorActionPreference = "Stop"

            $targetUri = Get-SkypeForBusinessServiceEndpoint -TargetDomain $adminDomain

            # we don't call Get-SkypeForBusinessAccessInfo
            # in the application identity use case we have our own clientId
            # disregarded the $authuri for now since it would mean that the authentication context would not be global any more
            $AccessToken = Get-OnBehalfOfAccessToken -TargetUri $targetUri -UserPrincipalName $userprincipalNameToUse

            $networkCreds = [System.Net.NetworkCredential]::new("", $AccessToken)
            $secPassword = $networkCreds.SecurePassword
            $user = "oauth"
            $cred = [System.Management.Automation.PSCredential]::new($user, $secPassword)

            $queryStr = "AdminDomain=$adminDomain"

            $ConnectionUri = [UriBuilder]$targetUri
            $ConnectionUri.Query = $queryStr

            $psSessionName = "SfBPowerShellSession"
            $ConnectorVersion = "7.0.2374.2"
            $SessionOption = New-PsSessionOption
            $SessionOption.ApplicationArguments = @{}
            $SessionOption.ApplicationArguments['X-MS-Client-Version'] = $ConnectorVersion
            $SessionOption.NoMachineProfile = $true


            $VerbosePreference = "SilentlyContinue"
            $InformationPreference = "SilentlyContinue"
            $WarningPreference = "SilentlyContinue"

            $Global:SkypeSession = New-PSSession -Name $psSessionName -ConnectionUri $ConnectionUri.Uri `
                -Credential $cred -Authentication Basic -SessionOption $SessionOption
            $Global:SkypeModule = Import-PSSession $Global:SkypeSession
            Import-Module $Global:SkypeModule -Global | Out-Null

            $createdSession = $true
            Write-Verbose "Created a new Session to Skype for Business Servers"
        }
        catch
        {
            # unfortunatelly there is nothing except the error message that could uniquely identify this case, hello potential localization issues
            $isMaxAllowedConnectionsError = $null -ne $_.Exception -and $_.Exception.Message.Contains('The maximum number of concurrent shells')
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
