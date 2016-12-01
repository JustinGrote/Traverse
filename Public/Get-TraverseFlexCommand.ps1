function Get-TraverseFlexCommand {
<#
.SYNOPSIS
Generates Powershell Commands from the Traverse FlexAPI
#>

    [CmdletBinding()]
    param ()


    $HelpResult = invoke-traversecommand "help"
    $HelpResult | where {$PSItem -notmatch '^End with .quit*'} | foreach {

        #Initialize special matches variable just in case
        $Matches = $null

        #Parse out the various inital elements of the command
        $cmdParts = @{}
        if ($PSItem -match '^(?<noun>[a-zA-z]*)\.?(?<verb>[a-zA-Z]*)\ (?<params>\".*\")') {
            #Save Matches result in case it changes due to processing or matching I do later
            $cmdMatches = $Matches

            $cmdParts.noun = $cmdMatches['noun']

            if ($cmdMatches['verb']) {
                #Capitalize first letter using TextInfo to meet Powershell Guidelines
                $TextInfo = (Get-Culture).TextInfo

                $cmdParts.verb = $TextInfo.ToTitleCase($cmdMatches['verb'])
            } else {
                $cmdParts.verb = 'Invoke'
            }

            $cmdParts.params = $cmdMatches['params']

            [psCustomObject]$cmdParts
        }

<# TODO: Convert to PSObject
        [pscustomobject][ordered]@{
            Verb = ($_ -replace '^[a-zA-Z]*?[\.]([a-zA-Z]*?)[$ ].*','$1')
            Noun = ($_ -replace '(^[a-zA-Z]*?)[\. ].*','$1')
        }
#>
    }
}