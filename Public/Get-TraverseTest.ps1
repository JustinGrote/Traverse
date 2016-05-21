function Get-TraverseTest {
<#
.SYNOPSIS
Retrieves Traverse Tests based on specified criteria.

.DESCRIPTION
This command leverages the Traverse APIs to gather information about tests in Traverse. 
It retrieves all tests visible to the user by default if no parameters are specified.

#>

    [CmdletBinding(DefaultParameterSetName="testName")]

    param (
        #Name of the test you want to retrieve. Regular expressions are supported.
        [Parameter(ParameterSetName="testName")][Alias("TestName")][String]$Name = '*',
        #Name of the device that you wish to get all associated tests
        [Parameter(ParameterSetName="testName",Mandatory)][String]$DeviceName,
        #Specify the individual serial number of the test you wish to retrieve
        [Parameter(ParameterSetName="testSerial")][int]$TestSerial,
        #Filter by the type of test (wmi, snmp, ping, etc.)
        [String]$testType,
        #Filter by the test subtype (cpu, disk, pl, rtt, etc.)
        [String]$subType,
        #[SUPERUSER ONLY] Restrict scope of search to what the specified user can see
        [String]$UserName
    ) # Param

    $argumentList = @{}
    switch ($PSCmdlet.ParameterSetName) {
        "testName" {
                        $argumentList.testName = $Name
                        $argumentList.deviceName = $DeviceName
                   }
        "deviceName" {}
        "testSerial" {$argumentList.testSerial = $testSerial}
    }
    if ($Username) {$argumentList.userName = $UserName}
    if ($testType) {$argumentList.testType = $testType}
    if ($subType)  {$argumentList.subType = $subType}

    (Invoke-TraverseCommand test.list $argumentList -Verbose:($PSBoundParameters['Verbose'] -eq $true)).data.object

} #Get-TraverseDevice


