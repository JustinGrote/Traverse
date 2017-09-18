$Verbose = @{}
if($env:APPVEYOR_REPO_BRANCH -and $env:APPVEYOR_REPO_BRANCH -notlike "master")
{
    $Verbose.add("Verbose",$True)
}

$PSVersion = $PSVersionTable.PSVersion.Major
$BuildOutputProject = Join-Path $env:BHBuildOutput $env:BHProjectName

Describe "$env:BHProjectName Module Build" {
    It "Has a valid Module Manifest" {
        $manifest = Test-ModuleManifest (Join-Path $BuildOutputProject "\*.psd1")
    }
    It "Has at least 1 exported command" {
        $manifest.exportedcommands.count | Shoul
    }
    It "Imports to Powershell without errors" {
        Import-Module $BuildOutputProject
    }
}

#Integration test example
Describe "Traverse PS$PSVersion Basic Command Testing" {
    Context 'Strict mode' { 
        Set-StrictMode -Version latest

        It 'Get-TraverseDevice errors if not connected' {
            {Get-TraverseDevice} | Should Throw 
        }
    }
}
