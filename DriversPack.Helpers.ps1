function Test-PackageHash {
	[CmdletBinding()]
	param (
		[Parameter(Mandatory = $true)]
		[ValidateNotNullOrEmpty()]
		[string]$FilePath,
		[Parameter(Mandatory = $true)]
		[ValidateNotNullOrEmpty()]
		[string]$FileHash
	)

	$myFileHash = Get-FileHash -Algorithm MD5 -Path $FilePath -ErrorAction Stop | Select-Object -ExpandProperty Hash
	return $myFileHash -eq $FileHash
}

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
