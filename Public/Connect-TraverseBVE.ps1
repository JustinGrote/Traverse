function Connect-TraverseBVE {
<#
.SYNOPSIS
 Connects to a Traverse BVE system with the Web Services API enabled.

.PARAMETER Hostname
The DNS name or IP address of the Traverse BVE system

.PARAMETER Credential
The username and password needed to access the system in secure PSCredential format.

.PARAMETER Force
Create a new session even if one already exists

.PARAMETER NoREST
Skips the connection to the REST API

.PARAMETER NoLegacyWS
Skips the connection to the legacy Web Services API

.PARAMETER RESTSessionPassThru
Pass the REST session object to the pipeline. Useful if you want to work with multiple sessions simultaneously

.PARAMETER WSSessionPassThru
Pass the SOAP session object to the pipeline. Useful if you want to work with multiple sessions simultaneously

#>

param (
    [Parameter(Mandatory=$true)][String]$Hostname,
    [PSCredential]$Credential = (get-credential -message "Enter your Traverse Username and Password"),
    [Switch]$Force,
    [Switch]$NoREST,
    [Switch]$NoLegacyWS,
    [Switch]$RESTSessionPassThru,
    [Switch]$WSSessionPassThru
) # Param

if (!$Hostname) {write-warning "You are already logged into Traverse. Use the -force parameter if you want to connect to a different one or use a different username";return} 
if ($Global:TraverseSession -and !$force) {write-warning "You are already logged into Traverse. Use the -force parameter if you want to connect to a different one or use a different username";return} 

#Workaround for bug with new-webserviceproxy (http://www.sqlmusings.com/2012/02/04/resolving-ssrs-and-powershell-new-webserviceproxy-namespace-issue/)
$TraverseBVELoginWS = (new-webserviceproxy -uri "https://$($hostname)/api/soap/login?wsdl" -ErrorAction stop)
$TraverseBVELoginNS = $TraverseBVELoginWS.gettype().namespace

#Create the login request and unpack the password from the encrypted credentials
$loginRequest = new-object ($TraverseBVELoginNS + '.loginRequest')
$loginRequest.username = $credential.GetNetworkCredential().Username
$loginRequest.password = $credential.GetNetworkCredential().Password

$loginResult = $TraverseBVELoginWS.login($loginRequest)

if (!$loginResult.success) {throw "The connection failed to $Hostname. Reason: Error $($loginresult.errorcode) $($loginresult.errormessage)"}

set-variable -name TraverseSession -value $loginresult -scope Global
set-variable -name TraverseHostname -value $hostname -scope Global
write-host -foreground green "Connected to $hostname BVE as $($loginrequest.username) using Web Services API"
#Return the session if switch is set
if ($WSSessionPassTHru) {$LoginResult}

#Create a REST Session
if (!$NoREST) {
    #Check for existing session
    if ($Global:TraverseSessionREST -and !$force) {write-warning "You are already logged into Traverse (REST). Use the -force parrameter if you want to connect to a different one or use a different username";return}

    #Log in using Credentials
    $RESTLoginURI = "https://$Hostname/api/rest/command/login?" + $Credential.GetNetworkCredential().UserName + "/" + $Credential.GetNetworkCredential().Password
    $RESTLoginResult = Invoke-RestMethod -sessionvariable TraverseSessionREST -Uri $RESTLoginURI
    if ($RESTLoginResult -notmatch "OK") {throw "The connection failed to $Hostname. Reason: $RESTLoginResult"}
    $Global:TraverseSessionREST = $TraverseSessionREST
    write-host -foreground green "Connected to $Hostname BVE as $($Credential.GetNetworkCredential().Username) using REST API"
    #Return The session if switch is set
    if ($RESTSessionPassThru) {$TraverseSessionREST}
}

#Create a Legacy WS Session
if (!$NoLegacyWS) {
    
    <# I couldn't get this to work correctly so instead just saving the credentials to use for individual commands. Leaving this here for future debugging.

    #Workaround for bug with new-webserviceproxy (http://www.sqlmusings.com/2012/02/04/resolving-ssrs-and-powershell-new-webserviceproxy-namespace-issue/)
    $TraverseBVELegacyLoginWS = (new-webserviceproxy -uri "https://$($hostname)/api/soap/public/sessionManager?wsdl" -ErrorAction stop)
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
    #>
    
    set-variable -scope Global -name "TraverseLegacyCredential" -value $credential
}

} #Connect-TraverseBVE
