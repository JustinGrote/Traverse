#requires -version 5
#Build Script for Traverse Powershell Module
#Uses Invoke-Build (https://github.com/nightroman/Invoke-Build)
#Run by changing to the project root directory and run ./Invoke-Build.ps1
#Uses a master-always-deploys strategy and semantic versioning - http://nvie.com/posts/a-successful-git-branching-model/

#Initialize Build Environment
Enter-Build {
    $BuildHelperModules = "BuildHelpers","PSDeploy","Pester","powershell-yaml"
    "Setting up Build Environment..."

    "Environment Variables"
    "---------------------"
    get-childitem env: | out-string

    "Powershell Variables"
    "--------------------"
    Get-Variable | select-object name,value,visibility | format-table -autosize | out-string

    if ($APPVEYOR) {
        write-host -fore green "Detected that we are running in Appveyor! AppVeyor Environment Information:"
        get-item env:/Appveyor*
        write-host -fore Green "PS Module Path: $PSModulePath"
    }

    #If we are in a CI (Appveyor/etc.), trust the powershell gallery for purposes of automatic module installation
    #We do this so that if running locally, you are still prompted to install software required by the build
    #If necessary. In a CI, we want it to happen automatically because it'll just be torn down anyways.
    if ($CI) {
        "Detected a CI environment, setting Powershell Repository to trusted automatically and disabling prompt confirmations"
        Set-PSRepository -Name PSGallery -InstallationPolicy Trusted -verbose
        $ConfirmPreference = “None”
    }


    "Package Providers"
    "-----------------"
    Get-PackageProvider -listavailable

    #Register Nuget
    if (!(get-packageprovider "Nuget" -ErrorAction silentlycontinue)) {
        "Nuget Provider Not found. Fetching..."
        Install-PackageProvider Nuget -forcebootstrap -verbose -scope currentuser

        "Installed Nuget Provider Info"
        Get-PackageProvider Nuget | format-list | out-string
    }

    #Add the nuget repository so we can download things like GitVersion
    if (!(Get-PackageSource "nuget.org" -erroraction silentlycontinue)) {
        "Registering nuget.org as package source"
        Register-PackageSource -provider NuGet -name nuget.org -location http://www.nuget.org/api/v2 -Trusted -verbose

        "Nuget.Org Package Source Info "
        Get-PackageSource -name nuget.org
    }



    #All relevant module functions must be loaded or Invoke-Build will fail
    function Resolve-Module ($BuildModules) {
        #Install a module from Powershell Gallery if it is not already available 
        foreach ($BuildModuleItem in $BuildModules) {
            if (get-module $BuildModuleItem -ListAvailable) {
                "Module $BuildModuleItem is installed on this system. Importing..."
                #Uncomment if you want to ensure you always have the latest available version
                #Update-Module $BuildModuleItem -verbose -warningaction silentlycontinue
                Import-Module $BuildModuleItem -verbose
            } else {
                "Module $BuildModuleItem not found. Downloading..."
                Install-Module $BuildModuleItem -verbose -warningaction silentlycontinue -scope currentuser
                "Module $BuildModuleItem downloaded. Importing..."
                Import-Module $BuildModuleItem -verbose
            }
        }
    }

    Resolve-Module $BuildHelperModules

    Set-BuildEnvironment -force
    $Timestamp = Get-date -uformat "%Y%m%d-%H%M%S"
    $PSVersion = $PSVersionTable.PSVersion.Major

    "Build Environment Prepared! Environment Information:"
    "-------------------------------"
    Get-BuildEnvironment

    #Move to the Project Directory if we aren't there already
    Set-Location $env:BHProjectPath
    
    $Script:ProjectBuildPath = $env:BHBuildOutput + "\" + $env:BHProjectName

}

task Clean {
    #Reset the BuildOutput Directory
    if (test-path $ProjectBuildPath)  {remove-item $ProjectBuildPath -Recurse -Force}
    New-Item -ItemType Directory $ProjectBuildPath -force | out-string
}

task Version {
    #This task determines what version number to assign this build
    $GitVersionConfig = "$env:BHProjectPath/GitVersion.yml"

    #Fetch GitVersion
    $GitVersionCMDPackageName = "GitVersion.CommandLine"
    if (!(Get-Package $GitVersionCMDPackageName)) {
        Install-Package $GitVersionCMDPackageName -scope currentuser -verbose
    }
    $GitVersionEXE = ((get-package "gitversion.commandline").source | split-path -Parent) + "\tools\GitVersion.exe"

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
    $GitVersionInfo = Invoke-Expression "$GitVersionEXE $env:BHProjectPath" | ConvertFrom-JSON
    $Script:ProjectBuildVersion = [Version] $GitVersionInfo.MajorMinorPatch
    $Script:ProjectSemVersion = $($GitVersionInfo.fullsemver)
    write-host -ForegroundColor Green "Using Project Version: $ProjectBuildVersion"
    write-host -ForegroundColor Green "Using Extended Project Version: $($GitVersionInfo.fullsemver)"
}

#Copy all powershell module "artifacts" to Build Directory 
task CopyFilesToBuildDir {
    copy-item -Recurse "Public","Private","Traverse.ps*","License.TXT","README.md" $ProjectBuildPath -verbose
}

#Update the Metadata of the Module with the latest Version
task UpdateMetadata CopyFilesToBuildDir,Version, {
    # Load the module, read the exported functions, update the psd1 FunctionsToExport
    Set-ModuleFunctions $ProjectBuildPath -verbose
    # Set the Module Version to the calculated Project Build version
    Update-Metadata -Path ($ProjectBuildPath + "\" + (split-path $env:BHPSModuleManifest -leaf)) -PropertyName ModuleVersion -Value $ProjectBuildVersion


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
    $PesterResultFile = "$($env:BHBuildOutput)\$($env:BHProjectName)-TestResults_PS$PSVersion`_$TimeStamp.xml"
    $PesterResult = Invoke-Pester -OutputFormat "NUnitXml" -OutputFile $PesterResultFile -PassThru

    # In Appveyor?  Upload our test results!
    If($APPVEYOR)
    {
        (New-Object 'System.Net.WebClient').UploadFile(
            "https://ci.appveyor.com/api/testresults/nunit/$($env:APPVEYOR_JOB_ID)",
            $PesterResultFile )
    }

    # Failed tests?
    # Need to error out or it will proceed to the deployment. Danger!
    if($TestResults.FailedCount -gt 0)
    {
        Write-Error "Failed '$($TestResults.FailedCount)' tests, build failed"
    }
    "`n"
}


#Build SuperTask
task Build CopyFilesToBuildDir,UpdateMetadata

#Test SuperTask
task Test Pester

#Default Task - Build, Test with Pester, Deploy
task . Clean,Build,Test

