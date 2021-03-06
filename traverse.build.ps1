#requires -version 5
#Build Script for Traverse Powershell Module
#Uses Invoke-Build (https://github.com/nightroman/Invoke-Build)
#Run by changing to the project root directory and run ./Invoke-Build.ps1
#Uses a master-always-deploys strategy and semantic versioning - http://nvie.com/posts/a-successful-git-branching-model/

#This variable specifies what modules to bootstrap for the build
#It is recommended to only bootstrap BuildHelpers and PSDepend, and use PSDepend for remaining prereqs
$BuildHelperModules = "BuildHelpers", "PSDepend", "Pester", "powershell-yaml", "Microsoft.Powershell.Archive"

#Initialize Build Environment
Enter-Build {
    $lines = '----------------------------------------------------------------'
    function Write-VerboseHeader ([String]$Message) {
        #Simple function to add lines around a header
        
        write-verbose ""
        write-verbose $lines
        write-verbose $Message
        write-verbose $lines
    }

    #If we are in a continuous integration environment (Appveyor, etc.)
    if ($ENV:CI) {
        write-build Green 'Detected a CI environment, disabling prompt confirmations'
        $SCRIPT:CI = $true
        $ConfirmPreference = 'None'
    }

    #Fetch Build Helper Modules using Install-ModuleBootstrap script (works in PSv3/4)
    #The comma in ArgumentList a weird idiosyncracy to make sure a nested array is created to ensure Argumentlist 
    #doesn't unwrap the buildhelpermodules as individual arguments
    write-verboseheader 'Bootstrapping Powershell Modules: $BuildHelperModules'
    Invoke-Command -ArgumentList @(, $BuildHelperModules) -ScriptBlock ([scriptblock]::Create((new-object net.webclient).DownloadString('https://git.io/PSModBootstrap'))) 
    
    #Initialize helpful build environment variables
    $Timestamp = Get-date -uformat "%Y%m%d-%H%M%S"
    $PSVersion = $PSVersionTable.PSVersion.Major
    Set-BuildEnvironment -force

    $PassThruParams = @{}
    
    #If the branch name is master-test, run the build like we are in "master"
    if ($env:BHBranchName -eq 'master-test') {
        write-build Magenta "Detected master-test branch, running as if we were master"
        $SCRIPT:BranchName = "master"
    } else {
        $SCRIPT:BranchName = $env:BHBranchName
    }

    #We suppress verbose output for master builds (because they should have already been built once cleanly)
    if ( ($VerbosePreference -ne 'SilentlyContinue') -or ($CI -and ($BranchName -ne 'master')) ) {
        write-build Green "Verbose Build Logging Enabled"
        $SCRIPT:VerbosePreference = "Continue"
        $PassThruParams.Verbose = $true
    }

    write-verboseheader "Build Environment Prepared! Environment Information:"
    Get-BuildEnvironment | format-list | out-string | write-verbose

    write-verboseheader "Current Environment Variables" 
    get-childitem env: | out-string | write-verbose

    write-verboseheader "Powershell Variables"
    Get-Variable | select-object name, value, visibility | format-table -autosize | out-string | write-verbose

    if ($ENV:APPVEYOR) {
        write-verboseheader "Detected that we are running in Appveyor! Appveyor Environment Info:"
        get-item env:/Appveyor* | out-string | write-verbose
    }

    #Register Nuget
    if (!(get-packageprovider "Nuget" -ForceBootstrap -ErrorAction silentlycontinue)) {
        write-verbose "Nuget Provider Not found. Fetching..."
        Install-PackageProvider Nuget -forcebootstrap -scope currentuser @PassThruParams | out-string | write-verbose
        write-verboseheader "Installed Nuget Provider Info"
        Get-PackageProvider Nuget @PassThruParams | format-list | out-string | write-verbose
    }

    #Add the nuget repository so we can download things like GitVersion
    if (!(Get-PackageSource "nuget.org" -erroraction silentlycontinue)) {
        write-verbose "Registering nuget.org as package source"
        Register-PackageSource -provider NuGet -name nuget.org -location http://www.nuget.org/api/v2 -Trusted @PassThruParams  | out-string | out-verbose
    }
    else {
        $nugetOrgPackageSource = Set-PackageSource -name 'nuget.org' -Trusted @PassThruParams
        if ($PassThruParams.Verbose) {
            write-verboseheader "Nuget.Org Package Source Info "
            $nugetOrgPackageSource | format-table | out-string | write-verbose
        }
        
    }

    #Move to the Project Directory if we aren't there already
    Set-Location $ENV:BHProjectPath

    #Define the Project Build Path
    $SCRIPT:ProjectBuildPath = $ENV:BHBuildOutput + "\" + $ENV:BHProjectName
    Write-Build Green "Module Build Output Path: $ProjectBuildPath"
}

