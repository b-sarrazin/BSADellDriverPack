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

	# Write-Progress has real per-call overhead; with catalogs of 1000+ packages,
	# refreshing it for every single one measurably slows down filtering. Throttle
	# to a few updates per second, always showing the first and the 100% update.
	$now = Get-Date
	if ($script:percentComplete -lt 100 -and $script:lastProgressUpdate -and ($now - $script:lastProgressUpdate).TotalMilliseconds -lt 100) {
		return
	}
	$script:lastProgressUpdate = $now

	Write-Progress -Activity $Activity -Status $Status -PercentComplete $script:percentComplete
}
