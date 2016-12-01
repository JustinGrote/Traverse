function Get-TraverseBVECommand {
<#
.SYNOPSIS
Generates a list of Traverse BVE Available Commands
#>

    [CmdletBinding()]
    param ()


    $HelpResult = invoke-traversecommand "help"

    $HelpResult | where {$PSItem -notmatch '^End with .quit*'} | foreach {
        #Parse out the various inital elements of the command
        [pscustomobject][ordered]@{
            Verb = ($_ -replace '^[a-zA-Z]*[\.]([a-zA-Z]*) .*','$1')
            Noun = ($_ -replace '(^[a-zA-Z]*)[\. ].*','$1')

        }


    }
}