#Requires -Version 3

function Connect-TraverseBVE {
<#
.SYNOPSIS
 Connects to a Traverse BVE system with the Web Services API enabled.

.PARAMETER Hostname
The DNS name or IP address of the Traverse BVE system

.PARAMETER Credential
The username and password needed to access the system in secure PSCredential format.

.PARAMETER Force
Create a new session even if one already exists

.PARAMETER NoREST
Skips the connection to the REST API

.PARAMETER NoLegacyWS
Skips the connection to the legacy Web Services API

.PARAMETER RESTSessionPassThru
Pass the REST session object to the pipeline. Useful if you want to work with multiple sessions simultaneously

.PARAMETER WSSessionPassThru
Pass the SOAP session object to the pipeline. Useful if you want to work with multiple sessions simultaneously

#>

param (
    [Parameter(Mandatory=$true)][String]$Hostname,
    [PSCredential]$Credential = (get-credential -message "Enter your Traverse Username and Password"),
    [Switch]$Force,
    [Switch]$NoREST,
    [Switch]$NoLegacyWS,
    [Switch]$RESTSessionPassThru,
    [Switch]$WSSessionPassThru
) # Param

if (!$Hostname) {write-warning "You are already logged into Traverse. Use the -force parameter if you want to connect to a different one or use a different username";return} 
if ($Global:TraverseSession -and !$force) {write-warning "You are already logged into Traverse. Use the -force parameter if you want to connect to a different one or use a different username";return} 

#Workaround for bug with new-webserviceproxy (http://www.sqlmusings.com/2012/02/04/resolving-ssrs-and-powershell-new-webserviceproxy-namespace-issue/)
$TraverseBVELoginWS = (new-webserviceproxy -uri "https://$($hostname)/api/soap/login?wsdl" -ErrorAction stop)
$TraverseBVELoginNS = $TraverseBVELoginWS.gettype().namespace

#Create the login request and unpack the password from the encrypted credentials
$loginRequest = new-object ($TraverseBVELoginNS + '.loginRequest')
$loginRequest.username = $credential.GetNetworkCredential().Username
$loginRequest.password = $credential.GetNetworkCredential().Password

$loginResult = $TraverseBVELoginWS.login($loginRequest)

if (!$loginResult.success) {throw "The connection failed to $Hostname. Reason: Error $($loginresult.errorcode) $($loginresult.errormessage)"}

set-variable -name TraverseSession -value $loginresult -scope Global
set-variable -name TraverseHostname -value $hostname -scope Global
write-host -foreground green "Connected to $hostname BVE as $($loginrequest.username) using Web Services API"
#Return the session if switch is set
if ($WSSessionPassTHru) {$LoginResult}

#Create a REST Session
if (!$NoREST) {
    #Check for existing session
    if ($Global:TraverseSessionREST -and !$force) {write-warning "You are already logged into Traverse (REST). Use the -force parrameter if you want to connect to a different one or use a different username";return}

    #Log in using Credentials
    $RESTLoginURI = "https://$Hostname/api/rest/command/login?" + $Credential.GetNetworkCredential().UserName + "/" + $Credential.GetNetworkCredential().Password
    $RESTLoginResult = Invoke-RestMethod -sessionvariable TraverseSessionREST -Uri $RESTLoginURI
    if ($RESTLoginResult -notmatch "OK") {throw "The connection failed to $Hostname. Reason: $RESTLoginResult"}
    $Global:TraverseSessionREST = $TraverseSessionREST
    write-host -foreground green "Connected to $Hostname BVE as $($Credential.GetNetworkCredential().Username) using REST API"
    #Return The session if switch is set
    if ($RESTSessionPassThru) {$TraverseSessionREST}
}

#Create a Legacy WS Session
if (!$NoLegacyWS) {
    
    <# I couldn't get this to work correctly so instead just saving the credentials to use for individual commands. Leaving this here for future debugging.

    #Workaround for bug with new-webserviceproxy (http://www.sqlmusings.com/2012/02/04/resolving-ssrs-and-powershell-new-webserviceproxy-namespace-issue/)
    $TraverseBVELegacyLoginWS = (new-webserviceproxy -uri "https://$($hostname)/api/soap/public/sessionManager?wsdl" -ErrorAction stop)
    $TraverseBVELegacyLoginNS = $TraverseBVELegacyLoginWS.gettype().namespace

    #Create the login request and unpack the password from the encrypted credentials
    $sessionManager = new-object ($TraverseBVELegacyLoginNS + '.sessionManager')
    $loginRequest = new-object ($TraverseBVELegacyLoginNS + '.loginRequest')
    $loginRequest.username = $credential.GetNetworkCredential().Username
    $loginRequest.password = $credential.GetNetworkCredential().Password

    $loginResult = $sessionManager.login($loginRequest)

    if ($loginResult.statusmessage -match "error") {throw "The connection failed to $Hostname. Reason: $($loginResult.statusmessage)"}
    set-variable -name TraverseSession -value $loginresult -scope Global
    set-variable -name TraverseHostname -value $hostname -scope Global
    write-host "Connected to $hostname BVE as $($loginrequest.username) using SOAP API"
    #Return The session if switch is set
    if ($WSSessionPassThru) {$LoginResult}
    #>
    
    set-variable -scope Global -name "TraverseLegacyCredential" -value $credential
}

} #Connect-TraverseBVE


function Get-TraverseDevice {
<#
.SYNOPSIS
Gets all listed Traverse devices.

.Parameter Filter
A Standard Regular Expression filter to search for devices in the environment. See the Traverse Documentation for details.


#TODO: Add additional SearchCriteria
#>

param (
    [string]$Filter
) # Param

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

return $DeviceResult.result.devices
} #Get-TraverseDevice

