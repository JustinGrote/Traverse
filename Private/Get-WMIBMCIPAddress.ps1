function Get-WMIBMCIPAddress {
<#
.SYNOPSIS
Accesses WMI to obtain the BMC IP Address of the device

.NOTES
Based on script by Michael Albert (http://michlstechblog.info/blog/windows-read-the-ip-address-of-a-bmc-board/)

.PARAMETER ComputerName
Name of the Windows Computer to check for a BMC

#>

param (
[Parameter(Mandatory=$true,ValueFromPipeline=$true)][String[]]$ComputerName
)

Begin {
    # Some constants
    # <a title="Microsoft In Band Management" href="http://gallery.technet.microsoft.com/scriptcenter/In-Band-Management-using-88e221b8" target="_blank">Source</a>
    [byte]$BMCResponderAddress = 0x20
    [byte]$GetLANInfoCmd = 0x02
    [byte]$GetChannelInfoCmd = 0x42
    [byte]$SetSystemInfoCmd = 0x58
    [byte]$GetSystemInfoCmd = 0x59
    [byte]$DefaultLUN = 0x00
    [byte]$IPMBProtocolType = 0x01
    [byte]$8023LANMediumType = 0x04
    [byte]$MaxChannel = 0x0b
    [byte]$EncodingAscii = 0x00
    [byte]$MaxSysInfoDataSize = 19
}

Process { 
    foreach ($cn in $ComputerName) {
    write-progress "Connecting to WMI on $cn"

    #Reset Variables
    $oIPMI = $null
    $oRet = $null

    #Get IPMI Instance
        try {
        if ((gwmi -computername $cn "win32_computersystem").manufacturer -match "VMware" ) { write-warning "$cn`:This is a Virtual Machine. Skipping BMC check";continue }
        $oIPMI=Get-WmiObject -Namespace root\WMI -Class MICROSOFT_IPMI -Computername $cn -ErrorAction stop
        }
        catch {
        if ($PSItem.Exception.Message -match "Invalid Class") { write-warning "$cn`: No BMC Found. If this server is Windows 2003, ensure the Hardware Management feature is installed" }
        if ($PSItem.Exception.Message -match "RPC Server Unavailable") {write-warning "$cn`: Could not connect to WMI on this host. Please ensure it is a windows machine and check firewalls"}
        }

    #If for whatever reason an IPMI object is not returned, skip this system and move on
    if (!$oIPMI) {write-warning "$cn`: No IPMI Object Returned. Skipping...";continue}

    #Create Result Info
    $IPMIResult = [ordered]@{}
    $IPMIResult.ComputerName = $cn

    #Get the LAN Channel and IP address if found
    [byte[]]$RequestData=@(0)
    $oMethodParameter=$oIPMI.GetMethodParameters("RequestResponse")
    $oMethodParameter.Command=$GetChannelInfoCmd
    $oMethodParameter.Lun=$DefaultLUN
    $oMethodParameter.NetworkFunction=0x06
    $oMethodParameter.RequestData=$RequestData
    $oMethodParameter.RequestDataSize=$RequestData.length
    $oMethodParameter.ResponderAddress=$BMCResponderAddress
    # http://msdn.microsoft.com/en-us/library/windows/desktop/aa392344%28v=vs.85%29.aspx
    $RequestData=@(0)
    [Int16]$iLanChannel=0
    [bool]$bFoundLAN=$false
    for(;$iLanChannel -le $MaxChannel;$iLanChannel++){
	    $RequestData=@($iLanChannel)
	    $oMethodParameter.RequestData=$RequestData
	    $oMethodParameter.RequestDataSize=$RequestData.length
        try {
        $oRet=$null
	    $oRet=$oIPMI.PSBase.InvokeMethod("RequestResponse",$oMethodParameter,(New-Object System.Management.InvokeMethodOptions))
        }
        catch [Exception] {
        write-warning "$CN`: Error While attempting to find LAN Channels";return
        }
	    #$oRet
	    if($oRet.ResponseData[2] -eq $8023LANMediumType){
		    $bFoundLAN=$true
		    break;
        }
	}

    $oMethodParameter.Command=$GetLANInfoCmd
    $oMethodParameter.NetworkFunction=0x0c

    

    if($bFoundLAN){
	    $RequestData=@($iLanChannel,3,0,0)
	    $oMethodParameter.RequestData=$RequestData
	    $oMethodParameter.RequestDataSize=$RequestData.length
	    $oRet=$oIPMI.PSBase.InvokeMethod("RequestResponse",$oMethodParameter,(New-Object System.Management.InvokeMethodOptions))
	    $IPMIResult.BMCIPAddress = (""+$oRet.ResponseData[2]+"."+$oRet.ResponseData[3]+"."+$oRet.ResponseData[4]+"."+ $oRet.ResponseData[5] )
	    $RequestData=@($iLanChannel,6,0,0)
	    $oMethodParameter.RequestData=$RequestData
	    $oMethodParameter.RequestDataSize=$RequestData.length
	    $oRet=$oIPMI.PSBase.InvokeMethod("RequestResponse",$oMethodParameter,(New-Object System.Management.InvokeMethodOptions))
	    $IPMIResult.BMCSubnetMask = (""+$oRet.ResponseData[2]+"."+$oRet.ResponseData[3]+"."+$oRet.ResponseData[4]+"."+ $oRet.ResponseData[5] )
	    $RequestData=@($iLanChannel,5,0,0)
	    $oMethodParameter.RequestData=$RequestData
	    $oMethodParameter.RequestDataSize=$RequestData.length
	    $oRet=$oIPMI.PSBase.InvokeMethod("RequestResponse",$oMethodParameter,(New-Object System.Management.InvokeMethodOptions))
	    # Format http://msdn.microsoft.com/en-us/library/dwhawy9k.aspx
	    $IPMIResult.BMCMACAddress = ("{0:x2}:{1:x2}:{2:x2}:{3:x2}:{4:x2}:{5:x2}" -f $oRet.ResponseData[2], $oRet.ResponseData[3],$oRet.ResponseData[4], $oRet.ResponseData[5], $oRet.ResponseData[6], $oRet.ResponseData[7])
    } #If
    
    #Output the result
    new-object PSObject -Property $IPMIResult
} #Foreach
} #Process

} #Get-WMIBMCIPAddress