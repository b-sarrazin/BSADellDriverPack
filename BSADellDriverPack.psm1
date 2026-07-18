<#
	.SYNOPSIS
		This module contains functions to download Dell driver packs (CAB files).

	.DESCRIPTION
		The BSADellDriverPack module downloads the Dell Driver Pack Catalog and
		downloads driver pack CAB files filtered by model, operating system and
		architecture.

	.EXAMPLE
		# Import the module
		Import-Module BSADellDriverPack

		# Download CAB files less than 12 months old
		Get-DriversPackFromDell -MonthsBack 12

	.NOTES
		Author: Brice SARRAZIN
#>

[CmdletBinding()]
Param ()
Process {
	# Where cached ValidateSet data (Models.txt, OperatingSystems.txt, Architectures.txt)
	# and, by default, downloaded drivers packs are stored. Writing into the module's own
	# installation folder would break on read-only installs and get wiped on upgrade.
	$script:BSADellDriverPackDataPath = Join-Path -Path $env:LOCALAPPDATA -ChildPath 'BSADellDriverPack'
	if (-not (Test-Path -Path $script:BSADellDriverPackDataPath)) {
		New-Item -Path $script:BSADellDriverPackDataPath -ItemType Directory -Force | Out-Null
	}

	# Locate all the public and private function specific files
	[array]$publicFunctions = Get-ChildItem -Path (Join-Path -Path $PSScriptRoot -ChildPath 'Public') -Filter '*.ps1' -ErrorAction SilentlyContinue
	[array]$privateFunctions = Get-ChildItem -Path (Join-Path -Path $PSScriptRoot -ChildPath 'Private') -Filter '*.ps1' -ErrorAction SilentlyContinue

	# Dot source the function files
	foreach ($functionFile in @($publicFunctions + $privateFunctions)) {
		try {
			. $functionFile.FullName -ErrorAction Stop
		}
		catch [System.Exception] {
			Write-Error -Message "Failed to import function '$($functionFile.FullName)' with error: $($_.Exception.Message)"
		}
	}

	Export-ModuleMember -Function $publicFunctions.BaseName -Alias *
}
