function Invoke-TraverseCommand {
<#
.SYNOPSIS
Executes a command using either the Traverse JSON or REST Interfaces

.NOTES
Modeled after Native Powershell functions Invoke-Command and Invoke-Expression.

#>

    [CmdletBinding(SupportsShouldProcess,DefaultParameterSetName="SessionID")]
    param (
        #The command you wish to execute
        [Parameter(Mandatory,Position=0)][String]$Command,
        #A list of arguments to pass with the command, as a hashtable, object array, or JSON string. If using FlexAPI, this MUST be a hashtable
        [Parameter(Position=1)]$ArgumentList,
        #Specifies whether this is a REST (FlexAPI) or JSON command. Default is REST (FlexAPI)
        [ValidateSet('REST','JSON')][String]$API = "REST",
        #NONFUNCTIONAL: The session ID to use. Defaults to the currently connected session
        [Parameter(ParameterSetName="SessionID")][String]$SessionID,
        #NONFUNCTIONAL: Credentials to optionally specify to run this command as another user
        [Parameter(Mandatory,ParameterSetName="Credential")][PSCredential]$Credential
    ) # Param

    #Prep the command parameters based on the API being chosen
    switch ($API) {
        'REST' { 
            $APIPath = '/api/rest/command/' 
            $Method = "GET"
            $WebSession = $Global:TraverseSessionREST
            
            if ($ArgumentList -ne $null -and $ArgumentList -isnot [System.Collections.Hashtable]) {throw 'ArgumentList must be specified as a hashtable for REST commands'}
            $ArgumentList.format = "json"

            if (!$Global:TraverseSessionREST) {throw 'You are not connected to a Traverse BVE system with REST. Use Connect-TraverseBVE first'}
        }
        'JSON' { 
            $APIPath = '/api/json/' 
            $Method = "POST"
            $WebSession = $Global:TraverseSessionJSON
            if (!$Global:TraverseSessionJSON) {throw 'You are not connected to a Traverse BVE system with JSON. Use Connect-TraverseBVE first'}
        }
    }

    $RESTCommand = @{
        URI = 'https://' + $TraverseHostname + $APIPath + $Command
        Method = $Method
        Body = $ArgumentList
        WebSession = $WebSession
        ContentType = 'application/json'
    }

    $commandResult = Invoke-RestMethod @RESTCommand

    #BUGFIX: Work around a bug in ConvertFrom-JSON where it doesn't parse blank entries even if it is valid JSON. Example: {""=""}
    #When this happens Invoke-Restmethod passes it as a string rather than a pscustomobject which is why we test for that
    $nullJSONRegex = [Regex]::Escape(',{"":""}')
    if ($commandResult -is [String] -and $commandResult -match $nullJSONRegex) {
        $commandResult = ConvertFrom-JSON ($commandResult -replace $nullJSONRegex,'')
    }

    if ($commandresult.'api-response'.status.error -eq 'false') {
        write-verbose ('Invoke-TraverseCommand Successful: ' + $commandResult.'api-response'.status.code + ' ' + $commandResult.'api-response'.status.message)
        return $commandResult.'api-response'.data.object
    }

    else {
        write-error ('Error getting devices. ' + $commandResult.'api-response'.status.code + ' ' + $commandResult.'api-response'.status.message)
    }

} #Connect-TraverseBVE