<#
	.SYNOPSIS
		Returns the package values matched by a filter.

	.DESCRIPTION
		Returns $PackageValues unchanged when $FilterValues is the wildcard '*'
		(no filtering requested), otherwise returns the intersection of both sets.

	.PARAMETER PackageValues
		Values carried by the package being tested (e.g. its supported models).

	.PARAMETER FilterValues
		Values requested by the caller, or '*' for no filtering.
#>
function Get-PackageFilterMatch {
	[CmdletBinding()]
	param (
		[Parameter(Mandatory = $true)]
		[AllowEmptyCollection()]
		[array]$PackageValues,
		[Parameter(Mandatory = $true)]
		[array]$FilterValues
	)

	if ($FilterValues -eq '*') {
		return $PackageValues
	}

	return @(Compare-Object -ReferenceObject $PackageValues -DifferenceObject $FilterValues -IncludeEqual -ExcludeDifferent |
		Where-Object { $_.SideIndicator -eq '==' } |
		Select-Object -ExpandProperty InputObject)
}
