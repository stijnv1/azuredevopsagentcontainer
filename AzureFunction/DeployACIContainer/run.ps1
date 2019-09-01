using namespace System.Net

# Input bindings are passed in via param block.
param($Request, $TriggerMetadata)

# Write to the Azure Functions log stream.
Write-Host "PowerShell HTTP trigger function processed a request."

# Interact with query parameters or the body of the request.
$rgName = $Request.Query.RGName
$containergroupName = $Request.Query.ACIGroupName


# create environmental variable hashtable
$azdevopsagentVariables = @{
    "VSTS_AGENT_INPUT_URL" = $env:VSTS_AGENT_INPUT_URL;
    "VSTS_AGENT_INPUT_AUTH" = $env:VSTS_AGENT_INPUT_AUTH;
    "VSTS_AGENT_INPUT_TOKEN" = $env:VSTS_AGENT_INPUT_TOKEN;
    "VSTS_AGENT_INPUT_AGENT" = $env:VSTS_AGENT_INPUT_AGENT
}

# create ps credential for access to acr
$secpasswd = ConvertTo-SecureString $env:ACRPASSWORD -AsPlainText -Force
$creds = New-Object System.Management.Automation.PSCredential ($env:ACRUSERNAME, $secpasswd)

# create container group
$acigroup = New-AzContainerGroup -ResourceGroupName $rgName `
                -Name $containergroupName `
                -Image $env:IMAGENAME `
                -EnvironmentVariable $azdevopsagentVariables `
                -OsType Linux `
                -RegistryCredential $creds

$body = "container group $containergroupName has been deployed"
$status = [HttpStatusCode]::OK
# Associate values to output bindings by calling 'Push-OutputBinding'.
Push-OutputBinding -Name Response -Value ([HttpResponseContext]@{
    StatusCode = $status
    Body = $body
})
