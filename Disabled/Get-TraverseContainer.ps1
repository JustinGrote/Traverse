function Get-TraverseContainer {
<#
.SYNOPSIS
Retrieves Traverse Container Objects

.DESCRIPTION

.NOTES

.EXAMPLE

#>

[CmdletBinding()]
param (
) # Param

#region Main
process {
    $TraverseCommandParams = @{
        API="REST"
        Verbose=($PSBoundParameters['Verbose'] -eq $true)
        ArgumentList=@{}
    }

    Invoke-TraverseCommand -Command 'Container.list' @TraverseCommandParams
}

#endregion Main

} #Get-TraverseContainer


