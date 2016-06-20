function Get-TraverseMonitorConfig {
<#
.SYNOPSIS
Retrieves the shared monitor configurations (including credentials)

.DESCRIPTION
This command obtains all the shared monitor credentials used in tests. It can be used to retrieve `
the information about a shared configuration.

.NOTES
While this command retrieves the credentials securely via SSL, it does display credentials in cleartext, `
so be VERY CAREFUL you are running this command in a protected environment where `
the display of credentials in plaintext on the screen is not a risk, and that your `
computer is free of viruses or HTTPS MITM proxies that might be able to snatch the `
credentials as they come into your environment.

.EXAMPLE
Get-TraverseMonitorConfig
serialNumber       : 1111111
name               : WMI: test\testconfig
type               : wmi
description        : WMI: My test Configuration
created            : Wednesday, December 23, 2015 2:31:03 PM PST
accountName        : MyTestAccount
parameters         : {@{label=Domain\Username; name=username; value=test\testuser; type=TEXT}, @{label=Password; name=password; 
                     value=MyTestPassw0rd; type=TEXT}}
monitorConfigUsage : @{testCount=449; devices=System.Object[]}

#>

    [CmdletBinding()]

    param (
    ) # Param

#region Main
    process {
        $TraverseCommandParams = @{
            API="JSON"
            Verbose=($PSBoundParameters['Verbose'] -eq $true)
            ArgumentList=@{}
        }

       (Invoke-TraverseCommand -Command 'admin/monitorConfig/list' @TraverseCommandParams).configAccounts.monitorConfigs
    }

#endregion Main

} #Get-TraverseDevice


