function ConvertFrom-UnixTimestamp{
    param (
        [int]$UnixTimestamp=0,
        #Specify if the timestamp was collected in a different timezone
        [int]$SourceTimeZone=0,
        #Specify if the timestamp is UTC (Skip UTC Conversion)
        [switch]$UTC
    )

    [datetime]$origin = '1970-01-01 00:00:00'
    
    $result = $origin.AddSeconds($UnixTimestamp)

    if (!($UTC)) {
        if ($SourceTimeZone) {
            $result = $result.AddHours($SourceTimeZone)
        } else {

        }

    }
}
