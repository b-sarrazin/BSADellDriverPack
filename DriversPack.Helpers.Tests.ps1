BeforeAll {
	. "$PSScriptRoot\DriversPack.Helpers.ps1"
}

Describe 'Test-PackageHash' {
	BeforeAll {
		$testFile = Join-Path $TestDrive 'package.cab'
		Set-Content -Path $testFile -Value 'sample content' -NoNewline
		$expectedHash = (Get-FileHash -Algorithm MD5 -Path $testFile).Hash
	}

	It 'returns true when the file hash matches' {
		Test-PackageHash -FilePath $testFile -FileHash $expectedHash | Should -BeTrue
	}

	It 'returns false when the file hash does not match' {
		Test-PackageHash -FilePath $testFile -FileHash 'deadbeefdeadbeefdeadbeefdeadbeef' | Should -BeFalse
	}

	It 'is case-insensitive when comparing hashes' {
		Test-PackageHash -FilePath $testFile -FileHash $expectedHash.ToLower() | Should -BeTrue
	}

	It 'throws when the file does not exist' {
		{ Test-PackageHash -FilePath (Join-Path $TestDrive 'missing.cab') -FileHash 'deadbeefdeadbeefdeadbeefdeadbeef' } | Should -Throw
	}
}

Describe 'Get-PackageFilterMatch' {
	It 'matches everything when the filter is the wildcard *' {
		Get-PackageFilterMatch -PackageValues @('Windows10', 'Windows11') -FilterValues '*' | Should -Be @('Windows10', 'Windows11')
	}

	It 'returns the overlapping values when a filter is supplied' {
		Get-PackageFilterMatch -PackageValues @('Windows10', 'Windows11') -FilterValues @('Windows11', 'Windows7') | Should -Be 'Windows11'
	}

	It 'returns an empty result when nothing matches' {
		Get-PackageFilterMatch -PackageValues @('Windows10') -FilterValues @('Windows11') | Should -BeNullOrEmpty
	}

	It 'handles a single scalar package value' {
		Get-PackageFilterMatch -PackageValues 'x64' -FilterValues @('x64', 'x86') | Should -Be 'x64'
	}
}

Describe 'Test-NewerPackage' {
	It 'compares version segments numerically, not lexicographically' {
		# Regression test: a plain string comparison ("9" -gt "10") would wrongly
		# treat "9" as newer than "10".
		Test-NewerPackage -CandidateName 'Latitude-7490-10-A00.CAB' -ReferenceName 'Latitude-7490-9-A00.CAB' | Should -BeTrue
		Test-NewerPackage -CandidateName 'Latitude-7490-9-A00.CAB' -ReferenceName 'Latitude-7490-10-A00.CAB' | Should -BeFalse
	}

	It 'returns false for identical versions' {
		Test-NewerPackage -CandidateName 'Latitude-7490-5-A00.CAB' -ReferenceName 'Latitude-7490-5-A00.CAB' | Should -BeFalse
	}

	It 'returns true when the candidate version is strictly greater' {
		Test-NewerPackage -CandidateName 'Latitude-7490-6-A00.CAB' -ReferenceName 'Latitude-7490-5-A00.CAB' | Should -BeTrue
	}
}
