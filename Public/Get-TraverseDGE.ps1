function Get-TraverseDGE {
<#
.SYNOPSIS
Retrieves Traverse DGE Objects

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

    (Invoke-TraverseCommand -Command 'DGE.list' @TraverseCommandParams).data.object
}

#endregion Main

} #Get-TraverseDGE


