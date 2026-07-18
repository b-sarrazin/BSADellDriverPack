<#
	.SYNOPSIS
		Returns the package values matched by a filter.

	.DESCRIPTION
		Returns $PackageValues unchanged when $FilterValues is the wildcard '*'
		(no filtering requested), otherwise returns the intersection of both sets.

	.PARAMETER PackageValues
		Values carried by the package being tested (e.g. its supported models).
		Some packages (e.g. WinPE driver packs) carry no value at all for a given
		attribute, in which case this is $null.

	.PARAMETER FilterValues
		Values requested by the caller, or '*' for no filtering.
#>
function Get-PackageFilterMatch {
	[CmdletBinding()]
	param (
		[Parameter(Mandatory = $true)]
		[AllowNull()]
		[AllowEmptyCollection()]
		[array]$PackageValues,
		[Parameter(Mandatory = $true)]
		[array]$FilterValues
	)

	if ($FilterValues -eq '*') {
		return $PackageValues
	}

	if (!$PackageValues) {
		return @()
	}

	return @(Compare-Object -ReferenceObject $PackageValues -DifferenceObject $FilterValues -IncludeEqual -ExcludeDifferent |
		Where-Object { $_.SideIndicator -eq '==' } |
		Select-Object -ExpandProperty InputObject)
}
