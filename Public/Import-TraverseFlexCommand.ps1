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
        [String]$Prefix = "TraverseFlex",
        #Don't generate shorthand aliases for commands
        [Switch]$NoCreateAliases,
        #Shorthand Alias Prefix to use. Defaults to "tf". For example, Get-TraverseFlexUser aliases to "gtfu"
        [String]$AliasPrefix = "tf"
    )

    $commands = Get-TraverseFlexCommand | where {$_.noun}

    #Exclude items that have bad formatting or otherwise require special formatting
    #TODO: Fix these functions

    $commands = $commands | where {
        "TestCreate",
        "TestUpdate",
        "TestSuppress",
        "ActionCreate",
        "ActionUpdate",
        "HotSpotUpdate" -notcontains ($PSItem.noun + $PSItem.verb)}

    $cmdlist = ""

    #Generate Function Code for the various commands
    foreach ($cmdItem in $commands) {
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

        #Generate the Parameter Information
        $PShellParams = @()
        foreach ($param in $cmdItem.params) {
            $PShellParams += switch ($param.type) {
                "String" {"[String]`$$($param.name)`r`n"}
                "RegEx" {"[Regex]`$$($param.name)`r`n"}
                default {"[String]`$$($param.name)`r`n"}
            }
        }

        #Add in the Comma Characters for all but the last command
        $PShellParamsFinal = ""
        $PShellParams | select -skiplast 1 | foreach {
            $PShellParamsFinal += $PSItem -replace '\r\n$',",`r`n"
        }
        $PShellParamsFinal += $PShellParams | select -last 1


        $command = @"
function $PShellVerb-$PShellNoun {
    [CmdletBinding()]
    <#
    .SYNOPSIS
    This is a generated command for the FlexAPI command $noun.$verb
    #>
    param (
        $PShellParamsFinal
    )

    #Filter Out Common PS Parameters so they don't screw up Invoke-TraverseCommand
    `$traverseCommandParameters = `$PSCmdlet.MyInvocation.BoundParameters.psobject.copy()
    `$commonParameters = [System.Management.Automation.PSCmdlet]::CommonParameters +
        [System.Management.Automation.PSCmdlet]::OptionalCommonParameters

    `$keysToRemove = @()
    foreach (`$tCommandKey in `$PSCmdlet.MyInvocation.BoundParameters.keys) {
        if (`$commonParameters -contains `$tCommandKey) {
            `$keysToRemove += `$tCommandKey
        }
    }
    `$keysToRemove | foreach {
        `$traverseCommandParameters.Remove("`$PSItem")
    }

    #Execute the Command
    `$result = Invoke-TraverseCommand -Verbose -Command $noun.$verb -ArgumentList `$traverseCommandParameters
    #TODO: Move this formatting into Invoke-TraverseCommand, it belongs there.
    if (`$result.data.object) {
        `$result.data.object
    } else {
        `$result.status
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
    if (!$NoCreateAliases) {
        foreach ($cmdlet in (get-command -module $prefix | sort Name)) {
            #Find a shortname that is available and not already used, up to 4 characters
            $aliasParams = @{
                Name = $null
                Value = $cmdlet.Name
            }

            $i = 1
            do {
                $candidateAliasName = ($cmdlet.verb.substring(0,1).toLower() +
                    $AliasPrefix.toLower() +
                    $cmdlet.noun.replace($prefix,'').substring(0,$i).toLower())
                if (get-alias $candidateAliasName -ErrorAction SilentlyContinue) {
                    $i++
                    continue
                } else {
                    $aliasParams.Name = $candidateAliasName
                }

            } until ($aliasParams.Name -or $i -ge 5)

            if ($aliasParams.Name) {
                Set-Alias @aliasParams -Scope Global
            } else {
                write-Warning "Couldn't find a sufficient alias shorthand for $($cmdlet.name)"
            }
        }
    }
}