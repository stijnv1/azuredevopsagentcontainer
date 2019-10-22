using namespace System.Net

# Input bindings are passed in via param block.
param($Request, $TriggerMetadata)

# Write to the Azure Functions log stream.
Write-Host "PowerShell HTTP trigger function processed a request."

# Interact with query parameters or the body of the request.
$rgName = $Request.Query.RGName
$containergroupName = $Request.Query.ACIGroupName
$numberOfAgents = $Request.Query.NumberOfAgents

# if no query parameters found, use body
if (-not $rgName -or -not $containergroupName -or -not $numberOfAgents)
{
    $rgName = $Request.Body.RGName
    $containergroupName = $Request.Body.ACIGroupName
    $numberOfAgents = $Request.Body.NumberOfAgents
}

# check if VSTS_AGENT_INPUT_TOKEN and ACRPASSWORD is valid (keyvault reference used, does not work for local development)
# if local development, use the Uri of the secret to get the secret value
if ($env:VSTS_AGENT_INPUT_TOKEN -like "@Microsoft.KeyVault(SecretUri*")
{
    $secretId = $($env:VSTS_AGENT_INPUT_TOKEN).Substring($($env:VSTS_AGENT_INPUT_TOKEN).IndexOf('=')+1).Replace(')','')
    $secretUri = [System.Uri]$secretId
    $pattoken = (Get-AzKeyVaultSecret -VaultName $secretUri.Host.Split('.')[0] -Name $secretUri.Segments[2].Replace('/','')).SecretValueText
}
else
{
    $pattoken = $env:VSTS_AGENT_INPUT_TOKEN
}

if ($env:ACRPASSWORD -like "@Microsoft.KeyVault(SecretUri*")
{
    $secretId = $($env:ACRPASSWORD).Substring($($env:ACRPASSWORD).IndexOf('=')+1).Replace(')','')
    $secretUri = [System.Uri]$secretId
    $acrpassword = (Get-AzKeyVaultSecret -VaultName $secretUri.Host.Split('.')[0] -Name $secretUri.Segments[2].Replace('/','')).SecretValueText
}
else
{
    $acrpassword = $env:ACRPASSWORD
}

# create environmental variable hashtable
for ($i = 0; $i -lt $numberOfAgents; $i++) {
    $agentname = $env:VSTS_AGENT_INPUT_AGENT
    $agentname = "$agentname-$i"

    $azdevopsagentVariables = @{
        "VSTS_AGENT_INPUT_URL" = $env:VSTS_AGENT_INPUT_URL;
        "VSTS_AGENT_INPUT_AUTH" = $env:VSTS_AGENT_INPUT_AUTH;
        "VSTS_AGENT_INPUT_TOKEN" = $pattoken;
        "VSTS_AGENT_INPUT_AGENT" = $agentname;
        "VSTS_AGENT_INPUT_POOL" = $env:VSTS_AGENT_INPUT_POOL
    }

    # create ps credential for access to acr
    $secpasswd = ConvertTo-SecureString $acrpassword -AsPlainText -Force
    $creds = New-Object System.Management.Automation.PSCredential ($env:ACRUSERNAME, $secpasswd)
    $azcontext = Get-AzContext

    # create container group
    try
    {
        $ScriptBlock = {
            param(
                $rgName,
                $containergroupName,
                $azdevopsagentVariables,
                $creds,
                $azcontext,
                $counter
            )
            
            Set-AzContext -Context $azcontext 
            $acigroup = New-AzContainerGroup -ResourceGroupName $rgName `
                        -Name "$containergroupName-$counter" `
                        -Image $env:IMAGENAME `
                        -EnvironmentVariable $azdevopsagentVariables `
                        -OsType Linux `
                        -RegistryCredential $creds `
                        -ErrorAction Stop
        }

        $job = Start-ThreadJob -ScriptBlock $ScriptBlock -ArgumentList $rgName,$containergroupName,$azdevopsagentVariables,$creds,$azcontext,$i
         
    }
    catch
    {
        $body = "Error occured during container deployment: $_"
        $status = [HttpStatusCode]::InternalServerError
        # Associate values to output bindings by calling 'Push-OutputBinding'.
        Push-OutputBinding -Name Response -Value ([HttpResponseContext]@{
            StatusCode = $status
            Body = $body
        })
    }
}

[Array]$acis = $()
Get-Job | ForEach-Object {
    $acis += Receive-Job -Job $_ -Wait
}

$body = @{aciJobs=$acis} | ConvertTo-Json
$status = [HttpStatusCode]::OK
# Associate values to output bindings by calling 'Push-OutputBinding'.
Push-OutputBinding -Name Response -Value ([HttpResponseContext]@{
    StatusCode = $status
    Body = $body
}) 
