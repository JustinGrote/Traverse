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