function Set-TraverseDevice {
<#
.SYNOPSIS
Update the configuration of a device. Currently this only supports some basic descriptive information.

.NOTES
This is a wrapper around the Device.Update FlexAPI command http://help.kaseya.com/webhelp/EN/tv/7000000/dev/index.asp#30181.htm
Supports Common Parameters -Whatif and -Confirm

.PARAMETER TraverseDevice
A Traverse Device, represented as a Traverse deviceStatus object.

.PARAMETER NewDeviceName
Rename a device. THIS IS DANGEROUS IF USED ON THE PIPELINE AND YOU CAN ACCIDENTALLY SET A LOT OF DEVICES TO THE SAME NAME. Please be careful with this parameter

.EXAMPLE
PS C:\> Get-TraverseDevice | Set-TraverseDevice -Comment 
Set the description for all devices to "this is a test" (remove the -whatif to do it for real)

#>

[CmdletBinding(SupportsShouldProcess)]  

param (
    [Parameter(Mandatory=$true,ValueFromPipeline=$true)]$TraverseDevice,
    [Alias("Description")][String]$Comment,
    [String]$Tag5,
    [String]$NewDeviceName
)

begin {
    if (!$Global:TraverseSessionREST) {write-warning "You are not connected to a Traverse BVE system via REST. Use Connect-TraverseBVE first";return}
    
    #Populate the update information based on what was provided
    $setDeviceParams = [ordered]@{}
    if ($Comment) {$setDeviceParams.Comment = $Comment.trim()}
    if ($NewDeviceName) {$setDeviceParams.DeviceName = $newDeviceName.trim()}

    #Tag5 might store extended properties as XML. If so, replace XML brackets with benign character so that it is not flagged by API
    if ($Tag5) {
        #Strip out any curly brackets and carriage returns. Not allowed for extended properties anyways
        $Tag5 = $Tag5.replace("`r",'').replace("`n",'').replace("`{",'').replace("`}",'').trim()
        #Tag5 might store extended properties as XML. If so, replace XML brackets with benign curly brackets so that it is not flagged by API
        $setDeviceParams.Tag5 = $Tag5.replace('<','{').replace('>','}')
    }


    #Exit if nothing was specified
    if ($setDeviceParams.count -eq 0) {throw "No parameters for the device has been specified to be set. Use the arguments to add information to set on the device. See the help for examples."}
}
process {
    foreach ($Device in $TraverseDevice) {
        $setDeviceParams.DeviceSerial = $Device.serialnumber

        if ($PSCmdlet.ShouldProcess("$($Device.devicename) `($($Device.serialnumber)`)","Setting Traverse Device Properties")) {
            $uriSetDevice = "https://$TraverseHostname/api/rest/command/devices.update"
            $resultSetDevice = invoke-restmethod -WebSession $TraverseSessionREST -uri $uriSetDevice -body $setDeviceParams

            if (!$resultSetDevice) {$resultSetDevice = "Error: No Response from Traverse BVE"}

            #Return a Result Object
            $resultSetDeviceProperty = [ordered]@{}
            $resultSetDeviceProperty.TraverseDeviceName=$TraverseDevice.DeviceName
            $resultSetDeviceProperty.TraverseDeviceSerial=$setDeviceParams.DeviceSerial
            $resultSetDeviceProperty.Result=$ResultSetDevice
            new-object PSObject -property $resultSetDeviceProperty
        }#If
    }#Foreach
}

}