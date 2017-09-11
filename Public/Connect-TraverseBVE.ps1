function Connect-TraverseBVE {
<#
.SYNOPSIS
 Connects to a Traverse BVE system in order to execute commands on the system.

.NOTES
 You should only use Connect-TraverseBVE once per powershell session.
#>

param (
    #The DNS name or IP address of the Traverse BVE system
    [Parameter(Mandatory=$true)][String]$Hostname,
    #The username and password needed to access the system in secure PSCredential format.
    [Parameter(Mandatory=$true)][PSCredential]$Credential,
    #Create a new session even if one already exists
    [Switch]$Force,
    #Do not show connection success information
    [Switch]$Quiet,
    #Connect without using SSL. NOT RECOMMENDED
    [Switch]$NoSSL,
    #Skips the connection to the REST API (BVE FlexAPI)
    [Switch]$NoREST,
    #Skip the connection to the JSON API
    [Switch]$NoJSON,
    #Pass the REST session object to the pipeline. Useful if you want to work with multiple sessions simultaneously
    [Switch]$PassThruREST,
    #Pass the JSON session object to the pipeline. Useful if you want to work with multiple sessions simultaneously
    [Switch]$PassThruJSON
) # Param

#Specify the connectivity protocol and hostname
if ($NoSSL) {$SCRIPT:TraverseProtocol = "http://"} else {$SCRIPT:TraverseProtocol = "https://"}
set-variable -name TraverseHostname -value $hostname -scope Script

#Create a REST Session
if (!$NoREST) {
    #Check for existing session
    if ($TraverseSessionREST -and !$force) {
        write-warning "You are already logged into Traverse (REST). Use the -force parameter if you want to connect to a different server or use a different username"
        return
    }

    #Log in using Credentials
    $RESTLoginURI = "$TraverseProtocol$Hostname/api/rest/command/login?" + $Credential.GetNetworkCredential().UserName +
        "/" + $Credential.GetNetworkCredential().Password

    $RESTLoginResult = Invoke-RestMethod -sessionvariable TraverseSessionREST -Uri $RESTLoginURI
    if ($RESTLoginResult -notmatch "OK") {throw "The connection failed to $Hostname. Reason: $RESTLoginResult"}

    #Workaround for SessionVariable parameter not allowing you to specify the scope
    #We need this to persist throughout the module lifetime
    $SCRIPT:TraverseSessionREST = $TraverseSessionREST

    if (!$Quiet) {
        write-verbose "Connected to $Hostname BVE as $($Credential.GetNetworkCredential().Username) using REST API"
    }

    #Return the login session if switch is set
    if ($PassThruREST) {$TraverseSessionREST}

} #if !$NoREST

#Create a JSON Session
if (!$NoJSON) {
    #Check for existing session
    if ($TraverseSessionJSON -and !$force) {
        write-warning "You are already logged into Traverse (JSON). Use the -force parameter if you want to connect to a different server or use a different username"
        return
    }

    #Log in using Credentials
    $JSONAPIPath = '/api/json/'
    $JSONCommandName = 'login/login'
    $JSONCommandURI = $TraverseProtocol + $Hostname + $JSONAPIPath + $JSONCommandName
    $JSONBody = @{
        username=$Credential.GetNetworkCredential().UserName
        password=$Credential.GetNetworkCredential().Password
    }

    $JSONRestMethodParams = @{
        Method = "POST"
        ContentType = 'application/json'
        URI = $JSONCommandURI
        Body = (ConvertTo-Json -compress $JSONBody)
        SessionVariable = "TraverseSessionJSON"
    }

    $SCRIPT:JSONLoginResult = Invoke-RestMethod @JSONRestMethodParams

    if ($JSONLoginResult.success -ne "True") {
        throw "The connection failed to $Hostname. Reason: " + $JSONLoginResult.errorCode + ": " +
            $JSONLoginResult.errorMessage}

    #Workaround for SessionVariable parameter not allowing you to specify the scope
    #We need this to persist throughout the module lifetime
    $SCRIPT:TraverseSessionJSON = $TraverseSessionJSON

    if (!$Quiet) {
        write-verbose "Connected to $Hostname BVE as $($Credential.GetNetworkCredential().Username) using JSON API"
    }

    #Return the login result if switch is set
    if ($PassThruJSON) {$JSONLoginResult}

} # if !$NoJSON

#Set the Refresh Interval which Invoke-TraverseCommand will use to determine reconnect
#TODO: Make this deterministic per-protocol. For now it refreshes everything
#It also introduces a condition where multiple independent connects don't work.
if ($JSONLoginResult) {
    $SCRIPT:TraverseConnectRefreshDate = [DateTime]::Now.AddMinutes($JSONLoginResult.result.refreshInterval).addminutes(-5)
}
else {
    $SCRIPT:TraverseConnectRefreshDate = [DateTime]::Now.AddMinutes(180).AddMinutes(-5)
}
$SCRIPT:TraverseConnectParams = $PSBoundParameters

} #Connect-TraverseBVE