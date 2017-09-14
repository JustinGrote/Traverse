#Build Script for Traverse Powershell Module
#Uses Invoke-Build (https://github.com/nightroman/Invoke-Build)
#Run by changing to the project root directory and run ./Invoke-Build.ps1
#Uses a master-always-deploys strategy and semantic versioning - http://nvie.com/posts/a-successful-git-branching-model/

#Initialize Build Environment
Enter-Build {
    $BuildHelperModules = "BuildHelpers","PSDeploy","Pester","powershell-yaml"
    "Setting up Build Environment..."

    # Grab nuget bits, install modules, set build variables, start build.
    Get-PackageProvider -Name NuGet -ForceBootstrap | Out-Null
    #Add the nuget repository so we can download things like GitVersion
    if (!(Get-PackageSource nuget.org)) {
        Register-PackageSource -provider NuGet -name nuget.org -location http://www.nuget.org/api/v2 -Trusted
    }

    function Resolve-Module ($BuildModules) {
        foreach ($BuildModuleItem in $BuildModules) {
            if (get-module $BuildModuleItem -ListAvailable) {
                #Uncomment if you want to ensure you always have the latest available version
                #Update-Module $BuildModuleItem -verbose -warningaction silentlycontinue
            } else {
                Install-Module $BuildModuleItem -verbose -warningaction silentlycontinue
            }
        }
    }

    Resolve-Module $BuildHelperModules

    Set-BuildEnvironment -buildoutput 'Release' -force
    $Timestamp = Get-date -uformat "%Y%m%d-%H%M%S"
    $PSVersion = $PSVersionTable.PSVersion.Major
    "Build Environment Prepared! Environment Information:"
    Get-BuildEnvironment

    #Move to the Project Directory if we aren't there already
    Set-Location $env:BHProjectPath

    #Create BuildOutput Directory if it doesn't already exist
    if (!(test-path $env:BHBuildOutput)) {New-Item -ItemType Directory $env:BHBuildOutput}
}

task Version {
    #This task determines what version number to assign this build
    $GitVersionConfig = "$env:BHProjectPath/GitVersion.yml"

    #Fetch GitVersion
    $GitVersionCMDPackageName = "GitVersion.CommandLine"
    Install-Package $GitVersionCMDPackageName -scope currentuser
    $GitVersionEXE = ((get-package gitversion.commandline).source | split-path -Parent) + "\tools\GitVersion.exe"

    #Does this project have a module manifest? Use that as the Gitversion starting point (will use this by default unless project is tagged higher)
    #Uses Powershell-YAML module to read/write the GitVersion.yaml config file
    if (Test-Path $env:BHPSModuleManifest) {
        $ModuleManifestVersion = [Version](Get-Metadata $env:BHPSModuleManifest)
        if (Test-Path $env:BHProjectPath/GitVersion.yml) {
            $GitVersionConfigYAML = [ordered]@{} 
            #ConvertFrom-YAML returns as individual key-value hashtables, we need to combine them into a single hashtable
            (Get-Content $GitVersionConfig | ConvertFrom-Yaml) | foreach-object {$GitVersionConfigYAML += $PSItem}
            $GitVersionConfigYAML.'next-version' = $ModuleManifestVersion.ToString()
            $GitVersionConfigYAML | ConvertTo-Yaml | Out-File $GitVersionConfig
        } else {
            @{"next-version"=$ModuleManifestVersion.toString()} | ConvertTo-Yaml | Out-File $GitVersionConfig
        }
    }

    #Calcuate the GitVersion
    $GitVersionInfo = iex "$GitVersionEXE $env:BHProjectPath" | ConvertFrom-JSON
    $Script:ProjectBuildVersion = [Version] $GitVersionInfo.MajorMinorPatch
}

<#
#Build the Module. Mostly just consists of updating the manifests
task UpdateMetadata Version {
    # Load the module, read the exported functions, update the psd1 FunctionsToExport
    Set-ModuleFunctions
    
    # Are we in the master branch? Bump the version based on the powershell gallery if so, otherwise add a build tag
    if ($BHBranchName -eq 'master') {
        #Get-NextNugetPackageVersion -Name (Get-ProjectName)
        #Update-Metadata -Path $env:BHPSModuleManifest -PropertyName ModuleVersion -Value (Get-NextNugetPackageVersion -Name (Get-ProjectName))
    } else {

    }

    # Add Release Notes from current version
    # TODO: Generate Release Notes from Github
    #Update-Metadata -Path $env:BHPSModuleManifest -PropertyName ReleaseNotes -Value ("$($env:APPVEYOR_REPO_COMMIT_MESSAGE): $($env:APPVEYOR_REPO_COMMIT_MESSAGE_EXTENDED)")
}  
#>

#Pester Testing
task Pester {
    "Starting Pester Tests..."
    $TestFile = "$BuildOutput\TestResults_PS$PSVersion`_$TimeStamp.xml"
    $PesterResult = Invoke-Pester -OutputFormat "NUnitXml" -OutputFile $TestFile -PassThru

    # In Appveyor?  Upload our test results!
    # TODO: Move this to its own task
    If($ENV:BHBuildSystem -eq 'AppVeyor')
    {
        (New-Object 'System.Net.WebClient').UploadFile(
            "https://ci.appveyor.com/api/testresults/nunit/$($env:APPVEYOR_JOB_ID)",
            $TestFile )
    }

    # Failed tests?
    # Need to error out or it will proceed to the deployment. Danger!
    if($TestResults.FailedCount -gt 0)
    {
        Write-Error "Failed '$($TestResults.FailedCount)' tests, build failed"
    }
    "`n"
}

#Deployment Task. Uses PSDeploy module
task Deploy Build,Test {
    Invoke-PSDeploy
}

#Build SuperTask
task Build UpdateMetadata

#Test SuperTask
task Test Pester

#Default Task - Build, Test with Pester, Deploy
task . Build,Test

