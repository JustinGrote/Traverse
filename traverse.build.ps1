#requires -version 5
#Build Script for Traverse Powershell Module
#Uses Invoke-Build (https://github.com/nightroman/Invoke-Build)
#Run by changing to the project root directory and run ./Invoke-Build.ps1
#Uses a master-always-deploys strategy and semantic versioning - http://nvie.com/posts/a-successful-git-branching-model/

#Initialize Build Environment
Enter-Build {
    
    $BuildHelperModules = "BuildHelpers","PSDeploy","Pester","powershell-yaml"
    #Fetch Build Helper Modules using Install-ModuleBootstrap script
    #The comma in ArgumentList a weird idiosyncracy to make sure a nested array is created to ensure Argumentlist 
    #doesn't unwrap the buildhelpermodules as individual arguments
    Invoke-Command -ArgumentList @(,$BuildHelperModules) -ScriptBlock ([scriptblock]::Create((new-object net.webclient).DownloadString('http://tinyurl.com/PSIMB'))) 
    
    #Initialize helpful build environment variables
    $Timestamp = Get-date -uformat "%Y%m%d-%H%M%S"
    $PSVersion = $PSVersionTable.PSVersion.Major
    Set-BuildEnvironment -force

    write-verbose "Build Environment Prepared! Environment Information:"
    write-verbose "-------------------------------"
    write-verbose Get-BuildEnvironment | fl | out-string | write-verbose


    $PassThruParams = @{}

    write-verbose "Verbose Build Logging Enabled"
    $PassThruParams.Verbose = $true

    write-verbose "Setting up Build Environment..."
    write-verbose "Environment Variables" 
    write-verbose "---------------------"
    get-childitem env: | out-string | write-verbose

    write-verbose "Powershell Variables"
    write-verbose "--------------------"
    Get-Variable | select-object name,value,visibility | format-table -autosize | out-string | write-verbose   

    write-verbose "Nuget Package Providers"
    write-verbose "-----------------"
    Get-PackageProvider -listavailable | write-verbose
    

    if ($APPVEYOR) {
        write-verbose "Detected that we are running in Appveyor!"
        write-verbose "AppVeyor Environment Information:"
        write-verbose "-----------------"
        get-item env:/Appveyor* | out-string | write-verbose
        write-verbose "PS Module Path: $PSModulePath"
    }

    #If we are in a CI (Appveyor/etc.), trust the powershell gallery for purposes of automatic module installation
    #We do this so that if running locally, you are still prompted to install software required by the build
    #If necessary. In a CI, we want it to happen automatically because it'll just be torn down anyways.
    if ($env:CI) {
        "Detected a CI environment, disabling prompt confirmations"
        $ConfirmPreference = "None"
    }


    #Register Nuget
    if (!(get-packageprovider "Nuget" -ForceBootstrap -ErrorAction silentlycontinue)) {
        write-verbose "Nuget Provider Not found. Fetching..."
        Install-PackageProvider Nuget -forcebootstrap -scope currentuser @PassThruParams | out-string | write-verbose

        write-verbose "Installed Nuget Provider Info"
        write-verbose "-----------------------------"
        Get-PackageProvider Nuget @PassThruParams | format-list | out-string | write-verbose
    }



    #Add the nuget repository so we can download things like GitVersion
    if (!(Get-PackageSource "nuget.org" -erroraction silentlycontinue)) {
        write-verbose "Registering nuget.org as package source"
        Register-PackageSource -provider NuGet -name nuget.org -location http://www.nuget.org/api/v2 -Trusted @PassThruParams  | out-string | out-verbose
    } else {
        Set-PackageSource -name 'nuget.org' -Trusted @PassThruParams | out-string | write-verbose
    }

    write-verbose "Nuget.Org Package Source Info "
    Get-PackageSource | format-table | out-string | write-verbose
    


    
    #Move to the Project Directory if we aren't there already
    Set-Location $env:BHProjectPath
    
    $Script:ProjectBuildPath = $env:BHBuildOutput + "\" + $env:BHProjectName

}

task Clean {
    #Reset the BuildOutput Directory
    if (test-path $ProjectBuildPath)  {remove-item $ProjectBuildPath -Recurse -Force @PassThruParams}
    New-Item -ItemType Directory $ProjectBuildPath -force | % FullName | out-string | write-verbose
}

task Version {
    #This task determines what version number to assign this build
    $GitVersionConfig = "$env:BHProjectPath/GitVersion.yml"

    write-verbose "Nuget.Org Package Source Info for fetching Gitversion"
    Get-PackageSource | fl | out-string | write-verbose

    #Fetch GitVersion
    $GitVersionCMDPackageName = "gitversion.commandline"
    if (!(Get-Package $GitVersionCMDPackageName -erroraction SilentlyContinue)) {
        write-verbose "Package $GitVersionCMDPackageName Not Found Locally, Installing..."
        $VerbosePreference = "continue"
        Install-Package $GitVersionCMDPackageName -scope currentuser -source 'nuget.org' -force @PassThruParams
    }
    $GitVersionEXE = ((get-package $GitVersionCMDPackageName).source | split-path -Parent) + "\tools\GitVersion.exe"

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
    copy-item -Recurse "Public","Private","Traverse.ps*","License.TXT","README.md" $ProjectBuildPath @PassThruParams
}

#Update the Metadata of the Module with the latest Version
task UpdateMetadata CopyFilesToBuildDir,Version, {
    # Load the module, read the exported functions, update the psd1 FunctionsToExport
    Set-ModuleFunctions $ProjectBuildPath @PassThruParams
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
task Build Clean,CopyFilesToBuildDir,UpdateMetadata

#Test SuperTask
task Test Pester

#Default Task - Build, Test with Pester, Deploy
task . Clean,Build,Test

