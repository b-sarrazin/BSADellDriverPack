<#
	.SYNOPSIS
		Determines whether a CAB filename is a newer version than another.

	.DESCRIPTION
		Dell driver pack CAB files are named "<Model>-<System>-<Version>-<...>.CAB".
		The version segment is compared numerically, not lexicographically, so that
		e.g. version 10 correctly sorts after version 9.

	.PARAMETER CandidateName
		Filename of the CAB being evaluated.

	.PARAMETER ReferenceName
		Filename of the CAB to compare against.
#>
function Test-NewerPackage {
	[CmdletBinding()]
	param (
		[Parameter(Mandatory = $true)]
		[string]$CandidateName,
		[Parameter(Mandatory = $true)]
		[string]$ReferenceName
	)

	return [int]$CandidateName.Split('-')[2] -gt [int]$ReferenceName.Split('-')[2]
}
