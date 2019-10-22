using namespace System.Net

# Input bindings are passed in via param block.
param($Request, $TriggerMetadata)

# Write to the Azure Functions log stream.
Write-Host "PowerShell HTTP trigger function processed a request."

# Interact with query parameters or the body of the request.
$action = $Request.Query.Action
$rgName = $Request.Query.RGName

if (-not $rgName -or -not $action)
{
    $rgName = $Request.Body.RGName
    $action = $Request.Body.Action
}

try
{
    $ACIs = Get-AzContainerGroup -ResourceGroupName $rgName

    foreach ($ACI in $ACIs)
    {
        switch ($action) {
            "start" { 
                if ((Get-AzContainerGroup -ResourceGroupName $rgName -Name $ACI.Name).State -eq "Running")
                {
                    $status = [HttpStatusCode]::OK
                    $body = @{status="already started"} | ConvertTo-Json
                }
                else
                {
                    $returnstatus = Invoke-AzResourceAction -ResourceGroupName $rgName `
                                        -ResourceName $ACI.Name `
                                        -Action $action `
                                        -ResourceType Microsoft.ContainerInstance/containerGroups `
                                        -Force
                   
                    $status = [HttpStatusCode]::OK
                    $body = @{status="start successful"} | ConvertTo-Json
                }
             }
        
             "stop" {
                if ((Get-AzContainerGroup -ResourceGroupName $rgName -Name $ACI.Name).State -eq "Stopped")
                {
                    $status = [HttpStatusCode]::OK
                    $body = "$($ACI.Name) already stopped"
                }
                else
                {
                    $returnstatus = Invoke-AzResourceAction -ResourceGroupName $rgName `
                                        -ResourceName $ACI.Name `
                                        -Action $action `
                                        -ResourceType Microsoft.ContainerInstance/containerGroups `
                                        -Force
        
                    $status = [HttpStatusCode]::OK
                    
                    $body = @{status="stop successful"} | ConvertTo-Json
                }
             }
            Default {
                $status = [HttpStatusCode]::BadRequest
                $body = @{status="error"} | ConvertTo-Json
            }
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
    $body = @{status="error";message=$_} | ConvertTo-Json
    $status = [HttpStatusCode]::InternalServerError
    # Associate values to output bindings by calling 'Push-OutputBinding'.
    Push-OutputBinding -Name Response -Value ([HttpResponseContext]@{
        StatusCode = $status
        Body = $body
    })
}

