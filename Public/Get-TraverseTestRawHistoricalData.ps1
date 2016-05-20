function Get-TraverseTestRawHistoricalData {

    [CmdletBinding()]
    param(
        #Selection Criteria for the tests to filter. SERIAL NUMBER ONLY FOR NOW. Todo: Accept Test Objects
        #[Parameter(Mandatory)][int]$Filter,
        #First date of data collection. Default is 1 month prior to now
        [DateTime]$Start = ([DateTime]::UtcNow).AddMonths(-1),
        #Last date of data collection. Default is now
        [DateTime]$End = [DateTime]::UtcNow

    )

    $JSONAPIPath = '/api/json/'
    $JSONCommandName = 'test/getRawHistoricalData'

    $JSONBody = @{
        username="jgrote"
        password="ncc1701EE"
        #sessionid="2184676080BE617DA5D32D3FE0C7A4BF"
        searchCriterias=@(@{
            searchOption="TEST_SERIAL_NUMBER"
            searchTerms=4646002
        })
        startTimeExp="6-hours-ago"
        endTimeExp="now"
    }

    $RawJSONTest = '{"sessionid":"2184676080BE617DA5D32D3FE0C7A4BF","searchCriterias":[{"searchOption":"TEST_SERIAL_NUMBER","searchTerms":4646002}],"startTimeExp":"6-hours-ago","endTimeExp":"now"}'

    $JSONCommand = @{
        URI = 'https://' + $TraverseHostname + $JSONApiPath + $JSONCommandName
        Method = 'POST'
        Websession = $TraverseSessionREST
        #Body = $RawJSONTest 
        Body = (ConvertTo-Json -compress $JSONBody)
        ContentType = 'application/json'
    }

    $result = $null
    $result = invoke-restmethod @JSONCommand -verbose
    $result.success
    $result.result.historicaldata.values.count

}