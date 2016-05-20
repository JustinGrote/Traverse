function Invoke-TraverseBVE {
<#
.SYNOPSIS
Executes a command using the BVE FlexAPI REST Interface

.NOTES
Modeled after Native Powershell functions Invoke-Command and Invoke-Expression.

#>

    [CmdletBinding(SupportsShouldProcess)]
    param (
        #The FlexAPI command you wish to execute
        [Parameter(Mandatory)][String]$Command,
        #
        [Object[]]$ArgumentList
    ) # Param

    $FlexAPIPath = '/api/rest/command/'

    #Exit if not connected
    if (!$Global:TraverseSessionREST) {write-warning 'You are not connected to a Traverse BVE system. Use Connect-TraverseBVE first';return}

    $RESTCommand = @{
        URI = 'https://' + $TraverseHostname + $FlexAPIPath + $FlexCommand + "?format=json&devicename=$deviceName"
        WebSession = $TraverseSessionREST
        Method = 'GET'
        ContentType = 'application/json'
    }

    $deviceResult = Invoke-RestMethod @RESTCommand

    #BUGFIX: Work around a bug in ConvertFrom-JSON where it doesn't parse blank entries even if it is valid JSON. Example: {""=""}
    $nullJSONRegex = [Regex]::Escape(',{"":""}')
    if ($deviceResult -is [String] -and $deviceResult -match $nullJSONRegex) {
        $deviceResult = ConvertFrom-JSON ($deviceResult -replace $nullJSONRegex,'')
    }

    if ($deviceresult.'api-response'.status.error -eq 'false') {
        write-verbose ('Get-TraverseDevice Successful: ' + $deviceresult.'api-response'.status.code + ' ' + $deviceresult.'api-response'.status.message)
        return $deviceresult.'api-response'.data.object
    }

    else {
        write-error ('Error getting devices. ' + $deviceresult.'api-response'.status.code + ' ' + $deviceresult.'api-response'.status.message)
    }

} #Connect-TraverseBVE
