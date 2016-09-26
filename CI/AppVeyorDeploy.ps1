#Powershell Module Deployment Script

#Skip deployment if this is not a master branch commit and a version tag is not detected
if($env:APPVEYOR_REPO_BRANCH -and $env:APPVEYOR_REPO_BRANCH -notmatch 'master')
{
    write-host -ForegroundColor yellow "DEPLOY PHASE: Not master branch, skipping"
    exit
} elseif ($env:APPVEYOR_REPO_TAG_NAME -match 'v\d') {
    write-host -ForegroundColor yellow "DEPLOY PHASE: Publishing to Powershell Gallery"
    $env:NuGetAPIKey > C:\projects\apikey.txt
    Publish-Module -Name (Get-ProjectName) -NuGetApiKey $env:NuGetAPIKey
}