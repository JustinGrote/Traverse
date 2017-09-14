# Upload Appveyor Artifacts if we're in AppVeyor
"Starting PSDeploy Appveyor Section"
if(
    $env:BHProjectName -and $ENV:BHProjectName.Count -eq 1 -and
    $env:BHBuildSystem -eq 'AppVeyor'
)
{
    "Detected AppVeyor environment. Pushing release to artifacts"
    Deploy Release {
        By AppVeyorModule {
            FromSource $ENV:BHProjectName
            To AppVeyor
            WithOptions @{
                Version = $env:APPVEYOR_BUILD_VERSION
            }
        }
    }
}