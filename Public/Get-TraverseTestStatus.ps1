function Get-TraverseTestStatus {
<#
.SYNOPSIS
Retrieves Traverse Test status based on specified criteria.

.DESCRIPTION
This command leverages the Traverse APIs to get the current status of a device.
#>

    [CmdletBinding(DefaultParameterSetName="deviceName")]

    param (
        [Parameter(ParameterSetName="deviceName",Mandatory)][String]$DeviceName,
        #Specify the individual serial number of the test you wish to retrieve
        [Parameter(ParameterSetName="testSerial",ValueFromPipelineByPropertyName,Mandatory)][Alias("serialNumber")][int]$TestSerial,
        #Only retrieve tests that match the specified status criteria
        [ValidateSet('OK','Warning','Critical','Unknown','Unreachable','Suspended')][String]$status
    ) # Param

#region JSON
    process {
        $argumentList = @{}
        switch ($PSCmdlet.ParameterSetName) {

            "deviceName" {
                $argumentList.searchCriterias = @(@{
                    SearchOption = "DEVICE_NAME"
                    SearchTerms = $DeviceName -replace ' ','*'
                })
            }
            "testSerial" {
                $argumentList.searchCriterias = @(@{
                    SearchOption = "TEST_SERIAL_NUMBER"
                    SearchTerms = $TestSerial
                })

            }
        }

        (Invoke-TraverseCommand -API JSON "test/getStatuses" $argumentList -Verbose:($PSBoundParameters['Verbose'] -eq $true))
    }

#endregion JSON


#region BVEAPI
<#
#THis section is how you would get this info with the BVE API, unfortuantely it does not as of 7.x return results in proper JSON.
#Preserving for when this gets fixed.
    process {
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
        if ($status) {$argumentList.status = $status}
        (Invoke-TraverseCommand test.status $argumentList -Verbose:($PSBoundParameters['Verbose'] -eq $true))
    }
#>

#endregion BVEAPI
} #Get-TraverseDevice


