function Get-TraverseLegacyDevice {
<#
.SYNOPSIS
Gets Traverse Devices using the legacy API which supports some different properties

.Notes
TODO: Search Criteria
#>
    [CmdletBinding()]
    param (
        [PSCredential]$Credential=$TraverseLegacyCredential
    )

    if (!$TraverseLegacyCredential) {write-warning "You are not connected to a Traverse BVE system. Use Connect-TraverseBVE first";return}

    $wsTraverseBVELegacyDevice = (new-webserviceproxy -uri "https://$TraverseHostname/api/soap/public/device?wsdl" -ErrorAction stop)
    $nsTraverseBVELegacyDevice = $wsTraverseBVELegacyDevice.gettype().namespace

    $ListDevicesRequest = new-object ($nsTraverseBVELegacyDevice + '.ListDevicesRequest')
    $ListDevicesRequest.username = $credential.GetNetworkCredential().username
    $ListDevicesRequest.password = $credential.GetNetworkCredential().password

    $ListDevicesResult = $wsTraverseBVELegacyDevice.listdevices($listdevicesrequest)

    if ($ListDevicesResult.statuscode -ne 0) {
        throw "An Error Occured while retrieving Traverse Devices: $($ListDevicesResult.statusmessage)"
    } else {
        $ListDevicesResult.objectinfo
    }
}
