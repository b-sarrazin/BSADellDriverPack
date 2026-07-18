<#
	.SYNOPSIS
		Download CAB file by model, operating system, architecture

	.DESCRIPTION
		Download CAB file by model, operating system, architecture

	.PARAMETER DriverCatalog
		Driver Pack Catalog download address

	.PARAMETER DownloadFolder
		path to the CAB file download folder

	.PARAMETER MonthsBack
		download drivers pack newer than  X month. 0 equal no time limit

	.PARAMETER DriversPath
		A description of the DriversPath parameter.

	.NOTES
		===========================================================================
		Created with: 	SAPIEN Technologies, Inc., PowerShell Studio 2018 v5.5.155
		Created on:   	12/10/2018 10:42
		Created by:   	Brice SARRAZIN
		Organization:
		Filename:     	Get-DriversPackFromDell
		===========================================================================
#>
[CmdletBinding(SupportsShouldProcess = $true)]
param
(
	[Parameter(HelpMessage = @'
Driver Pack Catalog download address.
Default is "http://downloads.dell.com/catalog/DriverPackCatalog.cab"
'@)]
	[ValidateNotNullOrEmpty()]
	[string]$DriverCatalog = 'http://downloads.dell.com/catalog/DriverPackCatalog.cab',
	[Parameter(HelpMessage = @'
Path to the folder where the drivers pack will be downloaded.
Certain variables can be used to sort drivers pack into download folder (but don''t expand variables in the parameter!).
Default is "$PSScriptRoot\Drivers".
Example : "C:\PathToScript\Drivers".
'@)]
	[ValidateNotNullOrEmpty()]
	[string]$DownloadFolder = "$PSScriptRoot\Drivers",
	[Parameter(HelpMessage = @'
Folder structure to sort drivers pack into download folder.
Leave empty to save drivers pack into the root of the download folder.
Default structure is "$($package.OperatingSystems)\$($package.Models)\$($package.Architectures)".
Example : "Windows11\Latitude E7470\X64".
'@)]
	[string]$DriversStructure = '$($package.OperatingSystems)\$($package.Models)\$($package.Architectures)',
	[Parameter(HelpMessage = @'
Download drivers pack newer than  X month.
Default is 0 (no time limit).
'@)]
	[ValidateRange(0, 240)]
	[int]$MonthsBack = 0,
	[Parameter(HelpMessage = @'
Don''t create symbolic link.
Drivers pack could be downloaded multiple times depending on your folder structure.
'@)]
	[switch]$NoSymbolicLink
)

DynamicParam {
	# Dynamic parameters
	$parametersName = 'Models', 'OperatingSystems', 'Architectures'
	$runtimeParameterDictionary = New-Object System.Management.Automation.RuntimeDefinedParameterDictionary

	foreach ($parameterName in $parametersName) {
		Write-Debug "Creating dynamic parameter : $parameterName"
		$attributeCollection = New-Object System.Collections.ObjectModel.Collection[System.Attribute]
		$parameterAttribute = New-Object System.Management.Automation.parameterAttribute
		$attributeCollection.Add($parameterAttribute)
		if (Test-Path "$PSScriptRoot\$parameterName.txt") {
			$arrSet = Get-Content -Path "$PSScriptRoot\$parameterName.txt"
		} else {
			$arrSet = ''
		}
		$validateSetAttribute = New-Object System.Management.Automation.validateSetAttribute($arrSet)
		$attributeCollection.Add($validateSetAttribute)
		$runtimeParameter = New-Object System.Management.Automation.RuntimeDefinedParameter($parameterName, [array], $attributeCollection)
		$PSBoundParameters[$parameterName] = '*'

		$runtimeParameterDictionary.Add($parameterName, $runtimeParameter)
		Write-Debug "Dynamic parameter created : $parameterName"
	}
	return $runtimeParameterDictionary
}


BEGIN {
	# Load testable helper functions (Test-PackageHash, Get-PackageFilterMatch, Test-NewerPackage)
	. "$PSScriptRoot\DriversPack.Helpers.ps1"

	# Check NoSymbolicLink parameter
	if ($NoSymbolicLink) {
		Write-Host 'Symbolic link creation is disabled' -ForegroundColor Yellow
	} else {
		# Check if the script is running as administrator
		$isAdmin = [bool](([System.Security.Principal.WindowsIdentity]::GetCurrent()).groups -match 'S-1-5-32-544')
		if (-not $script:isAdmin) {
			Write-Host 'Please run this script as administrator or use -NoSymbolicLink parameter.' -ForegroundColor Red
			Write-Host 'Administrator privileges are required to create symbolic links.' -ForegroundColor Red
			Exit 1
		}
	}

	# Initialize variables
	$currentOperation = 0
	$totalOperations = 0
	$percentComplete = 0

	Write-Host 'Updating models, operating systems and architectures variables... ' -NoNewline
	$models = $PSBoundParameters['Models']
	$operatingSystems = $PSBoundParameters['OperatingSystems']
	$architectures = $PSBoundParameters['Architectures']
	Write-Host 'OK' -ForegroundColor Green

	Write-Host 'Checking download folder... ' -NoNewline
	if (-not (Test-Path $DownloadFolder)) {
		try {
			New-Item -Path $DownloadFolder -ItemType Directory -ErrorAction Stop | Out-Null
			Write-Host 'OK' -ForegroundColor Green
		} catch {
			Write-Host 'KO' -ForegroundColor Red
			Write-Host $_.Exception.Message -ForegroundColor Red
		}
	} else {
		Write-Host 'OK' -ForegroundColor Green
	}
}


PROCESS {

	#region functions
	function Write-MyProgress {
		param(
			[Parameter(Mandatory = $true)]
			[string]$Activity,
			[Parameter(Mandatory = $false)]
			[string]$Status
		)

		$otherOperations = 3

		if ($script:totalOperations -eq 0) {
			$script:totalOperations = $otherOperations + $catalog.DriverPackManifest.DriverPackage.Count - 1
		}

		$script:percentComplete = [math]::Round(($script:currentOperation++ / $script:totalOperations) * 100)

		if (!$Status) {
			$Status = "Step $script:currentOperation / $script:totalOperations"
		}

		Write-Progress -Activity $Activity -Status $Status -PercentComplete $script:percentComplete
	}


	function Test-ExistingPackage {
		[CmdletBinding()]
		param (
			[ValidateNotNullOrEmpty()]
			[PSCustomObject]$Package = $package
		)

		# Check if the package is already downloaded
		$existingPackages = Get-ChildItem -Path $DownloadFolder -Filter $Package.name -Recurse -ErrorAction SilentlyContinue
		$refPackage = $null

		# Search for the first valid existing package
		foreach ($existingPackage in $existingPackages) {
			if (Test-PackageHash -FilePath $existingPackage.FullName -FileHash $Package.hash) {
				$refPackage = $existingPackage
				break
			}
		}

		# return $false if no valid existing package
		if (!$refPackage) {
			return $false
		}

		# Iterate existing packages, replace by a copy or link of the reference package
		foreach ($existingPackage in $existingPackages) {

			# Skip the reference package
			if ($existingPackage.FullName -eq $refPackage.FullName) {
				continue
			}

			# Remove if corrupted
			if (-not (Test-PackageHash -FilePath $existingPackage.FullName -FileHash $Package.hash)) {
				Write-Host "Removing corrupted package : $($existingPackage.Name)... " -NoNewline
				Remove-Item -Path $existingPackage.FullName -Force -ErrorAction Stop | Out-Null
				Write-Host 'OK' -ForegroundColor Green
			}

			if ($NoSymbolicLink) {

				# Copy the reference package
				Copy-Item -Path $refPackage.FullName -Destination $existingPackage.FullName -Force -ErrorAction Stop
			} else {
				# Create a symbolic link to the reference package
				New-Item -ItemType SymbolicLink -Path $existingPackage.FullName -Value $refPackage.FullName -Force -ErrorAction Stop | Out-Null
			}
		}

		return $true
	}

	function Get-Package {
		[CmdletBinding()]
		param (
			[Parameter(Mandatory = $true)]
			[ValidateNotNullOrEmpty()]
			[PSCustomObject]$package
		)

		$bitsTransferProps = @{
			DisplayName = 'Downloading ' + $package.name + ' for'
			Description = $package.models + ' - ' + $package.operatingSystems + ' ' + $package.architectures
			Source      = $package.uri
			Destination = $package.path
		}

		Start-BitsTransfer @bitsTransferProps -ErrorAction Stop
		return Test-PackageHash -FilePath $package.path -FileHash $package.hash
	}

	#endregion


	#region Driver Pack Catalog
	Write-Host "Downloading Driver Pack Catalog (CAB) from $DriverCatalog... " -NoNewline
	try {
		$driverCatalogFilename = Split-Path -Path $DriverCatalog -Leaf
		$temp = "$env:TEMP\$([guid]::NewGuid())"
		New-Item -Path $temp -ItemType Directory -ErrorAction Stop | Out-Null
		Start-BitsTransfer -DisplayName 'Driver Pack Catalog (CAB)' -Description "$DriverCatalog" -Source $DriverCatalog -Destination $temp -ErrorAction Stop
		Write-Host 'OK' -ForegroundColor Green
	} catch {
		Write-Host 'KO' -ForegroundColor Red
		Write-Host $_.Exception.Message -ForegroundColor Red
	}

	Write-Host 'Expanding Driver Pack Catalog (CAB to XML)... ' -NoNewline
	try {
		$cabCatalogTempPath = Join-Path -Path $temp -ChildPath $driverCatalogFilename
		$oShell = New-Object -ComObject Shell.Application
		$sourceFile = $oShell.Namespace("$cabCatalogTempPath").items()
		$destinationFolder = $oShell.Namespace("$temp")
		$destinationFolder.CopyHere($sourceFile)
		Write-Host 'OK' -ForegroundColor Green
	} catch {
		Write-Host 'KO' -ForegroundColor Red
		Write-Host $_.Exception.Message -ForegroundColor Red
	}

	Write-Host 'Moving Driver Pack Catalog (XML) to download folder... ' -NoNewline
	try {
		$xmlCatalogFilename = $driverCatalogFilename.Replace('.cab', '.xml')
		$xmlCatalogTempPath = Join-Path -Path $temp -ChildPath $xmlCatalogFilename
		$xmlCatalogPath = Join-Path -Path $DownloadFolder -ChildPath $xmlCatalogFilename
		Move-Item -Path $xmlCatalogTempPath -Destination $xmlCatalogPath -ErrorAction Stop -Force | Out-Null
		Write-Host 'OK' -ForegroundColor Green
	} catch {
		Write-Host 'KO' -ForegroundColor Red
		Write-Host $_.Exception.Message -ForegroundColor Red
	}

	Write-Host 'Loading Driver Pack Catalog (XML)... ' -NoNewline
	$catalog = [xml](Get-Content $xmlCatalogPath)
	$uriRoot = 'http://' + $($catalog.DriverPackManifest | Select-Object -ExpandProperty baseLocation)
	Write-Host 'OK' -ForegroundColor Green
	#endregion


	#region Create/update attibute set for variables models, operatingSystems, architectures
	Write-MyProgress -Activity 'Updating models, operating systems and architectures variables'
	Write-Host 'Updating models, operating systems and architectures variables... ' -NoNewline
	[array]$supportedModels = @()
	[array]$supportedOS = @()
	[array]$supportedArch = @()
	$catalog.DriverPackManifest.DriverPackage | ForEach-Object {
		$supportedModels += $_.SupportedSystems.Brand.Model | Select-Object -ExpandProperty name
		$supportedOS += $_.SupportedOperatingSystems.OperatingSystem | Select-Object -ExpandProperty osCode
		$supportedArch += $_.SupportedOperatingSystems.OperatingSystem | Select-Object -ExpandProperty osArch
	}
	$supportedModels | Select-Object -Unique | Sort-Object | Set-Content "$PSScriptRoot\models.txt" -Force
	$supportedOS | Select-Object -Unique | Sort-Object | Set-Content "$PSScriptRoot\operatingSystems.txt" -Force
	$supportedArch | Select-Object -Unique | Sort-Object | Set-Content "$PSScriptRoot\architectures.txt" -Force
	Write-Host 'OK' -ForegroundColor Green
	#endregion


	# Create drivers pack list
	Write-MyProgress -Activity 'Creating drivers packs list'
	Write-Host 'Creating drivers packs list... ' -NoNewline
	$driversPacks = @()
	$catalog.DriverPackManifest.DriverPackage | ForEach-Object {

		$driversPacks += New-Object PSObject -Property @{
			name             = $_.Name.Display.'#cdata-section'
			format           = $_.format
			version          = $_.dellVersion
			models           = $_.SupportedSystems.Brand.Model.name | Select-Object -Unique
			operatingSystems = $_.SupportedOperatingSystems.OperatingSystem.osCode | Select-Object -Unique
			architectures    = $_.SupportedOperatingSystems.OperatingSystem.osArch | Select-Object -Unique
			date             = [datetime]$_.dateTime
			uri              = $uriRoot + '/' + $_.path
			path             = Join-Path -Path $DownloadFolder -ChildPath ($ExecutionContext.InvokeCommand.ExpandString($DriversStructure)) -AdditionalChildPath $_.Name.Display.'#cdata-section'
			hash             = $_.hashMD5
		}
	}
	Write-Host 'OK' -ForegroundColor Green

	# Filter drivers pack by date
	if ($MonthsBack -gt 0) {
		Write-MyProgress -Activity 'Filtering drivers pack by date'
		Write-Host "Filtering drivers pack by date (newer than $MonthsBack month(s))... " -NoNewline
		$monthsBackDate = [datetime]::Today.AddMonths(- $MonthsBack)
		$driversPacksBeforeFilter = $driversPacks.Count - 1
		$driversPacks = $driversPacks | Where-Object { $_.date -ge $monthsBackDate }
		$currentOperation = $currentOperation + ($driversPacksBeforeFilter - $driversPacks.Count - 1)
		Write-Host 'OK' -ForegroundColor Green
	}

	# Filter drivers pack by models, operating systems and architectures
	foreach ($package in $driversPacks) {

		Write-MyProgress -Activity 'Iterating drivers packages'
		Write-Host "Package $($package.name)" -ForegroundColor Yellow

		# Filter by models
		if ($models -ne '*') {
			Write-Host " - Filtering by models : $($package.models)... " -NoNewline
			$modelsFound = Get-PackageFilterMatch -PackageValues $package.models -FilterValues $models
			if (!$modelsFound) {
				$driversPacks = $driversPacks | Where-Object { $_.name -ne $package.name }
				Write-Host 'NOT FOUND' -ForegroundColor Yellow
				continue
			}
			Write-Host 'OK' -ForegroundColor Green
			Write-Debug "Model found : $($modelsFound -join ', ')"
		}

		# Filter by operating systems
		if ($operatingSystems -ne '*') {
			Write-Host " - Filtering by operating systems : $($package.operatingSystems)... " -NoNewline
			$operatingSystemsFound = Get-PackageFilterMatch -PackageValues $package.operatingSystems -FilterValues $operatingSystems
			if (!$operatingSystemsFound) {
				Write-Debug "Operating system not found : $($package.operatingSystems)"
				$driversPacks = $driversPacks | Where-Object { $_.name -ne $package.name }
				Write-Host 'NOT FOUND' -ForegroundColor Yellow
				continue
			}
			Write-Host 'OK' -ForegroundColor Green
			Write-Debug "Operating system found : $($package.operatingSystems -join ', ')"
		}

		# Filter by architectures
		if ($architectures -ne '*') {
			Write-Host " - Filtering by architectures : $($package.architectures)... " -NoNewline
			$architecturesFound = Get-PackageFilterMatch -PackageValues $package.architectures -FilterValues $architectures
			if (!$architecturesFound) {
				Write-Debug "Architecture not found : $($package.architectures)"
				$driversPacks = $driversPacks | Where-Object { $_.name -ne $package.name }
				Write-Host 'NOT FOUND' -ForegroundColor Yellow
				continue
			}
			Write-Host 'OK' -ForegroundColor Green
			Write-Debug "Architecture found : $($package.architectures)"
		}

		# All filters are OK

		Write-Host "Downloading package $($package.name)... " -NoNewline
		# Check if the package is already downloaded
		try {
			$packageAlreadyExists = Test-ExistingPackage -Package $package
		} catch {
			Write-Host 'KO' -ForegroundColor Red
			Write-Host $_.Exception.Message -ForegroundColor Red
			continue
		}
		if ($packageAlreadyExists) {
			Write-Host 'Already downloaded' -ForegroundColor Green
			continue
		}

		# Download drivers pack
		try {
			$bitsTransferProps = @{
				DisplayName = 'Downloading ' + $package.name + ' for'
				Description = $package.models + ' - ' + $package.operatingSystems + ' ' + $package.architectures
				Source      = $package.uri
				Destination = Split-Path -Path $package.path
				ErrorAction = 'Stop'
			}
			if (!(Test-Path $bitsTransferProps.Destination)) {
				New-Item -Path $bitsTransferProps.Destination -ItemType Directory -ErrorAction Stop | Out-Null
			}
			Start-BitsTransfer @bitsTransferProps

			# Check file hash
			if (Test-PackageHash -FilePath $package.path -FileHash $package.hash) {
				Write-Host 'OK' -ForegroundColor Green
			} else {
				throw "File hash mismatch for package $($package.name)"
			}
		} catch {
			Write-Host 'KO' -ForegroundColor Red
			Write-Host $_.Exception.Message -ForegroundColor Red

			# Remove corrupted package
			if (Test-Path $package.path) {
				try {
					Write-Host "Removing corrupted package : $($package.name)... "
					Remove-Item -Path $package.path -Force -ErrorAction Stop | Out-Null
					Write-Host 'OK' -ForegroundColor Green
				} catch {
					Write-Host 'KO' -ForegroundColor Red
					Write-Host $_.Exception.Message -ForegroundColor Red
				}
			}
		}
	}
}
END {
	$Filter = '*.CAB'
	$LocalCABs = Get-Item $(Join-Path $DownloadFolder $Filter) -ErrorAction SilentlyContinue | Sort-Object Name | Select-Object -ExpandProperty Name

	if ($LocalCABs) {
		foreach ($CurrentCAB in $LocalCABs) {

			$Filter = $CurrentCAB.Split('-')[0] + '-' + $CurrentCAB.Split('-')[1] + '-*-*'

			Get-Item $(Join-Path $DownloadFolder $Filter) -ErrorAction SilentlyContinue | Select-Object -ExpandProperty Name |
			ForEach-Object {
				$oldCabName = $_

				if (Test-NewerPackage -CandidateName $CurrentCAB -ReferenceName $oldCabName) {
					try {
						Write-Host "Removing old package : $oldCabName"
						Remove-Item -Path $(Join-Path $DownloadFolder $oldCabName) -Force -ErrorAction Stop | Out-Null
					} catch {
						Write-Warning "Failed to remove $(Join-Path $DownloadFolder $oldCabName) : $($_.Exception.Message)"
					}
				}
			}
		}
	}
}
