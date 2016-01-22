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
