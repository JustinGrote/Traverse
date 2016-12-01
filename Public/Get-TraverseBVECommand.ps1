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
        $cmdParts = @{}
        #Match up the base elements to variables
        if ($PSItem -match '^(?<noun>[a-zA-z]*)\.?(?<verb>[a-zA-Z]*)\ (?<params>\".*\")' ) {
            $cmdParts.noun = $Matches['noun'].tolower()
            if ($cmdParts.verb) {
                $cmdParts.verb = $Matches['noun'].tolower()
            } else {
                $cmdParts.verb = 'invoke'
            }
            $cmdParts.params = $Matches['params'].trim()
        }

        [psCustomObject]$cmdParts

<# TODO: Convert to PSObject
        [pscustomobject][ordered]@{
            Verb = ($_ -replace '^[a-zA-Z]*?[\.]([a-zA-Z]*?)[$ ].*','$1')
            Noun = ($_ -replace '(^[a-zA-Z]*?)[\. ].*','$1')
        }
#>
    }
}