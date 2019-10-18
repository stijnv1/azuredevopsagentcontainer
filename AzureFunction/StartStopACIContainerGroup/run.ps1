using namespace System.Net

# Input bindings are passed in via param block.
param($Request, $TriggerMetadata)

# Write to the Azure Functions log stream.
Write-Host "PowerShell HTTP trigger function processed a request."

# Interact with query parameters or the body of the request.
$action = $Request.Query.Action
$rgName = $Request.Query.RGName
$containergroupName = $Request.Query.ACIGroupName

if (-not $rgName -or -not $containergroupName -or -not $action)
{
    $rgName = $Request.Body.RGName
    $containergroupName = $Request.Body.ACIGroupName
    $action = $Request.Body.Action
}

try
{
    switch ($action) {
        "start" { 
            if ((Get-AzContainerGroup -ResourceGroupName $rgName -Name $containergroupName).State -eq "Running")
            {
                $status = [HttpStatusCode]::OK
                $body = "$containergroupName already started"
            }
            else
            {
                $returnstatus = Invoke-AzResourceAction -ResourceGroupName $rgName `
                                    -ResourceName $containergroupName `
                                    -Action $action `
                                    -ResourceType Microsoft.ContainerInstance/containerGroups `
                                    -Force
               
                $status = [HttpStatusCode]::OK
                $body = "$containergroupName action $action executed"
            }
         }
    
         "stop" {
            if ((Get-AzContainerGroup -ResourceGroupName $rgName -Name $containergroupName).State -eq "Stopped")
            {
                $status = [HttpStatusCode]::OK
                $body = "$containergroupName already stopped"
            }
            else
            {
                $returnstatus = Invoke-AzResourceAction -ResourceGroupName $rgName `
                                    -ResourceName $containergroupName `
                                    -Action $action `
                                    -ResourceType Microsoft.ContainerInstance/containerGroups `
                                    -Force
    
                $status = [HttpStatusCode]::OK
                $body = "$containergroupName action $action executed"
            }
         }
        Default {
            $status = [HttpStatusCode]::BadRequest
            $body = "Error occured during start/stop of ACI Group"
        }
    }
    
    # Associate values to output bindings by calling 'Push-OutputBinding'.
    Push-OutputBinding -Name Response -Value ([HttpResponseContext]@{
        StatusCode = $status
        Body = $body
    })
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

