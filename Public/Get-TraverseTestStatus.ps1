function Get-TraverseTestStatus {
<#
.SYNOPSIS
Retrieves Traverse Test status based on specified criteria.

.DESCRIPTION
This command leverages the Traverse APIs to get the current status of a device.
#>

    [CmdletBinding(DefaultParameterSetName="testName")]

    param (
        #Name of the test you want to retrieve. Regular expressions are supported.
        [Parameter(ParameterSetName="testName")][Alias("TestName")][String]$Name = '*',
        #Name of the device that you wish to retrieve the test from. If specified alone, gets all tests associated with this device
        [Parameter(ParameterSetName="testName")]
        [Parameter(ParameterSetName="deviceName",Mandatory)][String]$DeviceName,
        #Specify the individual serial number of the test you wish to retrieve
        [Parameter(ParameterSetName="testSerial",Mandatory)][int]$TestSerial,
        #Only retrieve tests that match the specified status criteria
        [ValidateSet('OK','Warning','Critical','Unknown','Unreachable','Suspended')][String]$status,
        #[SUPERUSER ONLY] Restrict scope of search to what the specified user can see
        [String]$UserName
    ) # Param

    $argumentList = @{}
    switch ($PSCmdlet.ParameterSetName) {
        "testName" {
                        $argumentList.testName = $Name
                        $argumentList.deviceName = $DeviceName
                   }
        "deviceName" {
                        $argumentList.deviceName = $DeviceName
                   }
        "testSerial" {$argumentList.testSerial = $testSerial}
    }
    if ($Username) {$argumentList.userName = $UserName}
    if ($testType) {$argumentList.testType = $testType}
    if ($subType)  {$argumentList.subType = $subType}

    (Invoke-TraverseCommand test.list $argumentList -Verbose:($PSBoundParameters['Verbose'] -eq $true)).data.object

} #Get-TraverseDevice


