[Unofficial] Kaseya Traverse Powershell Module
-
[![Build status](https://ci.appveyor.com/api/projects/status/hyh1xb65ebiiovoi/branch/master?svg=true)](https://ci.appveyor.com/project/JustinGrote/traverse/branch/master)

This module provides a Powershell interface for the [Kaseya Traverse](http://traverse-monitoring.com) network monitoring platform.

This project is **first and foremost** a way to teach myself to build a Powershell module using the latest best practices, conventions, and modern continuous integration processes. As such, I accept pull requests but I'm not likely to address any outstanding issues or missing features that don't directly correlate with my own needs.

Installation
-
####[Powershell V5](https://www.microsoft.com/en-us/download/details.aspx?id=50395) and Later
You can install the Traverse module directly from the [Powershell Gallery](http://www.powershellgallery.com/packages/Traverse)

**Method 1** *[Recommended]*: Install to your personal Powershell Modules folder
```powershell
Install-Module ImportExcel -scope CurrentUser
```
**Method 2** *[Requires Elevation]*: Install for Everyone (computer Powershell Modules folder)
```powershell
Install-Module ImportExcel
```
####Powershell V4 and Earlier
To install to your personal modules folder (e.g. ~\Documents\WindowsPowerShell\Modules), run:

```powershell
iex (new-object System.Net.WebClient).DownloadString('https://raw.github.com/dfinke/ImportExcel/master/Install.ps1')
```

Getting Started
-

All commands have comment based help, so recommend starting with this:
```powershell
Get-Command -Module Traverse
Get-Help <command> -Full
```

Quick Start Commands
-
```powershell
Connect-Traversebve my.traversebve.com
Get-TraverseDevice
Get-TraverseTest -Device *
```
