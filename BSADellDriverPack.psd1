<#
	.SYNOPSIS
	BSADellDriverPack is a PowerShell module to download Dell driver packs.

	.DESCRIPTION
	This module downloads the Dell Driver Pack Catalog and downloads driver
	pack CAB files filtered by model, operating system and architecture.

	.NOTES
	Created on:    18/07/2026
	Created by:    Brice SARRAZIN
	Organization:

	.LINK
	GitHub Repository: https://github.com/b-sarrazin/BSADellDriverPack

	.EXAMPLE
	# Import the module
	Import-Module BSADellDriverPack

	# Download CAB files less than 12 months old
	Get-BSADellDriverPack -MonthsBack 12
#>

@{
	# Script module or binary module file associated with this manifest
	RootModule = 'BSADellDriverPack.psm1'

	# Version number of this module.
	ModuleVersion = '1.0.1'

	# ID used to uniquely identify this module
	GUID = 'b5d868a7-b06c-4e1b-97f9-87a9e66b0856'

	# Author of this module
	Author = 'Brice SARRAZIN'

	# Company or vendor of this module
	CompanyName = ''

	# Copyright statement for this module
	Copyright = '(c) 2026. All rights reserved.'

	# Description of the functionality provided by this module
	Description = 'BSADellDriverPack is a PowerShell module to download Dell driver packs (CAB files) filtered by model, operating system and architecture.'

	# Minimum version of the Windows PowerShell engine required by this module
	PowerShellVersion = '5.1'

	# Name of the Windows PowerShell host required by this module
	PowerShellHostName = ''

	# Minimum version of the Windows PowerShell host required by this module
	PowerShellHostVersion = ''

	# Minimum version of the .NET Framework required by this module
	DotNetFrameworkVersion = '4.5'

	# Minimum version of the common language runtime (CLR) required by this module
	CLRVersion = ''

	# Processor architecture (None, X86, Amd64, IA64) required by this module
	ProcessorArchitecture = 'None'

	# Modules that must be imported into the global environment prior to importing
	# this module
	RequiredModules = @()

	# Assemblies that must be loaded prior to importing this module
	RequiredAssemblies = @()

	# Script files (.ps1) that are run in the caller's environment prior to
	# importing this module
	ScriptsToProcess = @()

	# Type files (.ps1xml) to be loaded when importing this module
	TypesToProcess = @()

	# Format files (.ps1xml) to be loaded when importing this module
	FormatsToProcess = @()

	# Modules to import as nested modules of the module specified in
	# ModuleToProcess
	NestedModules = @()

	# Functions to export from this module
	FunctionsToExport = @(
		'Get-BSADellDriverPack'
	) # For performance, list functions explicitly

	# Cmdlets to export from this module
	CmdletsToExport = @()

	# Variables to export from this module
	VariablesToExport = @()

	# Aliases to export from this module
	AliasesToExport = @() # For performance, list alias explicitly

	# DSC class resources to export from this module.
	#DSCResourcesToExport = ''

	# List of all modules packaged with this module
	ModuleList = @()

	# List of all files packaged with this module
	FileList = @()

	# Private data to pass to the module specified in ModuleToProcess. This may also contain a PSData hashtable with additional module metadata used by PowerShell.
	PrivateData = @{
		# Support for PowerShellGet galleries.
		PSData = @{
			# Tags applied to this module. These help with module discovery in online galleries.
			Tags = @('Dell', 'Drivers', 'DriverPack', 'CAB', 'SCCM', 'MDT', 'Windows')

			# A URL to the license for this module.
			LicenseUri = 'https://github.com/b-sarrazin/BSADellDriverPack/blob/master/LICENSE'

			# A URL to the main website for this project.
			ProjectUri = 'https://github.com/b-sarrazin/BSADellDriverPack'

			# ReleaseNotes of this module
			ReleaseNotes = 'https://github.com/b-sarrazin/BSADellDriverPack/releases'
		}
	}
}
