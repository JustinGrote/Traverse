function Connect-TraverseBVE {
<#
.SYNOPSIS
 Connects to a Traverse BVE system with the Web Services API enabled.
#>

param (
    #The DNS name or IP address of the Traverse BVE system
    [Parameter(Mandatory=$true)][String]$Hostname,
    #The username and password needed to access the system in secure PSCredential format.
    [PSCredential]$Credential = (get-credential -message "Enter your Traverse Username and Password"),
    #Create a new session even if one already exists
    [Switch]$Force,
    #Do not show connection success information
    [Switch]$Quiet,
    #Connect without using SSL. NOT RECOMMENDED
    [Switch]$NoSSL,
    #Skips the connection to the REST API
    [Switch]$NoREST,
    #Skip the connection to the JSON API
    [Switch]$NoJSON,
    #Skip the connection to the Web Services API
    [Switch]$NoWS,
    #Skips the connection to the legacy Web Services API
    [Switch]$NoLegacyWS,
    #Pass the REST session object to the pipeline. Useful if you want to work with multiple sessions simultaneously
    [Switch]$RESTSessionPassThru,
    #Pass the JSON session object to the pipeline. Useful if you want to work with multiple sessions simultaneously
    [Switch]$JSONSessionPassThru,
    #Pass the SOAP session object to the pipeline. Useful if you want to work with multiple sessions simultaneously
    [Switch]$WSSessionPassThru
) # Param


#Specify the connectivity protocol
if ($NoSSL) {$Global:TraverseProtocol = "http://"} else {$Global:TraverseProtocol = "https://"}

#Create a REST Session
if (!$NoREST) {
    #Check for existing session
    if ($Global:TraverseSessionREST -and !$force) {write-warning "You are already logged into Traverse (REST). Use the -force parameter if you want to connect to a different one or use a different username";return}

    #Log in using Credentials
    $RESTLoginURI = "$TraverseProtocol$Hostname/api/rest/command/login?" + $Credential.GetNetworkCredential().UserName + "/" + $Credential.GetNetworkCredential().Password
    $RESTLoginResult = Invoke-RestMethod -sessionvariable TraverseSessionREST -Uri $RESTLoginURI
    if ($RESTLoginResult -notmatch "OK") {throw "The connection failed to $Hostname. Reason: $RESTLoginResult"}
    $Global:TraverseSessionREST = $TraverseSessionREST
    if (!$Quiet) {
        write-host -foreground green "Connected to $Hostname BVE as $($Credential.GetNetworkCredential().Username) using REST API"
    }

    #Return The session if switch is set
    if ($RESTSessionPassThru) {$TraverseSessionREST}

    $GLOBAL:TraverseLastCommandTimeREST = [DateTime]::Now

} #if !$NoREST

#Create a JSON Session
if (!$NoJSON) {
    #Check for existing session
    if ($Global:TraverseSessionJSON -and !$force) {write-warning "You are already logged into Traverse (JSON). Use the -force parameter if you want to connect to a different one or use a different username";return}

    #Log in using Credentials
    $JSONAPIPath = '/api/json/'
    $JSONCommandName = 'login/login'
    $JSONCommandURI = $TraverseProtocol + $Hostname + $JSONAPIPath + $JSONCommandName

    $JSONBody = @{
        username=$Credential.GetNetworkCredential().UserName
        password=$Credential.GetNetworkCredential().Password
    }

    $JSONLoginResult = Invoke-RestMethod -Method POST -Uri $JSONCommandURI -Body (ConvertTo-Json -compress $JSONBody) -ContentType 'application/json' -SessionVariable TraverseSessionJSON
    if ($JSONLoginResult.success -notmatch "True") {throw "The connection failed to $Hostname. Reason: " + $JSONLoginResult.errorCode + ": " + $JSONLoginResult.errorMessage}
    $Global:TraverseSessionJSON = $TraverseSessionJSON
    
    if (!$Quiet) {
        write-host -foreground green "Connected to $Hostname BVE as $($Credential.GetNetworkCredential().Username) using JSON API"
    }
    $GLOBAL:TraverseLastCommandTimeJSON = [DateTime]::Now

} # if !$NoJSON

#Create Web Services (SOAP) connection
if (!$NoWS) {
    if ($Global:TraverseSession -and !$force) {write-warning "You are already logged into Traverse (WS). Use the -force parameter if you want to connect to a different one or use a different username";return} 

    #Workaround for bug with new-webserviceproxy (http://www.sqlmusings.com/2012/02/04/resolving-ssrs-and-powershell-new-webserviceproxy-namespace-issue/)
    $TraverseBVELoginWS = (new-webserviceproxy -uri "$TraverseProtocol$Hostname/api/soap/login?wsdl" -ErrorAction stop)
    $TraverseBVELoginNS = $TraverseBVELoginWS.gettype().namespace

    #Create the login request and unpack the password from the encrypted credentials
    $loginRequest = new-object ($TraverseBVELoginNS + '.loginRequest')
    $loginRequest.username = $credential.GetNetworkCredential().Username
    $loginRequest.password = $credential.GetNetworkCredential().Password

    $loginResult = $TraverseBVELoginWS.login($loginRequest)

    if (!$loginResult.success) {throw "The connection failed to $Hostname. Reason: Error $($loginresult.errorcode) $($loginresult.errormessage)"}

    set-variable -name TraverseSession -value $loginresult -scope Global
    set-variable -name TraverseHostname -value $hostname -scope Global
    if (!$Quiet) {
        write-host -foreground green "Connected to $hostname BVE as $($loginrequest.username) using Web Services API"
    }

    #Return the session if switch is set
    if ($WSSessionPassThru) {$LoginResult}
} #If !$NoWS

#Create a Legacy WS Session
if (!$NoLegacyWS) {
    
    <# I couldn't get this to work correctly so instead just saving the credentials to use for individual commands. Leaving this here for future debugging.

    #Workaround for bug with new-webserviceproxy (http://www.sqlmusings.com/2012/02/04/resolving-ssrs-and-powershell-new-webserviceproxy-namespace-issue/)
    $TraverseBVELegacyLoginWS = (new-webserviceproxy -uri "$TraverseProtocol://$($hostname)/api/soap/public/sessionManager?wsdl" -ErrorAction stop)
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
    
    
    set-variable -scope Global -name "TraverseLegacyCredential" -value $credential

    #>
}

} #Connect-TraverseBVE