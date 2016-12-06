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

    $commands = Get-TraverseFlexCommand

    $cmdlist = ""
    #Start with List Commands, because they are easy
    $cmds = $commands | where verb -match "List"
    foreach ($cmdItem in $cmds) {
        $noun = $cmdItem.noun
        $verb = $cmdItem.verb
        $command = @"
function $($cmdItem.verb)-$($cmdItem.noun) {
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
    $cmdList > $env:temp\$prefix`.psm1
    import-module $env:temp\$prefix`.psm1 -prefix $prefix
}