function Get-UnixTimestamp ([DateTime]$Date) {
    [int][double]::Parse((Get-Date $Date -UFormat %s))
}