workflow Get-TraverseWindowsServerExtendedInfo {
<#
.SYNOPSIS
Gets extended information about a Traverse Windows Device such as BMC and Serial Number, and adds an ExtendedInfo property to the device object

.PARAMETER TraverseDeviceObject
One or more Traverse Device Objects obtained via Get-TraverseDevice

.PARAMETER ThrottleLimit
How many devices to process concurrently if multiple devices are specified. Default is 5

.PARAMETER GetHPInfo
If enabled, system will try additional techniques to get HP iLO BMC information. Requires the HPILOStatus module and PSExec from Sysinternals to be present in the path.

#>

param(
$TraverseDeviceObject,
[int]$ThrottleLimit = 5
)

foreach -parallel -throttle $ThrottleLimit  ($device in $TraverseDeviceObject) {
    inlineScript{
        $device = $USING:Device
        $deviceAddress = $device.deviceaddress
        #Construct the result hashtable
        $InfoResult = @{}
        
        #Get the system Hostname, Make, Model, and Serial Number Information
        write-progress -Activity "Get Traverse Windows Extended Info" -CurrentOperation "$($devices.DeviceName): Querying WMI Information"
        $deviceComputerSystemInfo = Get-WMICustom win32_computersystem -computername $deviceAddress -erroraction stop
        $deviceBIOSInfo = Get-WMICustom Win32_bios -computername $deviceAddress -erroraction stop
        if ($deviceComputerSystemInfo -and $deviceBIOSInfo) {
            if ($deviceComputerSystemInfo.model -match "Virtual") {
                $infoResult.isVirtual = $true
            }
            else {
                $infoResult.Manufacturer = $deviceComputerSystemInfo.Manufacturer.Trim()
                $infoResult.Model = $deviceComputerSystemInfo.Model.Trim()
                $infoResult.SerialNumber = $deviceBIOSInfo.SerialNumber.Trim()
                $infoResult.isVirtual = $false
            } #Else
        } #If

        #Get BMC IP Information
        $BMCResult = get-wmibmcipaddress $deviceAddress
        if ($BMCResult) {$InfoResult.BMCIPAddress = $BMCResult.BMCIPAddress}

        #If this is an HP server and PSEXEC is in the path, try the legacy HPONCFG command, write the config to a file, and extract the IP from the XML
        elseif (($inforesult.manufacturer -match "HP" -or $inforesult.manufacturer -match "Hewlett") -and (get-command psexec -erroraction silentlycontinue)) {
            write-progress -Activity "Get Traverse Windows Extended Info" -CurrentOperation "$($devices.DeviceName): No BMC Found but device is HP. Trying HPONCFG method."
            $PSExecResult = & {psexec \\$deviceaddress "C:\Program Files\HP\hponcfg\hponcfg.exe" /w "C:\Windows\Temp\hpilo.cfg"} 2>$psExecStdError
            if ($PSExecResult -match "successfully written") {
                $BMCIPAddress = ([xml](get-content "\\$deviceaddress\C$\windows\temp\hpilo.cfg")).ribcl.login.rib_info.mod_network_settings.IP_ADDRESS.VALUE
                if ($BMCIPAddress) {$InfoResult.BMCIPAddress = $BMCIPAddress}
            } #IF
            
        } #ElseIf

        #Attach the Extended Attribute to the device and return it
        $device | Add-Member -Name "extendedInfo" -MemberType NoteProperty -Value $InfoResult -force
        return $device
    } #InlineScript
} #Foreach -Parallel
} #Get-TraverseExtendedInfo

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
Set the description for all devices to "this is a test" (remove the -whatif to do it for real)

PS C:\> Get-TraverseDevice | Set-TraverseDevice -Comment 

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

function get-TraverseDeviceExtendedInfo {
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

function get-TraverseLegacyDevice {
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


function Update-TraverseWindowsExtendedInfo {

<#
.SYNOPSIS
Queries Customer Windows Servers and updates their Traverse Extended Info (stored in Tag5)

.PARAM TraverseAccountName
Name of the customer account to update. The computer system must have network access to the systems to be updated. Must match exactly for safety

.NOTES
THIS ASSUMES LOGGED IN USER HAS RIGHTS TO THE TARGET SYSTEM. TODO: Allow for alternate credentials
TODO: Add full device search criteria

.EXAMPLE
Update all Systems for Customer "Contoso Corp"
PS C:\> Update-TraverseWindowsExtendedInfo -TraverseAccountName "Contoso Corp"
#>

    [CmdletBinding(SupportsShouldProcess)]
    param (
        [Parameter(ParameterSetName="ByDevice",ValueFromPipeline,ValueFromPipelineByPropertyName)][String]$DeviceName,
        [Parameter(ParameterSetName="ByAccountName")][String]$TraverseAccountName,
        $credential = $seasonsCredential
    )
    if ($TraverseAccountName) {
        $devices = Get-TraverseDevice | where {$_.accountname -eq $TraverseAccountName}
    } else {
        $devices = $DeviceName
    }
    $windevices = $devices | where {$PSItem.devicetypestr -match "Windows Server"}

    $resultExtendedInfo = get-TraverseWindowsServerExtendedInfo $windevices

    foreach ($result in $resultExtendedInfo) {
        if ($result.extendedInfo) {
            $xmlExtendedInfo = ($result.extendedinfo | convert-hashtabletoxml -root DeviceExtendedInfo).OuterXML.replace("`n","")
            set-traversedevice $result -Tag5 $xmlExtendedInfo
        }
    }

}


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
        if (!$Global:TraverseSessionREST) {write-warning "You are not connected to a Traverse BVE system via REST. Use Connect-TraverseBVE first";return}
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