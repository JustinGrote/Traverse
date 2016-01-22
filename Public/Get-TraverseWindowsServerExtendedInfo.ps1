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
