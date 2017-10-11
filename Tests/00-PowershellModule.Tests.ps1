$PSVersion = $PSVersionTable.PSVersion.Major
$BuildOutputProject = Join-Path $env:BHBuildOutput $env:BHProjectName

Describe "$env:BHProjectName Module Build" {
    $ModuleManifestPath = Join-Path $BuildOutputProject "\*.psd1"

    Context "Powershell Module - $ModuleManifestPath" {
        $ModuleName = $env:BHProjectName
        It "Has a valid Module Manifest" {
            #Copy the Module Manifest to a temp file in order to test to fix a bug where 
            #Test-ModuleManifest caches the first result, thus not catching changes
            #Not using New-GUID because not available in Azure Functions
            $TempModuleManifestPath = join-path $env:Temp ($env:BHProjectName + "-" + ([GUID]::newguid()).guid + ".psd1")
            copy-item $ModuleManifestPath $TempModuleManifestPath
            $Script:Manifest = Test-ModuleManifest $TempModuleManifestPath
            remove-item $TempModuleManifestPath
        }

        It "Has a valid root module" {
            $Manifest.RootModule | Should Be "$ModuleName.psm1"
        }

        It "Has a valid Description" {
            $Manifest.Description | Should Not BeNullOrEmpty
        }

        It "Has a valid GUID" {
            [Guid]$Manifest.Guid | Should BeOfType 'System.GUID'
        }

        It "Has a valid Copyright" {
            $Manifest.CopyRight | Should Not BeNullOrEmpty
        }

        It 'Exports all public functions' {
            $FunctionFiles = Get-ChildItem "$BuildOutputProject\Public" -Filter *.ps1 | Select -ExpandProperty BaseName
            $FunctionNames = $FunctionFiles | foreach {$_ -replace '-', "-$($Manifest.Prefix)"}
            $ExFunctions = $Manifest.ExportedFunctions.Values.Name
            foreach ($FunctionName in $FunctionNames)
            {
                $ExFunctions -contains $FunctionName | Should Be $true
            }
        }
        
        It "Has at least 1 exported command" {
            $Script:Manifest.exportedcommands.count | Should BeGreaterThan 0
        }
        It "Imports to Powershell without errors" {
            Import-Module $BuildOutputProject -PassThru | Should BeOfType System.Management.Automation.PSModuleInfo
        }
    }
}