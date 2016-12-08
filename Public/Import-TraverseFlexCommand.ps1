function Import-TraverseFlexCommand {
<#
.SYNOPSIS
Connects to the FlexBVE Help API and automatically generates commands to use with Traverse
.DESCRIPTION
This command automatically generates a Powershell Module with the Traverse FlexAPI commands.
These commands match the commands in the FlexAPI, with some additional validation and structure
Documentation for all commands can be found at the Traverse Developers Guide, but there is no inline help generated
#>
    [CmdletBinding()]
    param (
        #A prefix to append to the commands, similar to Powershell Module Prefix.
        [String]$Prefix = "TraverseFlex"
    )

    $commands = Get-TraverseFlexCommand | where {$_.noun}

    #Exclude Create Test and Update Test for now as they require special formatting since they have multiple entries
    #TODO: Add special formatting for Create/Update Test
    $commands = $commands | where {$PSItem.noun -notlike "Test" -and $PSItem.verb -notmatch 'Create|Update'}

    $cmdlist = ""
    #Start with List Commands, because they are easy
    $cmds = $commands
    foreach ($cmdItem in $cmds) {
        $noun = $cmdItem.noun
        $PShellNoun = $noun
        $verb = $cmdItem.verb
        #Substitute Invalid Nouns for Powershell-Approved ones
        $PShellVerb = switch ($verb) {
            "List" {"Get"}
            "Create" {"New"}
            "Delete" {"Remove"}
            "Status" {"Get"; $PShellNoun = $PShellNoun + "Status"}
            "Members" {"Get"; $PShellNoun = $PShellNoun + "Members"}
            "Baseline" {"New"; $PShellNoun = $PShellNoun + "Baseline"}
            "Represent" {"Enter"}
            "Suppress" {"Disable"}
            "" {"Invoke"}
            default {$verb}
        }


        $command = @"
function $PShellVerb-$PShellNoun {
    <#
    .SYNOPSIS
    This is a generated command for the FlexAPI command $noun.$verb
    #>
    param ()
    `$result = Invoke-TraverseCommand -Command $noun.$verb
    if (`$result.data.object) {
        `$result.data.object
    } else {
        `$result
    }
}

"@
        #invoke-expression $command
        $cmdList += $command
    }
    #TODO: Randomly generate path
    $flexModulePath =  $env:temp + "\" + $prefix + ".psm1"
    remove-item  $flexModulePath -ErrorAction SilentlyContinue
    $cmdList > $flexModulePath
    import-module $flexModulePath -prefix $prefix -global
}