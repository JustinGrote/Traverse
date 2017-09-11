function Get-TraverseDeviceExtendedInfo {
<#
.SYNOPSIS
Gets the extended properties store in a device tag and converts them back to usable XML format.

.PARAMETER Tag
The number of the tag where extended properties are stored. Defaults to 5

.PARAMETER Credential
Alternate Credentials to use for connection

.NOTES
Currently uses the deprecated legacy API as no method exists in new API to retrieve tags.
Doesn't support nested XML elements in extended properties. Single level only.
Because these fields are free-form, objects are not strictly typed, and so the Powershell display may not
show all available tags. 
TODO: Add an option flag to wait until all devices are collected, get a list of tags, and output them in a proper format.

#>
    [CmdletBinding()]
    param (
        [PSCredential]$Credential=$TraverseLegacyCredential,
        [int]$Tag = 5
    )

    if (!$TraverseLegacyCredential) {write-warning "You are not connected to a Traverse BVE system. Use Connect-TraverseBVE first";return}

    $Devices = get-TraverseLegacyDevice

    foreach ($Device in ($Devices)) {
        $TagIdentifier = "tag$tag"
        if (!($device.$TagIdentifier)) {
            write-verbose "$($Device.name)`: No Tag Information Found";continue
        }
        #Retrieve the extended info and "rehydrate" it back to XML
        $xmlDeviceExtendedInfo = [xml]$device.$TagIdentifier.replace('{','<').replace('}','>')

        #Convert the XML into a hash table
        $DeviceExtendedInfo = [Ordered]@{}
        $DeviceExtendedInfo.DeviceName = $Device.name
        $DeviceExtendedInfo.DeviceSerial = $Device.SerialNumber
        $xmlDeviceExtendedInfo.DeviceExtendedInfo.ChildNodes | Foreach {$DeviceExtendedInfo[$PSItem.Name] = $PSItem.'#text'}

        #Return the properties
        new-object PSObject -Property $DeviceExtendedInfo
    }

}