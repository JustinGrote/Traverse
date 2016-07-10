function New-TraverseDevice {
    <#
    .SYNOPSIS
    Creates a new Traverse Device using the REST API

    .NOTES
    No Web Services API was present to create a device that I could find as of version 8.0

    .PARAM DeviceName
    Name of the device as displayed in the console. The DNS name for this device will automatically be used unless DNSHostName or IPAddress is also specified.

    .PARAM Location
    The Site Location of the device you wish to create. This is usually tied to a DGE. A list of locations can be found using https://<servername>/api/rest/command/location.list or looking at the "Provisioned Location" attribute of another device. If not specified, will default to "Default Location"

    .PARAM DNSHostName
    DNS Hostname or IP address of the device, if different from its DeviceName

    .PARAM SNMPCommunity
    The SNMP Community Name to use when polling the device. If you do not specify, "public" will be used.

    .PARAM DeviceType
    Type of Device in Traverse (mostly informational). If you do not specify, "unknown" will be used.

    #>

    [CmdletBinding(SupportsShouldProcess)]
    param(
        [Alias("TraverseDeviceName","DeviceName")][Parameter (Mandatory,ValueFromPipeline,ValueFromPipelineByPropertyName)]$Name,

        [Alias("DeviceLocation","TraverseDeviceLocation")][Parameter(Mandatory,ValueFromPipelineByPropertyName)][String]$Location = "Default Location",

        [Alias("DeviceType","TraverseDeviceType")][ValidateSet("nt","windows","unix","linux","solaris","switch","bridge","router","firewall","slb","proxy","vpn","vpnc","printer","wireless","other","unknown","generic","storage","san","nas","vmware","xen","hyperv")]`
            [String]$Type = "unknown",


        [Alias("IPAddress")][Parameter(ValueFromPipelineByPropertyName)][String]$DNSHostName,

        [Alias("Comment")][Parameter(ValueFromPipelineByPropertyName)][String]$Description,

        [String]$SNMPCommunity = "public",

        [Switch]$SmartNotify,

        [Switch]$ShowOnSummary,

        [Switch]$ClearOnOK
    )

    begin {
        if (!$Script:TraverseSessionREST) {write-warning "You are not connected to a Traverse BVE system via REST. Use Connect-TraverseBVE first";return}
    }


    process {
        foreach ($Device in $Name) {
            #Collect the parameters as a hashtable for easy passing to Invoke-RESTMethod, replacing spaces with %20 where appropriate to avoid them being coverted to "+" instead
            $newDeviceParams = [ordered]@{}
            $newDeviceParams.deviceName = $Device.replace(' ','_')
            $newDeviceParams.deviceType = $Type
            if ($DNSHostname) {$newDeviceParams.address = $DNSHostName} else {$newDeviceParams.address = $Device}
            $newDeviceParams.locationName = $Location
            $newDeviceParams.comment = $Description.replace(' ','_')
            $newDeviceParams.snmpcid = $SNMPCommunity
            $newDeviceParams.smartnotify = $SmartNotify
            $newDeviceParams.showonsummary = $ShowOnSummary
            $newDeviceParams.clearonok = $ClearOnOK


            if ($PSCmdlet.ShouldProcess("$TraverseHostname","Create Traverse Device $Device in $Location")) {
                $uriNewDevice = "https://$TraverseHostname/api/rest/command/devices.create"
                $resultNewDevice = Invoke-RestMethod -WebSession $TraverseSessionREST -uri $uriNewDevice -body $newDeviceParams

                if (!$resultNewDevice) {$resultNewDevice = "Error: No Response from Traverse BVE"}

                if ($resultNewDevice -notlike "OK*") {write-error "$resultNewDevice" -category InvalidOperation}
                else {
                    #Return a Result Object
                    $resultNewDeviceProperty = [ordered]@{}
                    $resultNewDeviceProperty.TraverseDeviceName=$Device
                    $resultNewDeviceProperty.TraverseDeviceLocation=$Location
                    $resultNewDeviceProperty.Result=$ResultNewDevice
                    new-object PSObject -property $resultNewDeviceProperty
                }
            }#If
        }#Foreach
    }#Process
}#New-TraverseDevice
