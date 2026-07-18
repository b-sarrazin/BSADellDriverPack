<#
	.SYNOPSIS
		Compares a file's MD5 hash against an expected value.

	.PARAMETER FilePath
		Path to the file to hash.

	.PARAMETER FileHash
		Expected MD5 hash to compare against.
#>
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
