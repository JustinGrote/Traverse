function Get-TraverseTestGraph {
<#
.SYNOPSIS
Retrieves a historical data graph for a given Traverse test. 
Test information may be specified either directly with the serial number, or by passing a test object via the pipeline.

.EXAMPLE
Get-TraverseTestGraph -TestSerial 15089601 -start (get-date).addmonths(-6)
Gets the historical data for the last 6 months

.EXAMPLE
Get-TraverseTest -devicename 'mydevice' | Get-TraverseTestGraph
Gets the historical data for all tests on 'mydevice'

.EXAMPLE
Get-TraverseTest -devicename 'mydevice' -testname '*Space*' | Get-TraverseTestGraph -start '3/1/2015' -end '9/1/2015'
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
        [DateTime]$End = [DateTime]::UtcNow,

        #Width of the graph, in pixels
        [int]$Width,

        #Height of the graph, in pixels
        [int]$Height,

        #Show Threshold Lines
        [Switch]$ShowThresholds,

        #X Axis Label
        [string]$XLabel,

        #Y Axis Label
        [string]$YLabel,

        #Output path of Graph. Defaults to temp folder with a random name
        [String]$Path = $env:TEMP + '\' + (new-guid).tostring() + '.gif'

    )

    process {
        $ArgumentList = @{
            testSerialNumber=$TestSerial
            startTime=((Get-UnixTimestamp $start)*1000)
            endTime=((Get-UnixTimestamp $end)*1000)
        }

        #Simple Parameter Passthrough
        foreach ($ParameterItem in "Width","Height","ShowThresholds","XLabel","Ylabel") {
            if ($PSBoundParameters[$ParameterItem]) {$ArgumentList.add($ParameterItem.tolower(),$PSBoundParameters[$ParameterItem])}
        }

        (Invoke-TraverseCommand -Command 'graph/getGraphByQuery' -API JSON -Get -OutFile $path -ArgumentList $ArgumentList -Verbose:($PSBoundParameters['Verbose'] -eq $true)) 

        write-verbose "Traverse Test Graph Saved to $Path"
    }
}