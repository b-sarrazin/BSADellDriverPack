<#
	.SYNOPSIS
		Checks whether a valid copy of a package already exists, and reconciles duplicates.

	.DESCRIPTION
		Looks for an existing, hash-valid copy of the package anywhere under
		DownloadFolder. If found, every other copy required by DriversStructure is
		replaced by a copy (or symbolic link) of that reference copy, and corrupted
		duplicates are removed.

	.PARAMETER Package
		The package to check, as produced by Get-DriversPackFromDell.

	.PARAMETER DownloadFolder
		Root folder to search for existing copies of the package.

	.PARAMETER NoSymbolicLink
		Use a file copy instead of a symbolic link to reconcile duplicates.
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
		[switch]$NoSymbolicLink
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
