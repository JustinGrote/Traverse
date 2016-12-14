function Get-TraverseDepartment {
<#
.SYNOPSIS
Retrieves Traverse Department Objects

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

    Invoke-TraverseCommand -Command 'department.list' @TraverseCommandParams
}

#endregion Main

} #Get-TraverseDepartment


