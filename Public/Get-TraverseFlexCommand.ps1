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
        #Initialize the hashtable so that PSCustomObject doesn't mess it up later
        $cmdParts = [ordered]@{
            noun = $null
            verb = $null
            params = $null
        }
        if ($PSItem -match '^(?<noun>[a-zA-z]*)\.?(?<verb>[a-zA-Z]*)\ (?<params>.*)') {
            #Save Matches result in case it changes due to processing or matching I do later
            $cmdMatches = $Matches

            #Used for TitleText conversion
            $TextInfo = (Get-Culture).TextInfo

            if ($cmdMatches['verb']) {
                #Capitalize first letter using TextInfo to meet Powershell Guidelines
                $cmdParts.verb = $TextInfo.ToTitleCase($cmdMatches['verb']).trim()
            } else {
                #Default to "Invoke" if no verb was found
                $cmdParts.verb = 'Invoke'
            }

            $cmdParts.noun = $TextInfo.ToTitleCase($cmdMatches['noun']).trim()

            #Process Parameter syntax for attributes
            $roughParams = @()
            $cmdMatches['params'] -split ', ' | foreach {
                $paramString = $PSItem.trim()
                $cmdParam = [ordered]@{
                    name = $null
                    mandatory = $null
                    type = $null
                    validateset = $null
                    argument = $null
                }

                #If the parameter is encapsulated in brackets, this means it is an optional parameter. Strip the brackets and add the appropriate tag.
                if ($paramString -match '^\[.*\]$') {
                    $paramString = ($paramString -replace '^\[(.*)\]$','$1').trim()
                    $cmdParam.mandatory = $false
                } else {
                    $cmdParam.mandatory = $true
                }

                #If the parameter item has a | it's an "OR" parameter.
                #If its optional, just split it into two separate optional parameters
                #If it is mandatory, it should have its own parameter set
                #Unfortunately | is used inside of arguments so we can't just do a simple split, hence the fancy regex
                if ($paramstring -match '^(\".*?=.*?\") \| (\".*?=.*?\")$' ) {
                    $result = $matches.remove(0)
                    $matches.values | foreach {
                        $roughParams += [ordered]@{
                            argument = $PSItem.trim()
                            mandatory = $cmdParam.mandatory
                        }
                    }
                } else {
                    $cmdParam.argument = $paramString.trim()
                    $roughParams += $cmdParam
                }

                #TODO: If a parameter doesn't have brackets and is a constant value, it should be configured as a switch with its own parameter set
            }

            #Second Pass to clean up the parameter entries
            $finalParams = @()
            foreach ($roughParamItem in $roughParams) {
                #strip outer quotes if present
                $roughParamItem.argument = ($roughParamItem.argument -replace '^\"(.*)\"$','$1').trim()
                #Split the argument into its name and type definition
                $roughParamItem.name = ($roughParamItem.argument -split '=')[0].trim()
                $argTypeDef = ($roughParamItem.argument -split '=')[1].trim()
                #If the argument is not enclosed in brackets, it is a literal. For now just treat this as a string entry
                #TODO: ValidateSet for the literal to cut down on commands.
                if ($argTypeDef -notmatch '^\<.*\>$') {
                    $roughParamItem.type = 'String'
                }  else {
                    #If it does have brackets, strip them and match for type
                    $argTypeDef = $argTypeDef -replace '^\<(.*)\>$','$1'
                    switch -regex ($argTypeDef) {
                        #If it has multiple specific params, save them for defining for validationSet later
                        #TODO: Define ValidationSet
                        "\|" {
                                $roughParamItem.type = 'String'
                                $roughParamItem.validateSet = $argTypeDef.split('|')
                        }
                        "^value$" {$roughParamItem.type = 'String'}
                        "^regexp$" {$roughParamItem.type = 'Regex'}
                        default {$roughParamItem.type = 'String'}
                    }
                }
                $finalParams += [PSCustomObject]$roughParamItem
            }

            $cmdParts.params = $finalParams
        }

        [PSCustomObject]$cmdParts
    }
}