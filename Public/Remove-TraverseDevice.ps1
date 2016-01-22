
function Remove-TraverseDevice {
    <#
    .SYNOPSIS
    Deletes a Traverse Device

    .PARAM DeviceName
    Name of the Device. May use Regex to select multiple devices

    #>

    [CmdletBinding(SupportsShouldProcess,ConfirmImpact="High")]
    param(
        [Alias("Name","DeviceName")][Parameter (Mandatory,ValueFromPipeline,ValueFromPipelineByPropertyName)][String]$TraverseDeviceName
    )

    begin {
        if (!$Global:TraverseSessionREST) {write-warning "You are not connected to a Traverse BVE system via REST. Use Connect-TraverseBVE first";return}
    }


    process {
        foreach ($Device in $TraverseDeviceName) {
            #Collect the parameters as a hashtable for easy passing to Invoke-RESTMethod
            $removeDeviceParams = [ordered]@{}
            $removeDeviceParams.deviceName = $Device


            if ($PSCmdlet.ShouldProcess("$TraverseHostname","Removing Traverse Device $Device")) {
                $uriRemoveDevice = "https://$TraverseHostname/api/rest/command/devices.delete"
                $resultRemoveDevice = Invoke-RestMethod -WebSession $TraverseSessionREST -uri $uriRemoveDevice -body $removeDeviceParams

                if (!$resultRemoveDevice) {$resultRemoveDevice = "Error: No Response from Traverse BVE"}

                if ($resultRemoveDevice -notlike "OK*") {write-error "$resultRemoveDevice" -category InvalidOperation}
                else {
                    #Return a Result Object
                    $resultRemoveDeviceProperty = [ordered]@{}
                    $resultRemoveDeviceProperty.TraverseDeviceName=$Device
                    $resultRemoveDeviceProperty.Result=$ResultRemoveDevice
                    new-object PSObject -property $resultRemoveDeviceProperty
                }
            }#If
        }#Foreach
    }#Process
}#Remove-TraverseDevice