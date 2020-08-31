function Connect-MSCloudLoginMicrosoftGraph
{
    [CmdletBinding()]
    param(
    )


    if(!(Get-Module Microsoft.Graph.Authentication))
    {
        Import-Module -Name Microsoft.Graph.Authentication -DisableNameChecking -Force | out-null
    }

    if($Global:UseApplicationIdentity)
    {


        $onAssemblyResolveEventHandler = [ResolveEventHandler]{
            param($sender, $e)

            Write-Verbose $e.Name
            Write-Verbose "ResolveEventHandler: Attempting FullName resolution of $($e.Name)"
            foreach($assembly in [System.AppDomain]::CurrentDomain.GetAssemblies()) {
                if ($assembly.FullName -eq $e.Name) {
                    Write-Host "Successful FullName resolution of $($e.Name)"
                    return $assembly
                }
            }

            Write-Verbose "ResolveEventHandler: Attempting name-only resolution of $($e.Name)"
            foreach($assembly in [System.AppDomain]::CurrentDomain.GetAssemblies()) {
                # Get just the name from the FullName (no version)
                $assemblyName = $assembly.FullName.Substring(0, $assembly.FullName.IndexOf(", "))

                if ($e.Name.StartsWith($($assemblyName + ","))) {

                    Write-Verbose "Successful name-only (no version) resolution of $assemblyName"
                    return $assembly
                }
            }

            # return $null
        }

        try
        {
            [System.AppDomain]::CurrentDomain.add_AssemblyResolve($onAssemblyResolveEventHandler)
            if(!('Microsoft.Graph.AuthenticateRequestAsyncDelegate' -as [Type]))
            {
                $rootDir = [System.IO.Path]::GetDirectoryName((Get-Module Microsoft.Graph.Authentication).Path).TrimEnd('\')
                $graphCoreAssemblyPath  = $rootDir +"\bin\Microsoft.Graph.Core.dll"
                Add-Type -Path $graphCoreAssemblyPath
            }

            [SysKit.MsGraphAuthModulePatching.MsGraphAuthModulePatcher]::DoPatching([Microsoft.Graph.AuthenticateRequestAsyncDelegate]{
                param(
                    [Parameter()]
                    [System.Net.Http.HttpRequestMessage]
                    $request
                )

                $token = Get-OnBehalfOfAccessToken -TargetUri "https://graph.microsoft.com"
                $request.Headers.Authorization = [System.Net.Http.Headers.AuthenticationHeaderValue]::new("Bearer", $token)
                return [System.Threading.Tasks.Task]::CompletedTask
            })
        }
        finally
        {
            [System.AppDomain]::CurrentDomain.remove_AssemblyResolve($onAssemblyResolveEventHandler)
        }







      #  Add-Type -AssemblyName "C:\GitProjects\MSCloudLoginAssistant-SysKit\Modules\MSCloudLoginAssistant\Utilities\MsGrapgModuleAuthFix\MsGraphAuthModulePatcher.dll"

        # Connect-Graph -ClientId $Global:appIdentityParams.AppId -TenantId $Global:appIdentityParams.Tenant `
        #     -CertificateThumbprint $Global:appIdentityParams.CertificateThumbprint

        $authContext = [Microsoft.Graph.PowerShell.Authentication.AuthContext]::new()
        $authContext.TenantId = $Global:appIdentityParams.Tenant
        $authContext.ClientId = $Global:appIdentityParams.AppId
        $authContext.AuthType = [Microsoft.Graph.PowerShell.Authentication.AuthenticationType]::Delegated


        [Microsoft.Graph.PowerShell.Authentication.GraphSession]::Instance.AuthContext = $authContext

        Write-Verbose "Connected to MicrosoftGraph using application identity with certificate thumbprint"
    }
    else
    {
        throw "Not implemented"
    }
}

function Connect-MSCloudLoginMSGraphWithUser
{
    [CmdletBinding()]
    Param(
        [Parameter(Mandatory = $true)]
        [System.Management.Automation.PSCredential]
        $CloudCredential,

        [Parameter()]
        [System.String]
        $ApplicationId = "14d82eec-204b-4c2f-b7e8-296a70dab67e" #PoSh Graph SDK
    )
    if ($null -eq $Global:MSCloudLoginGraphAccessToken)
    {
        $azuretenantADName = $CloudCredential.UserName.Split('@')[1]

        #Authority to Azure AD Tenant
        $AzureADAuthority = "https://login.microsoftonline.com/$azuretenantADName/oauth2/v2.0/authorize"

        #Resource URI to the Microsoft Graph
        $resourceURL = "https://graph.microsoft.com/"

        # Create UserCredential object
        $accessToken = Get-AccessToken -TargetUri $resourceUrl `
            -AuthUri $AzureADAuthority `
            -ClientId $ApplicationId `
            -Credentials $CloudCredential
        $Global:MSCloudLoginGraphAccessToken = $accessToken
    }
}

function Connect-MSCloudLoginMSGraphWithServicePrincipal
{
    [CmdletBinding()]
    Param(
        [Parameter(Mandatory = $true)]
        [System.String]
        $ApplicationId,

        [Parameter(Mandatory = $true)]
        [System.String]
        $TenantId,

        [Parameter(Mandatory = $true)]
        [System.String]
        $ApplicationSecret
    )

    $url = "https://login.microsoftonline.com/$TenantId/oauth2/v2.0/token"
    $body = "client_id=$ApplicationId&scope=https%3A%2F%2Fgraph.microsoft.com%2F.default&client_secret=$ApplicationSecret&grant_type=client_credentials"
    $response = Invoke-RestMethod -Method POST -Uri $url -Body $body
    $Global:MSCloudLoginGraphAccessToken = $response.access_token
}

function Connect-MSCloudLoginMSGraphWithServicePrincipalDelegated
{
    [CmdletBinding()]
    Param(
        [Parameter(Mandatory = $true)]
        [System.String]
        $ApplicationId,

        [Parameter(Mandatory = $true)]
        [System.String]
        $TenantId,

        [Parameter(Mandatory = $true)]
        [System.String]
        $ApplicationSecret,

        [Parameter(Mandatory = $true)]
        [System.String]
        $Scope
    )

    $url = "https://login.microsoftonline.com/$TenantId/oauth2/v2.0/authorize?"
    $body = "client_id=$ApplicationId&scope=$scope&client_secret=$ApplicationSecret&response_type=code"
    $response = Invoke-RestMethod -Method GET -Uri ($url + $body)
    $Global:MSCloudLoginGraphAccessToken = $response.access_token
}

function Invoke-MSCloudLoginMicrosoftGraphAPI
{
    [CmdletBinding()]
    [OutputType([System.String])]
    Param(
        [Parameter(Mandatory = $true)]
        [System.String]
        $Uri,

        [Parameter()]
        [System.String]
        $Body,

        [Parameter()]
        [System.Collections.Hashtable]
        $Headers,

        [Parameter()]
        [System.String]
        $Method,

        [Parameter()]
        [System.Management.Automation.PSCredential]
        $CloudCredential,

        [Parameter()]
        [System.String]
        $ApplicationId,

        [Parameter()]
        [System.UInt32]
        $CallCount = 1
    )

    $accessToken = Get-OnBehalfOfAccessToken -TargetUri "https://graph.microsoft.com"
    $requestHeaders = @{
        "Authorization" = "Bearer " + $accessToken
        "Content-Type" = "application/json"
    }
    foreach ($key in $Headers.Keys)
    {
        Write-Verbose -Message "    $key = $($requestHeaders.$key)"
        $requestHeaders.Add($key, $Headers.$key)
    }

    Write-Verbose -Message "URI: $Uri"
    Write-Verbose -Message "Method: $Method"
    $requestParams = @{
        Method  = $Method
        Uri     = $Uri
        Headers = $requestHeaders
    }
    if (-not [System.String]::IsNullOrEmpty($Body))
    {
        $requestParams.Add("Body", $Body)
        Write-Verbose -Message "Body: $Body"
    }

    # the error handling with retry makes no sense, maybe retry for transient errors but this is for auth
    # try
    # {
        $Result = Invoke-RestMethod @requestParams
    # }
    # catch
    # {
    #     Write-Verbose -Message $_
    #     if ($_.Exception -like '*The remote server returned an error: (401) Unauthorized.*')
    #     {
    #         if ($CallCount -eq 1)
    #         {
    #             Write-Verbose -Message "This is the first time the method is called. Wait 10 seconds and retry the call."
    #             Start-Sleep -Seconds 10
    #         }
    #         else
    #         {
    #             $newSleepTime = 10 * $CallCount
    #             Write-Verbose -Message "The Access Token expired, waiting {$newSleepTime} and then regenerating a new one."
    #             $Global:MSCloudLoginGraphAccessToken = $null
    #         }
    #         $CallCount++
    #         try
    #         {
    #             $PSBoundParameters.Remove("CallCount") | Out-Null
    #         }
    #         catch
    #         {
    #             Write-Verbose -Message "CallCount was not already specified."
    #         }
    #         return (Invoke-MSCloudLoginMicrosoftGraphAPI @PSBoundParameters -CallCount $CallCount)
    #     }
    #     throw $_
    # }
    return $result
}
