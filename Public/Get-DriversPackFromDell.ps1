<#
	.SYNOPSIS
		Download Dell driver packs (CAB files) filtered by model, operating system and architecture.

	.DESCRIPTION
		Downloads the Dell Driver Pack Catalog, then downloads every driver pack CAB
		file matching the requested models, operating systems and architectures.
		Packages already downloaded (and valid) are skipped, duplicate copies are
		created as hard links by default, and older versions of a package are
		removed once a newer one has been downloaded.

		Progress is reported via Write-Progress. Use -Verbose for a detailed,
		step-by-step trace of what the command is doing. Returns a summary
		object (packages considered/matched/downloaded/failed/removed) once done.

	.PARAMETER DriverCatalog
		Driver Pack Catalog download address.
		Default is "http://downloads.dell.com/catalog/DriverPackCatalog.cab"

	.PARAMETER DownloadFolder
		Path to the folder where the drivers pack will be downloaded.
		Certain variables can be used to sort drivers pack into download folder (but don't expand variables in the parameter!).
		Default is "$env:LOCALAPPDATA\BSADellDriverPack\Drivers".
		Example : "C:\Drivers".

	.PARAMETER DriversStructure
		Folder structure to sort drivers pack into download folder.
		Leave empty to save drivers pack into the root of the download folder.
		Default structure is "$($package.OperatingSystems)\$($package.Models)\$($package.Architectures)".
		Example : "Windows11\Latitude E7470\X64".

	.PARAMETER MonthsBack
		Download drivers pack newer than X month.
		Default is 0 (no time limit).

	.PARAMETER DuplicateHandling
		How to reconcile duplicate copies of the same package across the folder
		structure. 'HardLink' (default) requires no admin rights but source and
		destination must be on the same volume. 'SymbolicLink' requires admin
		rights. 'Copy' uses more disk space but works across volumes.

	.PARAMETER Models
		Filter drivers pack by model. Supports tab-completion once the catalog has been downloaded at least once. Default is every model.

	.PARAMETER OperatingSystems
		Filter drivers pack by operating system. Supports tab-completion once the catalog has been downloaded at least once. Default is every operating system.

	.PARAMETER Architectures
		Filter drivers pack by architecture. Supports tab-completion once the catalog has been downloaded at least once. Default is every architecture.

	.EXAMPLE
		Get-DriversPackFromDell -MonthsBack 12

		Download CAB files less than 12 months old.

	.EXAMPLE
		Get-DriversPackFromDell -Architectures x86, x64 -OperatingSystems Windows10, Windows7 -MonthsBack 6

		Download CAB files less than 6 months old corresponding to x86 or x64 architectures and Windows 7 or 10 operating systems.

	.EXAMPLE
		Get-DriversPackFromDell -Models 'Latitude 7370', 'Latitude 7490'

		Download CAB files corresponding to models Latitude 7370 or Latitude 7490.

	.EXAMPLE
		Get-DriversPackFromDell -MonthsBack 12 -Verbose

		Same as the first example, but with a detailed, step-by-step trace of every
		filtering and download decision.

	.NOTES
		Created by:   Brice SARRAZIN
		Filename:     Get-DriversPackFromDell.ps1
#>
function Get-DriversPackFromDell {
	[CmdletBinding(SupportsShouldProcess = $true)]
	param
	(
		[Parameter(HelpMessage = 'Driver Pack Catalog download address.')]
		[ValidateNotNullOrEmpty()]
		[string]$DriverCatalog = 'http://downloads.dell.com/catalog/DriverPackCatalog.cab',
		[Parameter(HelpMessage = 'Path to the folder where the drivers pack will be downloaded.')]
		[ValidateNotNullOrEmpty()]
		[string]$DownloadFolder = (Join-Path -Path $script:BSADellDriverPackDataPath -ChildPath 'Drivers'),
		[Parameter(HelpMessage = 'Folder structure to sort drivers pack into download folder.')]
		[string]$DriversStructure = '$($package.OperatingSystems)\$($package.Models)\$($package.Architectures)',
		[Parameter(HelpMessage = 'Download drivers pack newer than X month. Default is 0 (no time limit).')]
		[ValidateRange(0, 240)]
		[int]$MonthsBack = 0,
		[Parameter(HelpMessage = 'How to reconcile duplicate copies of the same package. Default is HardLink.')]
		[ValidateSet('HardLink', 'SymbolicLink', 'Copy')]
		[string]$DuplicateHandling = 'HardLink'
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
			$parameterCachePath = Join-Path -Path $script:BSADellDriverPackDataPath -ChildPath "$parameterName.txt"
			if (Test-Path $parameterCachePath) {
				$arrSet = Get-Content -Path $parameterCachePath
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
		Write-Verbose "Duplicate handling mode : $DuplicateHandling"
		if ($DuplicateHandling -eq 'SymbolicLink') {
			# Check if the script is running as administrator
			$isAdmin = [bool](([System.Security.Principal.WindowsIdentity]::GetCurrent()).groups -match 'S-1-5-32-544')
			if (-not $isAdmin) {
				throw 'Administrator privileges are required to create symbolic links. Run this command as administrator, or use -DuplicateHandling HardLink (default) or Copy.'
			}
		}

		# Initialize variables
		$script:currentOperation = 0
		$script:totalOperations = 0
		$script:percentComplete = 0
		$script:lastProgressUpdate = $null
		$packagesMatched = 0
		$packagesDownloaded = 0
		$packagesAlreadyDownloaded = 0
		$packagesFailed = 0

		$models = $PSBoundParameters['Models']
		$operatingSystems = $PSBoundParameters['OperatingSystems']
		$architectures = $PSBoundParameters['Architectures']
		Write-Verbose "Models filter : $models"
		Write-Verbose "OperatingSystems filter : $operatingSystems"
		Write-Verbose "Architectures filter : $architectures"

		Write-Progress -Activity 'Get-DriversPackFromDell' -Status 'Checking download folder'
		if (-not (Test-Path $DownloadFolder)) {
			try {
				New-Item -Path $DownloadFolder -ItemType Directory -ErrorAction Stop | Out-Null
				Write-Verbose "Created download folder : $DownloadFolder"
			} catch {
				Write-Warning "Failed to create download folder '$DownloadFolder' : $($_.Exception.Message)"
			}
		}
	}

	PROCESS {

		#region Driver Pack Catalog
		Write-Progress -Activity 'Get-DriversPackFromDell' -Status 'Downloading Driver Pack Catalog'
		try {
			$driverCatalogFilename = Split-Path -Path $DriverCatalog -Leaf
			$temp = "$env:TEMP\$([guid]::NewGuid())"
			New-Item -Path $temp -ItemType Directory -ErrorAction Stop | Out-Null
			Start-BitsTransfer -DisplayName 'Driver Pack Catalog (CAB)' -Description "$DriverCatalog" -Source $DriverCatalog -Destination $temp -ErrorAction Stop
			Write-Verbose "Downloaded Driver Pack Catalog (CAB) from $DriverCatalog"
		} catch {
			Write-Warning "Failed to download Driver Pack Catalog from '$DriverCatalog' : $($_.Exception.Message)"
		}

		Write-Progress -Activity 'Get-DriversPackFromDell' -Status 'Expanding Driver Pack Catalog'
		try {
			$cabCatalogTempPath = Join-Path -Path $temp -ChildPath $driverCatalogFilename
			$oShell = New-Object -ComObject Shell.Application
			$sourceFile = $oShell.Namespace("$cabCatalogTempPath").items()
			$destinationFolder = $oShell.Namespace("$temp")
			$destinationFolder.CopyHere($sourceFile)
			Write-Verbose 'Expanded Driver Pack Catalog (CAB to XML)'
		} catch {
			Write-Warning "Failed to expand Driver Pack Catalog : $($_.Exception.Message)"
		}

		Write-Progress -Activity 'Get-DriversPackFromDell' -Status 'Moving Driver Pack Catalog to download folder'
		try {
			$xmlCatalogFilename = $driverCatalogFilename.Replace('.cab', '.xml')
			$xmlCatalogTempPath = Join-Path -Path $temp -ChildPath $xmlCatalogFilename
			$xmlCatalogPath = Join-Path -Path $DownloadFolder -ChildPath $xmlCatalogFilename
			Move-Item -Path $xmlCatalogTempPath -Destination $xmlCatalogPath -ErrorAction Stop -Force | Out-Null
			Write-Verbose "Moved Driver Pack Catalog (XML) to $xmlCatalogPath"
		} catch {
			Write-Warning "Failed to move Driver Pack Catalog to download folder : $($_.Exception.Message)"
		}

		Write-Progress -Activity 'Get-DriversPackFromDell' -Status 'Loading Driver Pack Catalog'
		$script:catalog = [xml](Get-Content $xmlCatalogPath)
		$uriRoot = 'http://' + $($script:catalog.DriverPackManifest | Select-Object -ExpandProperty baseLocation)
		Write-Verbose 'Loaded Driver Pack Catalog (XML)'
		#endregion


		#region Create/update attibute set for variables models, operatingSystems, architectures
		Write-MyProgress -Activity 'Updating models, operating systems and architectures variables'
		# Member access on a collection flattens the property across every element,
		# so this collects every model/OS/architecture in one pass, without the
		# O(n^2) cost of growing an array with += inside a loop.
		[array]$supportedModels = @($script:catalog.DriverPackManifest.DriverPackage.SupportedSystems.Brand.Model.name)
		[array]$supportedOS = @($script:catalog.DriverPackManifest.DriverPackage.SupportedOperatingSystems.OperatingSystem.osCode)
		[array]$supportedArch = @($script:catalog.DriverPackManifest.DriverPackage.SupportedOperatingSystems.OperatingSystem.osArch)
		$supportedModels | Select-Object -Unique | Sort-Object | Set-Content (Join-Path -Path $script:BSADellDriverPackDataPath -ChildPath 'Models.txt') -Force
		$supportedOS | Select-Object -Unique | Sort-Object | Set-Content (Join-Path -Path $script:BSADellDriverPackDataPath -ChildPath 'OperatingSystems.txt') -Force
		$supportedArch | Select-Object -Unique | Sort-Object | Set-Content (Join-Path -Path $script:BSADellDriverPackDataPath -ChildPath 'Architectures.txt') -Force
		Write-Verbose "Updated models, operating systems and architectures variables ($($supportedModels.Count) models, $($supportedOS.Count) operating systems, $($supportedArch.Count) architectures)"
		#endregion


		# Create drivers pack list
		Write-MyProgress -Activity 'Creating drivers packs list'
		# Assigning the pipeline output directly (instead of += inside the loop)
		# avoids reallocating and copying the whole array on every package.
		$driversPacks = @($script:catalog.DriverPackManifest.DriverPackage | ForEach-Object {
			New-Object PSObject -Property @{
				name             = $_.Name.Display.'#cdata-section'
				format           = $_.format
				version          = $_.dellVersion
				models           = $_.SupportedSystems.Brand.Model.name | Select-Object -Unique
				operatingSystems = $_.SupportedOperatingSystems.OperatingSystem.osCode | Select-Object -Unique
				architectures    = $_.SupportedOperatingSystems.OperatingSystem.osArch | Select-Object -Unique
				date             = [datetime]$_.dateTime
				uri              = $uriRoot + '/' + $_.path
				path             = Join-Path -Path (Join-Path -Path $DownloadFolder -ChildPath ($ExecutionContext.InvokeCommand.ExpandString($DriversStructure))) -ChildPath $_.Name.Display.'#cdata-section'
				hash             = $_.hashMD5
			}
		})
		Write-Verbose "Created drivers packs list ($($driversPacks.Count) packages)"

		# Filter drivers pack by date
		if ($MonthsBack -gt 0) {
			Write-MyProgress -Activity 'Filtering drivers pack by date'
			$monthsBackDate = [datetime]::Today.AddMonths(- $MonthsBack)
			$driversPacksBeforeFilter = $driversPacks.Count - 1
			$driversPacks = $driversPacks | Where-Object { $_.date -ge $monthsBackDate }
			$script:currentOperation = $script:currentOperation + ($driversPacksBeforeFilter - $driversPacks.Count - 1)
			Write-Verbose "Filtered drivers pack by date (newer than $MonthsBack month(s)) : $($driversPacks.Count) package(s) remaining"
		}

		# Filter drivers pack by models, operating systems and architectures
		foreach ($package in $driversPacks) {

			Write-MyProgress -Activity 'Downloading driver packs' -Status $package.name
			Write-Verbose "Package $($package.name)"

			# Filter by models
			if ($models -ne '*') {
				$modelsFound = Get-PackageFilterMatch -PackageValues $package.models -FilterValues $models
				if (!$modelsFound) {
					Write-Verbose " - Models not matched : $($package.models)"
					continue
				}
				Write-Verbose " - Models matched : $($modelsFound -join ', ')"
			}

			# Filter by operating systems
			if ($operatingSystems -ne '*') {
				$operatingSystemsFound = Get-PackageFilterMatch -PackageValues $package.operatingSystems -FilterValues $operatingSystems
				if (!$operatingSystemsFound) {
					Write-Verbose " - Operating systems not matched : $($package.operatingSystems)"
					continue
				}
				Write-Verbose " - Operating systems matched : $($operatingSystemsFound -join ', ')"
			}

			# Filter by architectures
			if ($architectures -ne '*') {
				$architecturesFound = Get-PackageFilterMatch -PackageValues $package.architectures -FilterValues $architectures
				if (!$architecturesFound) {
					Write-Verbose " - Architectures not matched : $($package.architectures)"
					continue
				}
				Write-Verbose " - Architectures matched : $($architecturesFound -join ', ')"
			}

			# All filters are OK
			$packagesMatched++

			# Check if the package is already downloaded
			try {
				$packageAlreadyExists = Test-ExistingPackage -Package $package -DownloadFolder $DownloadFolder -DuplicateHandling $DuplicateHandling
			} catch {
				Write-Warning "Failed to check existing copies of package '$($package.name)' : $($_.Exception.Message)"
				$packagesFailed++
				continue
			}
			if ($packageAlreadyExists) {
				Write-Verbose "Package $($package.name) already downloaded"
				$packagesAlreadyDownloaded++
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
					Write-Verbose "Downloaded package $($package.name)"
					$packagesDownloaded++
				} else {
					throw "File hash mismatch for package $($package.name)"
				}
			} catch {
				Write-Warning "Failed to download package '$($package.name)' : $($_.Exception.Message)"
				$packagesFailed++

				# Remove corrupted package
				if (Test-Path $package.path) {
					try {
						Remove-Item -Path $package.path -Force -ErrorAction Stop | Out-Null
						Write-Verbose "Removed corrupted package : $($package.name)"
					} catch {
						Write-Warning "Failed to remove corrupted package '$($package.name)' : $($_.Exception.Message)"
					}
				}
			}
		}

		Write-Progress -Activity 'Downloading driver packs' -Completed
	}
	END {
		$packagesRemoved = 0
		$Filter = '*.CAB'
		$LocalCABs = Get-Item $(Join-Path $DownloadFolder $Filter) -ErrorAction SilentlyContinue | Sort-Object Name | Select-Object -ExpandProperty Name

		if ($LocalCABs) {
			Write-Progress -Activity 'Get-DriversPackFromDell' -Status 'Removing outdated packages'
			foreach ($CurrentCAB in $LocalCABs) {

				$Filter = $CurrentCAB.Split('-')[0] + '-' + $CurrentCAB.Split('-')[1] + '-*-*'

				Get-Item $(Join-Path $DownloadFolder $Filter) -ErrorAction SilentlyContinue | Select-Object -ExpandProperty Name |
				ForEach-Object {
					$oldCabName = $_

					if (Test-NewerPackage -CandidateName $CurrentCAB -ReferenceName $oldCabName) {
						try {
							Remove-Item -Path $(Join-Path $DownloadFolder $oldCabName) -Force -ErrorAction Stop | Out-Null
							Write-Verbose "Removed old package : $oldCabName"
							$packagesRemoved++
						} catch {
							Write-Warning "Failed to remove $(Join-Path $DownloadFolder $oldCabName) : $($_.Exception.Message)"
						}
					}
				}
			}
		}

		Write-Progress -Activity 'Get-DriversPackFromDell' -Completed

		# Summary report, returned to the pipeline so it can be consumed by the
		# caller too (e.g. $result = Get-DriversPackFromDell; $result.Failed)
		[PSCustomObject]@{
			PackagesConsidered = $driversPacks.Count
			PackagesMatched    = $packagesMatched
			Downloaded         = $packagesDownloaded
			AlreadyDownloaded  = $packagesAlreadyDownloaded
			Failed             = $packagesFailed
			RemovedOutdated    = $packagesRemoved
			DownloadFolder     = $DownloadFolder
		}
	}
}