task Clean {
    #Reset the BuildOutput Directory
    if (test-path $env:BHBuildOutput) {
        write-verbose "Removing and resetting $($ENV:BHBuildOutput)"
        remove-item $env:BHBuildOutput -Recurse -Force @PassThruParams
    }
    New-Item -ItemType Directory $ProjectBuildPath -force | % FullName | out-string | write-verbose

    #Unmount any modules named the same as our module
    
}

task Version {
    #This task determines what version number to assign this build
    $GitVersionConfig = "$env:BHProjectPath/GitVersion.yml"

    #Fetch GitVersion
    #TODO: Use Nuget.exe to fetch to make this v3/v4 compatible
    $GitVersionCMDPackageName = "gitversion.commandline"
    if (!(Get-Package $GitVersionCMDPackageName -erroraction SilentlyContinue)) {
        write-verbose "Package $GitVersionCMDPackageName Not Found Locally, Installing..."
        write-verboseheader "Nuget.Org Package Source Info for fetching Gitversion"
        Get-PackageSource | ft | out-string | write-verbose

        #Fetch GitVersion
        Install-Package $GitVersionCMDPackageName -scope currentuser -source 'nuget.org' -force @PassThruParams
    }
    $GitVersionEXE = ((get-package $GitVersionCMDPackageName).source | split-path -Parent) + "\tools\GitVersion.exe"

    #Does this project have a module manifest? Use that as the Gitversion starting point (will use this by default unless project is tagged higher)
    #Uses Powershell-YAML module to read/write the GitVersion.yaml config file
    if (Test-Path $env:BHPSModuleManifest) {
        write-verbose "Fetching Version from Powershell Module Manifest (if present)"
        $ModuleManifestVersion = [Version](Get-Metadata $env:BHPSModuleManifest)
        if (Test-Path $env:BHProjectPath/GitVersion.yml) {
            $GitVersionConfigYAML = [ordered]@{} 
            #ConvertFrom-YAML returns as individual key-value hashtables, we need to combine them into a single hashtable
            (Get-Content $GitVersionConfig | ConvertFrom-Yaml) | foreach-object {$GitVersionConfigYAML += $PSItem}
            $GitVersionConfigYAML.'next-version' = $ModuleManifestVersion.ToString()
            $GitVersionConfigYAML | ConvertTo-Yaml | Out-File $GitVersionConfig
        }
        else {
            @{"next-version" = $ModuleManifestVersion.toString()} | ConvertTo-Yaml | Out-File $GitVersionConfig
        }
    }

    #Calcuate the GitVersion
    write-verbose "Executing GitVersion to determine version info"
    $GitVersionOutput = & $GitVersionEXE $env:BHProjectPath

    #Since GitVersion doesn't return error exit codes, we look for error text in the output in the output
    if ($GitVersionOutput -match '^[ERROR|INFO] \[') {throw "An error occured when running GitVersion.exe $env:BHProjectPath"}
    try {
        $GitVersionInfo = $GitVersionOutput | ConvertFrom-JSON -ErrorAction stop
    } catch {
        throw "There was an error when running GitVersion.exe $env:BHProjectPath. The output of the command (if any) follows:"
        $GitVersionOutput
    }

    write-verboseheader "GitVersion Results"
    $GitVersionInfo | format-list | out-string | write-verbose
    
    #If we are in the develop branch, add the prerelease number as revision
    #TODO: Make the develop and master regex customizable in a settings file
    if ($BranchName -match '^dev(elop)?(ment)?$') {
        $SCRIPT:ProjectBuildVersion = ($GitVersionInfo.MajorMinorPatch + "." + $GitVersionInfo.PreReleaseNumber)
    } else {
        $SCRIPT:ProjectBuildVersion = [Version] $GitVersionInfo.MajorMinorPatch
    }


    $SCRIPT:ProjectSemVersion = $($GitVersionInfo.fullsemver)
    write-build Green "Using Project Version: $ProjectBuildVersion"
    write-build Green "Using Project Version (Extended): $($GitVersionInfo.fullsemver)"
}

#Copy all powershell module "artifacts" to Build Directory 
task CopyFilesToBuildDir {
    $FilesToCopy = "Public","Private","$($Env:BHProjectName).psm1","$($Env:BHProjectName).psd1",".\LICENSE.TXT","README.md"
    copy-item -Recurse -Path $FilesToCopy -Destination $ProjectBuildPath @PassThruParams 
}

