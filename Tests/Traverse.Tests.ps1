$Verbose = @{}
if($env:APPVEYOR_REPO_BRANCH -and $env:APPVEYOR_REPO_BRANCH -notlike "master")
{
    $Verbose.add("Verbose",$True)
}

$PSVersion = $PSVersionTable.PSVersion.Major
Import-Module $PSScriptRoot\..\Traverse -Force

#Integration test example
Describe "Traverse PS$PSVersion Basic Command Testing" {
    Context 'Strict mode' { 

        Set-StrictMode -Version latest

        It 'Get-TraverseDevice errors if not connected' {
            {Get-TraverseDevice} | Should Throw 
        }
    }
}
