function Invoke-TraverseCommand {
<#
.SYNOPSIS
Executes a command using either the Traverse JSON or REST Interfaces

.DESCRIPTION
This cmdlet executes a Traverse API command and formats the result as a Powershell Custom Object
This cmdlet mostly serves as a wrapper around the APIs to make them easier to use.
Most of the commands in the Traverse module use this command as the foundation to execute their actions.

.NOTES
Modeled after Native Powershell functions Invoke-Command and Invoke-Expression.

.EXAMPLE
(Invoke-TraverseCommand 'device.list').data.object
Run the device.list command, and show only the resulting object output

.EXAMPLE
(Invoke-TraverseCommand 'device.list').data.object
Run the device.list command, and show only the resulting object output


#>

    [CmdletBinding(SupportsShouldProcess,DefaultParameterSetName="SessionID")]
    param (
        #The command you wish to execute
        [Parameter(Mandatory,Position=0)][String]$Command,
        #A list of arguments to pass with the command, as a hashtable, object array, or JSON string. If using FlexAPI, this MUST be a hashtable
        [Parameter(Position=1)]$ArgumentList = @{},
        #Specifies whether this is a REST (FlexAPI) or JSON command. Default is REST (FlexAPI)
        [ValidateSet('REST','JSON')][String]$API = 'REST',
        #NONFUNCTIONAL: The session ID to use. Defaults to the currently connected session
        [Parameter(ParameterSetName="SessionID")][String]$SessionID,
        #NONFUNCTIONAL: Credentials to optionally specify to run this command as another user
        [Parameter(Mandatory,ParameterSetName="Credential")][PSCredential]$Credentials
    ) # Param

    #Determine if we need to refresh the connection based on the timeout interval. Use a 5 second buffer to account for command latency
    if ($TraverseConnectRefreshDate -lt [DateTime]::Now) {
        write-verbose "JSON Refresh Timer Expired. Refreshing Login..."
        connect-traversebve @TraverseConnectParams -Quiet -Force
    }

    #Prep the command parameters based on the API being chosen
    switch ($API) {
        'REST' { 
            $APIPath = '/api/rest/command/' 
            $Method = 'GET'
            
            if ($ArgumentList -isnot [System.Collections.Hashtable]) {throw 'ArgumentList must be specified as a hashtable for REST commands'}
            $ArgumentList.format = "json"

            #Ensure we have a connection
            if (!$Script:TraverseSessionREST) {throw 'You are not connected to a Traverse BVE system with REST. Use Connect-TraverseBVE first'}

            $WebSession = $Script:TraverseSessionREST
        }
        'JSON' { 
            $APIPath = '/api/json/' 
            $Method = 'POST'
            $ArgumentList = ConvertTo-Json -Compress $ArgumentList

            #Ensure we have a connection
            if (!$Script:TraverseSessionJSON) {throw 'You are not connected to a Traverse BVE system with JSON. Use Connect-TraverseBVE first'}

            $WebSession = $Script:TraverseSessionJSON
        }
    }

    $RESTCommand = @{
        URI = $TraverseProtocol + $TraverseHostname + $APIPath + $Command
        Method = $Method
        Body = $ArgumentList
        WebSession = $WebSession
        ContentType = 'application/json'
    }

    if (!($PSCmdlet.ShouldProcess($RESTCommand.URI,"Invoke $API Command"))) {return}
    $commandResult = Invoke-RestMethod @RESTCommand

    #BUGFIX: Work around a bug in ConvertFrom-JSON where it doesn't parse blank entries even if it is valid JSON. Example: {""=""}
    #When this happens Invoke-Restmethod passes it as a string rather than a pscustomobject which is why we test for that
    $nullJSONRegex = [Regex]::Escape(',{"":""}')
    if ($commandResult -is [String] -and $commandResult -match $nullJSONRegex) {
        $commandResult = ConvertFrom-JSON ($commandResult -replace $nullJSONRegex,'')
    }


    #Error Checking and results return are API-dependent
    switch ($API) {
        "REST" {

            if ($commandresult.'api-response'.status.error -eq 'false') {
                write-verbose ('Invoke-TraverseCommand Successful: ' + $commandResult.'api-response'.status.code + ' ' + $commandResult.'api-response'.status.message)
                return $commandResult.'api-response'
            }

            else {
                write-error ($commandResult.'api-response'.status.code + ' ' + $commandResult.'api-response'.status.message)
            }
        } #REST

        "JSON" {
            if ($commandResult.success) {
                write-verbose ('Invoke-TraverseCommand Successful: ' + $commandResult.errorcode + ' ' + $commandResult.errormessage)
                return $commandResult.result
            }
            else {
                write-error ($commandResult.errorcode + ' ' + $commandResult.errormessage)
            }
        } #JSON
    } #Switch
} #Connect-TraverseBVE