function Get-UnixTimestamp ([DateTime]$Date = (get-date)) {
    [int][double]::Parse((Get-Date $Date -UFormat %s))
}
