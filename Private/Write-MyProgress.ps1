<#
	.SYNOPSIS
		Writes a Write-Progress update for the driver pack download loop.

	.PARAMETER Activity
		Activity name shown on the progress bar.

	.PARAMETER Status
		Optional status text. Defaults to "Step X / Y".
#>
function Write-MyProgress {
	[CmdletBinding()]
	param (
		[Parameter(Mandatory = $true)]
		[string]$Activity,
		[Parameter(Mandatory = $false)]
		[string]$Status
	)

	$otherOperations = 3

	if ($script:totalOperations -eq 0) {
		$script:totalOperations = $otherOperations + $script:catalog.DriverPackManifest.DriverPackage.Count - 1
	}

	$script:percentComplete = [math]::Round(($script:currentOperation++ / $script:totalOperations) * 100)

	if (!$Status) {
		$Status = "Step $script:currentOperation / $script:totalOperations"
	}

	Write-Progress -Activity $Activity -Status $Status -PercentComplete $script:percentComplete
}
