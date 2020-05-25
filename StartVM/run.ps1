using namespace System.Net

# Input bindings are passed in via param block.
param($Request, $TriggerMetadata)

# Write to the Azure Functions log stream.
Write-Host "**PowerShell HTTP trigger function processed a request.**"

# Stop on error
$ErrorActionPreference = 'stop'

# Interact with query parameters or the body of the request.
#ToDo Add verification for all parameters
$subscriptionId = $Request.Query.SubscriptionId
Write-Host "Request Query SubscriptionId: $subscriptionId"

$ResourceGroup = $Request.Query.ResourceGroup
Write-Host "Request Query ResourceGroup: $ResourceGroup"

$VMName = $Request.Query.VMName
Write-Host "Request Query VMName: $VMName"



if (-not $VMname) {
    $VMname = $Request.Body.Name
    Write-Host "Request Body Name: $VMname"
}

if ($VMname) {

    #Main Function Code

    # Check if managed identity has been enabled and granted access to a subscription, resource group, or resource
    $AzContext = Get-AzContext -ErrorAction SilentlyContinue
    if (-not $AzContext.Subscription.Id)
    {
       Throw ("Managed identity is not enabled for this app or it has not been granted access to any Azure resources. Please see https://docs.microsoft.com/en-us/azure/app-service/overview-managed-identity for additional details.")
    }

    #Comment In to debug powershell script.  Only for use with local development.
    #Wait-Debugger

    #Verify if in correct subscription, and switch if not
    #ToDo Is there a better way to do this?  e.g. using a URI to specify VM?
    if (-NOT ($AzContext.Subscription.Id -match $subscriptionId)) {

        write-host "Current subscription does not match target subscription.  Switching subscription...."
        try {
            Set-AzContext -Subscription $subscriptionId -ErrorAction SilentlyContinue
        }
        catch {
            write-host $_.Exception.Message
            $status = [HttpStatusCode]::InternalServerError
            $body = "Unable to switch to specified subscription.  Check the Function Managed Identity has access to this subscription."
        }

        $AzContext = Get-AzContext -ErrorAction SilentlyContinue
    }else {
        write-host "Current subscription matches target subscription"
    }


    try 
    {

        #ToDo Catch Resource not found error
        #ToDo Handle Permission denied to resource (same as Resource not found?)
        #ToDo Catch error if VM already running
        $vm = Start-AzVM -ResourceGroupName $ResourceGroup -Name $VMname -NoWait -ErrorAction SilentlyContinue

        #FUNCTION RETURN
        $status = [HttpStatusCode]::OK
        $body = "VM Start Initiated.  Wait a few minutes then check VM Status to confirm running."
    }
    catch
    {
        write-host $_.Exception.Message

        #FUNCTION RETURN
        #InternalServerError
        $status = [HttpStatusCode]::InternalServerError
        $body = "An Exception error occurred, check functions log for error"
    }


}
else {
    $status = [HttpStatusCode]::BadRequest
    $body = "Please pass a name on the query string or in the request body."
}

# Associate values to output bindings by calling 'Push-OutputBinding'.
Push-OutputBinding -Name Response -Value ([HttpResponseContext]@{
    StatusCode = $status
    Body = $body
})
