function Get-TraverseTestRawHistoricalData {
<#
.SYNOPSIS
Retrieves historical data for a given Traverse test. 
Test information may be specified either directly with the serial number, or by passing a test object via the pipeline.

.NOTES
The amount of results depends on your timescale. 
You may receive less total results by specifying timeframes longer than 30 days because Traverse will switch to aggregate timescale

.EXAMPLE
Get-TraverseTestRawHistoricalData -TestSerial 15089601 -start (get-date).addmonths(-6)
Gets the historical data for the last 6 months

.EXAMPLE
Get-TraverseTest -devicename 'mydevice' | Get-TraverseTestRawHistoricalData
Gets the historical data for all tests on 'mydevice'

.EXAMPLE
Get-TraverseTest -devicename 'mydevice' -testname '*Space*' | Get-TraverseTestRawHistoricalData -start '3/1/2015' -end '9/1/2015'
Gets the historical data for all tests on 'mydevice' with the word 'Space' in their name ranging from March 2015 to September 2015
#>
    [CmdletBinding()]
    param(
        #TODO: Selection Criteria for the tests to filter. SERIAL NUMBER ONLY FOR NOW. Todo: Accept Test Objects
        #[Parameter(Mandatory)][int]$Filter,

        #Specify the individual serial number of the test you wish to retrieve.
        [Parameter(Mandatory,ValueFromPipelineByPropertyName)]
        [Alias("SerialNumber")]
        [int]$TestSerial,

        #First date of data collection. Default collects the last 6 hours of historical data
        [DateTime]$Start = ([DateTime]::UtcNow).AddHours(-6),

        #Last date of data collection. Default is now
        [DateTime]$End = [DateTime]::UtcNow

    )

    process {
        $ArgumentList = @{
            searchCriterias=@(@{
                searchOption="TEST_SERIAL_NUMBER"
                searchTerms=$TestSerial
            })
            startTime=((Get-UnixTimestamp $start)*1000)
            endTime=((Get-UnixTimestamp $end)*1000)
        }
            
        (Invoke-TraverseCommand -API JSON -Command 'test/getRawHistoricalData' -ArgumentList $ArgumentList -Verbose:($PSBoundParameters['Verbose'] -eq $true)).historicaldata
    }
}