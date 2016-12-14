function Get-TraverseTest {
<#
.SYNOPSIS
Retrieves Traverse Tests based on specified criteria.

.DESCRIPTION
This command leverages the Traverse APIs to gather information about tests in Traverse.

.EXMPLE
Get-TraverseTest Device1
Gets all tests from device Device1

.EXAMPLE
Get-TraverseTest -TestName '*disk*' -DeviceName *
Gets all tests from devices whos name contains the word "disk"

.EXAMPLE
Get-TraverseDevice "*dc*" | Get-TraverseTest -subtype ping
Get all tests of type "ping" from the devices whos name contains the letters "dc"

#>

    [CmdletBinding(DefaultParameterSetName="testName")]

    param (
        #Name of the test you want to retrieve. Regular expressions are supported.
        [Parameter(ParameterSetName="testName",ValueFromPipelinebyPropertyName)][Alias("TestName")][String]$Name = '*',
        #Name of the device that you wish to retrieve the test from. If specified alone, gets all tests associated with this device
        [Parameter(Position=0,ParameterSetName="testName",Mandatory,ValueFromPipelinebyPropertyName)]
        [Parameter(ParameterSetName="deviceName",Mandatory)][String]$DeviceName,
        #Specify the individual serial number of the test you wish to retrieve
        [Parameter(ParameterSetName="testSerial",Mandatory,ValueFromPipeline,ValueFromPipelinebyPropertyName)][int]$TestSerial,
        #Filter by the type of test (wmi, snmp, ping, etc.)
        [String]$testType,
        #Filter by the test subtype (cpu, disk, pl, rtt, etc.)
        [String]$subType,
        #[SUPERUSER ONLY] Restrict scope of search to what the specified user can see
        [String]$RunAs,
        #Show the unencrypted cleartext password used for the test, if applicable
        [Switch]$ShowPWs
    ) # Param

    process {
        $argumentList = @{}
        switch ($PSCmdlet.ParameterSetName) {
            "testName" {
                            $argumentList.testName = $Name
                            if ($DeviceName) {$argumentList.deviceName = $DeviceName -replace ' ','*'}
                       }
            "deviceName" {
                            $argumentList.deviceName = $DeviceName -replace ' ','*'
                       }
            "testSerial" {$argumentList.testSerial = $testSerial}
        }
        if ($RunAs) {$argumentList.userName = $RunAs}
        if ($testType) {$argumentList.testType = $testType}
        if ($subType)  {$argumentList.subType = $subType}
        if ($ShowPWs) {$argumentList.showPassword = 'true'}

        Invoke-TraverseCommand test.list $argumentList -Verbose:($PSBoundParameters['Verbose'] -eq $true)
    }
} #Get-TraverseDevice