#Update the Metadata of the Module with the latest Version
task UpdateMetadata CopyFilesToBuildDir,Version,{
    # Load the module, read the exported functions, update the psd1 FunctionsToExport
    Set-ModuleFunctions $ProjectBuildPath @PassThruParams

    # Set the Module Version to the calculated Project Build version
    Update-Metadata -Path ($ProjectBuildPath + "\" + (split-path $env:BHPSModuleManifest -leaf)) -PropertyName ModuleVersion -Value $ProjectBuildVersion
    
    # Are we in the master or develop/development branch? Bump the version based on the powershell gallery if so, otherwise add a build tag
    write-build Yellow "BranchName: $BranchName"
    if ($BranchName -match '^(master|dev(elop)?(ment)?)$') {
        write-build Green "In Master/Develop branch, adding Tag Version $ProjectBuildVersion to this build"
        $Script:ProjectVersion = $ProjectBuildVersion
        if (-not (git tag -l $ProjectBuildVersion)) {
            git tag "$ProjectBuildVersion"
        } else {
            write-warning "Tag $ProjectBuildVersion already exists. This is normal if you are running multiple builds on the same commit, otherwise this should not happen"
        }
        <# TODO: Add some intelligent logic to tagging releases
        if (-not $CI) {
            git push origin $ProjectBuildVersion | write-verbose
        }
        #>
        <# TODO: Add a Powershell Gallery Check on the module
        if (Get-NextNugetPackageVersion -Name (Get-ProjectName) -ErrorAction SilentlyContinue) {
            Update-Metadata -Path $env:BHPSModuleManifest -PropertyName ModuleVersion -Value (Get-NextNugetPackageVersion -Name (Get-ProjectName))
        }
        #>
    } else {
        write-build Green "Not in Master/Develop branch, marking this as a feature prelease build"
        $Script:ProjectVersion = $ProjectSemVersion
        if (-not (git tag -l "$ProjectSemVersion")) {
            exec { git tag "$ProjectSemVersion" -a -m "Automatic GitVersion Prerelease Tag Generated by Invoke-Build" }
        } else {
            write-warning "Tag $ProjectSemVersion already exists. This is normal if you are running multiple builds on the same commit, otherwise this should not happen"
        }

        #Create an empty file in the root directory of the module for easy identification that its not a valid release.
        "This is a prerelease build and not meant for deployment!" > (Join-Path $ProjectBuildPath "PRERELEASE-$ProjectSemVersion")
    }

    # Add Release Notes from current version
    # TODO: Generate Release Notes from Github
    #Update-Metadata -Path $env:BHPSModuleManifest -PropertyName ReleaseNotes -Value ("$($env:APPVEYOR_REPO_COMMIT_MESSAGE): $($env:APPVEYOR_REPO_COMMIT_MESSAGE_EXTENDED)")
}

#Pester Testing
task Pester {
    "Starting Pester Tests..."
    $PesterResultFile = "$($env:BHBuildOutput)\$($env:BHProjectName)-TestResults_PS$PSVersion`_$TimeStamp.xml"
    $PesterResult = Invoke-Pester -OutputFormat "NUnitXml" -OutputFile $PesterResultFile -PassThru

    # In Appveyor?  Upload our test results!
    If ($ENV:APPVEYOR) {
        $UploadURL = "https://ci.appveyor.com/api/testresults/nunit/$($env:APPVEYOR_JOB_ID)"
        write-verbose "Detected we are running in AppVeyor"
        write-verbose "Uploading Pester Results to $UploadURL"
        (New-Object 'System.Net.WebClient').UploadFile(
            "https://ci.appveyor.com/api/testresults/nunit/$($env:APPVEYOR_JOB_ID)",
            $PesterResultFile )
    }

    # Failed tests?
    # Need to error out or it will proceed to the deployment. Danger!
    if ($TestResults.FailedCount -gt 0) {
        Write-Error "Failed '$($TestResults.FailedCount)' tests, build failed"
    }
    "`n"
}

task PackageArtifacts Version,{
    $ZipArchivePath = (join-path $env:BHBuildOutput "$env:BHProjectName-$ProjectVersion.zip")
    write-build green "Writing Finished Module to $ZipArchivePath"
    #Package the Powershell Module
    Compress-Archive -Path $ProjectBuildPath -DestinationPath $ZipArchivePath -Force @PassThruParams

    #If we are in Appveyor, push completed zip to Appveyor Artifact
    if ($env:APPVEYOR) {
        write-host -ForegroundColor Green "Detected Appveyor, pushing Powershell Module archive to Artifacts"
        Push-AppveyorArtifact $ZipArchivePath
    }
}

#Deploy Supertask
task Deploy PackageArtifacts

#Build SuperTask
task Build Clean,CopyFilesToBuildDir,UpdateMetadata

#Test SuperTask
task Test Pester

#Default Task - Build, Test with Pester, Deploy
task . Clean,Build,Test,Deploy