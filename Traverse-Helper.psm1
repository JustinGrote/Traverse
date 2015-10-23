#####################################
#####################################
##### IMPORTED HELPER FUNCTIONS #####
#####################################
#####################################
#These are functions brought from other modules or systems to remove dependencies and make this module self-sufficient

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

function Convert-HashTableToXML() {
<#
.SYNOPSIS
COnverts one or more Powershell hashtables into a simple XML format.

.DESCRIPTION
Creates simpler and more human-readable output for a hashtable than Export-CliXML or ConvertTo-XML.
This is useful for instance when storing attributes or configuration variables for output to other 
program or storage in an AD CustomAttribute.

This command will create appropriate subnodes if you have nested hashtables.

.NOTES
Adapted from original script by Blindrood (https://gallery.technet.microsoft.com/scriptcenter/Export-Hashtable-to-xml-in-122fda31)

.PARAMETER InputObject
A Powershell hashtable that contains the name-value pairs you wish to convert to XML elements

.PARAMETER Root
Allows you to specify the root XML element definition.

.PARAMETER OutPath
Path to an output XML file, if desired. If not specified, outputs directly to the pipeline

.EXAMPLE
Create a Hashtable

PS C:\> $Configuration = @{ 
    'Definitions' = @{ 
        'ConnectionString' = 'sql=srv01;port=223' 
        'MonitoringLevel' = 'MonitoringLevelValue' 
    } 
    'Conventions' = @{ 
        'MyConvention' = 'This is my convention' 
        'Option' = 'Zip' 
        'ServerType' = 'sql' 
        'Actions' = @{ 
            'SpecificAction' = 'DoNothing' 
            'DefaultAction' = 'Destroy it All' 
        } 
        'ExceptionAction' = 125 
        'Period' = New-TimeSpan -Seconds 20 
    } 
    'ServiceAccount' = @{ 
        'UserName' = 'mydomain.com\thisisme' 
        'Password' = '123o123' 
    } 
    'GroupConfiguration' = @{ 
        'AdminsGroup' = 'mydomain.com\thisisAdminsGroup' 
        'UsersGroup' = 'mydomain.com\thisisUsersGroup' 
    } 
} 

.EXAMPLE
Export the 
$Configuration | Out-HashTableToXml -Root 'Configuration' -File $env:temp\test.xml

-----------------
Test.XML Contents
-----------------

<Configuration> 
  <Conventions> 
    <ExceptionAction>125</ExceptionAction> 
    <ServerType>sql</ServerType> 
    <Actions> 
      <SpecificAction>DoNothing</SpecificAction> 
      <DefaultAction>Destroy it All</DefaultAction> 
    </Actions> 
    <Period>00:00:20</Period> 
    <Option>Zip</Option> 
    <MyConvention>This is my convention</MyConvention> 
  </Conventions> 
  <GroupConfiguration> 
    <UsersGroup>mydomain.com\thisisUsersGroup</UsersGroup> 
    <AdminsGroup>mydomain.com\thisisAdminsGroup</AdminsGroup> 
  </GroupConfiguration> 
  <Definitions> 
    <MonitoringLevel>MonitoringLevelValue</MonitoringLevel> 
    <ConnectionString>sql=srv01;port=223</ConnectionString> 
  </Definitions> 
  <ServiceAccount> 
    <Password>123o123</Password> 
    <UserName>mydomain.com\thisisme</UserName> 
  </ServiceAccount> 
</Configuration>


#>

Param(
	[Parameter(ValueFromPipeline = $true, Position = 0)]
	[System.Collections.Hashtable]$InputObject,

    [ValidateScript({Test-Path $_ -IsValid})] 
    [System.String]$OutPath,

	[System.String]$Root="PSHashTable"
)

Begin{
	$ScriptBlock = {
		Param($Elem, $Root)
		if( $Elem.Value -is [System.Collections.Hashtable] ){
			$RootNode = $Root.AppendChild($Doc.CreateNode([System.Xml.XmlNodeType]::Element,$Elem.Key,$Null))
			$Elem.Value.GetEnumerator() | ForEach-Object {
				$Scriptblock.Invoke( @($_, $RootNode) )
			}
		}
		else{
			$Element = $Doc.CreateElement($Elem.Key)
			$Element.InnerText = if($Elem.Value -is [Array]) {
				$Elem.Value -join ','
			}
			else{
				$Elem.Value | Out-String
			}
			$Root.AppendChild($Element) | Out-Null	
		}
	}	
} #Begin

Process{
	$Doc = [xml]"<$($Root)></$($Root)>"
	$InputObject.GetEnumerator() | ForEach-Object {
		$scriptblock.Invoke( @($_, $doc.DocumentElement) )
	}
	
    #Output the formatted XML document if OutPath is specified, otherwise send to pipeline
    if ($OutPath) {$doc.save($OutPath)}
    else {$doc}
} #Process

} #Out-HashTableToXML

###########################################
# Function Get-WmiCustom([string]$computername,[string]$namespace,[string]$class,[int]$timeout=15)
# by Daniele Muscetta, MSFT
# originally published at http://www.muscetta.com/2009/05/27/get-wmicustom/
#
# works as a replacement for the Get-WmiObject cmdlet,
# but includes an extra parameter for specifying a client timeout.
#
###########################################
Function Get-WmiCustom([string]$class,[string]$computername = "localhost",[string]$namespace = "root\cimv2",[int]$timeout=15)
{
    $ConnectionOptions = new-object System.Management.ConnectionOptions
    $EnumerationOptions = new-object System.Management.EnumerationOptions 
    
    $timeoutseconds = new-timespan -seconds $timeout
    $EnumerationOptions.set_timeout($timeoutseconds) 
    
    $assembledpath = "\\" + $computername + "\" + $namespace
    #write-host $assembledpath -foregroundcolor yellow 
    
    $Scope = new-object System.Management.ManagementScope $assembledpath, $ConnectionOptions
    $Scope.Connect() 
    
    $querystring = "SELECT * FROM " + $class
    #write-host $querystring 
    
    $query = new-object System.Management.ObjectQuery $querystring
    $searcher = new-object System.Management.ManagementObjectSearcher
    $searcher.set_options($EnumerationOptions)
    $searcher.Query = $querystring
    $searcher.Scope = $Scope 
    
    
    
    return $searcher.get() 
}