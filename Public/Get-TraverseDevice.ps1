function Get-TraverseDevice {
<#
.SYNOPSIS
Retrieves Traverse Devices based on specified criteria.

.DESCRIPTION
This command leverages the Traverse APIs to gather information about devices in Traverse. 
It retrieves all devices visible to the user by default if no parameters are specified.

.PARAMETER Filter
A Standard Regular Expression filter to search for devices in the environment. Using this option will retrieve objects via the Web Services API instead of REST.

The format follows the Traverse Search Parameters format and searches the same properties by default:
http://help.kaseya.com/webhelp/EN/TV/9020000/#17437.htm

Note that if using properties (e.g. 'department:test host') then the search is a logical AND search, as opposed to the default OR

See the Examples section for more information.
.EXAMPLE
Get-TraverseDevice
Get all devices to which this user has visible access

.EXAMPLE
Get-TraverseDevice "host1"
Get devices where name is exactly "host1"

.EXAMPLE
Get-TraverseDevice -DeviceName "host1"
Get devices where name is exactly "host1"

.EXAMPLE
Get-TraverseDevice -DeviceName "host1*"
Get devices where name begins with "host1"

.EXAMPLE
Get-TraverseDevice -DeviceName "host[1-7]"
Use a regex to get devices named host1 through host7 (but not host8 or host9)

.EXAMPLE
Get-TraverseDevice -filter "host1"
Get devices where name contains host1 anywhere in the name (would match: host1, testhost1, t-host14-dev)

.EXAMPLE
Get-TraverseDevice -filter "10.1.2.5"
Get devices with an IP address (or name) of 10.1.2.5

.EXAMPLE
Get-TraverseDevice -filter "^host1"
Get devices where name begins with host1 (would match: host1, host1test)

.EXAMPLE
Get-TraverseDevice -filter "department:Finance"
Get devices in the Finance department

.EXAMPLE
Get-TraverseDevice -filter "department:Finance host1"
Get devices in the Finance department whos name contains host1

.EXAMPLE
Get-TraverseDevice -filter "test:SQL"
Get devices that have at least one test defined with SQL in the name

#>

    [CmdletBinding(DefaultParameterSetName="REST")]

    param (
        #Name of the device you want to retrieve. Regular expressions are supported.
        [Parameter(Position=0,ParameterSetName="REST")][String]$DeviceName = '*',
        #[SUPERUSER ONLY] Restrict scope of search to what the specified user can see
        [Parameter(ParameterSetName="REST")][String]$UserName,
        [Parameter(ParameterSetName="WS")][String]$Filter
    ) # Param

    if ($PSCmdlet.ParameterSetName -eq "REST") {
        $argumentList = @{}
        $argumentList.deviceName = $DeviceName
        if ($Username) {$argumentList.userName = $UserName}

        (Invoke-TraverseCommand device.list $argumentList -Verbose:($PSBoundParameters['Verbose'] -eq $true)).data.object
    } #If ParameterSet REST

    if ($PSCmdlet.ParameterSetName -eq "WS") {

        #Exit if not connected
        if (!$Global:TraverseSession) {write-warning "You are not connected to a Traverse BVE system. Use Connect-TraverseBVE first";return}

        #Connect to the Device Web Service
        $TraverseBVEDeviceWS = (new-webserviceproxy -uri "https://$($TraverseHostname)/api/soap/device?wsdl" -ErrorAction stop)
        $TraverseBVEDeviceNS = $TraverseBVEDeviceWS.gettype().namespace

        #Create device request
        $DeviceRequest = new-object ($TraverseBVEDeviceNS + '.deviceStatusesRequest')
        $DeviceRequest.sessionid = $TraverseSession.result.sessionid

        #If Filter is specified, add a freeform search criteria object
        if ($Filter) {
            $SearchCriteria = new-object ($TraverseBVEDeviceNS + '.searchCriteria')
            $SearchCriteria.searchOption = "FREEFORM"
            $SearchCriteria.searchOptionSpecified = $true
            $SearchCriteria.searchTerms = $Filter
            $DeviceRequest.searchCriterias += $SearchCriteria
        }

        $DeviceResult = $TraverseBVEDeviceWS.getStatuses($DeviceRequest)

        if (!$DeviceResult.success) {throw "The connection failed to $TraverseHostname. Reason: Error $($DeviceResult.errorcode) $($DeviceResult.errormessage)"}
        if ($DeviceResult.errorCodeSpecified) {write-warning "Get-TraverseDevice Search Error: $($DeviceResult.errorMessage)"}

        return $DeviceResult.result.devices

    } #If ParameterSetName WS

} #Get-TraverseDevice


