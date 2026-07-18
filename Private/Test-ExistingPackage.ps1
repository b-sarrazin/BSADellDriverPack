<#
	.SYNOPSIS
		Checks whether a valid copy of a package already exists, and reconciles duplicates.

	.DESCRIPTION
		Looks for an existing, hash-valid copy of the package anywhere under
		DownloadFolder. If found, every other copy required by DriversStructure is
		replaced by a hard link, symbolic link or copy of that reference copy
		(depending on DuplicateHandling), and corrupted duplicates are removed.

	.PARAMETER Package
		The package to check, as produced by Get-DriversPackFromDell.

	.PARAMETER DownloadFolder
		Root folder to search for existing copies of the package.

	.PARAMETER DuplicateHandling
		How to reconcile duplicate copies of the same package: 'HardLink' (default,
		no admin rights required, source and destination must be on the same
		volume), 'SymbolicLink' (requires admin rights), or 'Copy' (uses more disk
		space, works across volumes).
#>
function Test-ExistingPackage {
	[CmdletBinding()]
	param (
		[Parameter(Mandatory = $true)]
		[ValidateNotNullOrEmpty()]
		[PSCustomObject]$Package,
		[Parameter(Mandatory = $true)]
		[ValidateNotNullOrEmpty()]
		[string]$DownloadFolder,
		[ValidateSet('HardLink', 'SymbolicLink', 'Copy')]
		[string]$DuplicateHandling = 'HardLink'
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
			Remove-Item -Path $existingPackage.FullName -Force -ErrorAction Stop | Out-Null
			Write-Verbose "Removed corrupted package : $($existingPackage.Name)"
		}

		if ($DuplicateHandling -eq 'Copy') {

			# Copy the reference package
			Copy-Item -Path $refPackage.FullName -Destination $existingPackage.FullName -Force -ErrorAction Stop
		} else {
			# New-Item -Force is not reliable for HardLink/SymbolicLink on an existing file
			if (Test-Path -Path $existingPackage.FullName) {
				Remove-Item -Path $existingPackage.FullName -Force -ErrorAction Stop
			}

			# Create a hard link or a symbolic link to the reference package
			New-Item -ItemType $DuplicateHandling -Path $existingPackage.FullName -Value $refPackage.FullName -ErrorAction Stop | Out-Null
		}
		Write-Verbose "$DuplicateHandling created for $($existingPackage.FullName)"
	}

	return $true
}
