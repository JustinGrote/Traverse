
<#
.Synopsis
Takes either a traverse status integer or string and converts it back-and-forth.
#>
function Convert-TraverseStatus {
    [CmdletBinding(DefaultParameterSetName="StringToInt")]
    param (
        [Parameter(Mandatory,ParameterSetName="IntToString")][Int]$StatusNumber,
        [Parameter(Mandatory,ParameterSetName="StringToInt")]
            [String]$Status
    )

    begin {
        #TODO: Abstract to JSON file
        $traverseDeviceStateDefinitions = @{
            128 = "Suspended"
            2048 = "OK"
            32768 = "Unknown"
            524288 = "Unreachable"
            8388608 = "Warning"
            134217728 = "Critical"
        }


    }
    process {
        if ($PSCmdlet.ParameterSetName -match "IntToString") {
            $traverseDeviceStateDefinitions[$statusNumber]
        }
        if ($PSCmdlet.ParameterSetName -match "StringToInt") {
            ($traverseDeviceStateDefinitions.getEnumerator() | where {$_.value -match $status}).name
        }
    } #Process
} #Convert-TraverseStatus