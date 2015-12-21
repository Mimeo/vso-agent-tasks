[CmdletBinding()]
param()

Trace-VstsEnteringInvocation $MyInvocation
[string]$SymbolsPath = Get-VstsInput -Name 'SymbolsPath'
[string]$SearchPattern = Get-VstsInput -Name 'SearchPattern' -Default "**\bin\**\*.pdb"
if ([string]$SourceFolder = (Get-VstsInput -Name 'SourceFolder') -and
    $SourceFolder -ne (Get-VstsTaskVariable -Name 'Build.SourcesDirectory' -Require)) {
    Write-Warning (Get-VstsLocString -Key 'SourceFolderParameterDeprecatedIgnoring0' -ArgumentList $SourceFolder)
}

[string]$SymbolsProduct = Get-VstsInput -Name 'SymbolsProduct' -Default (Get-VstsTaskVariable -Name 'Build.DefinitionName' -Require)
[string]$SymbolsVersion = Get-VstsInput -Name 'SymbolsVersion' -Default (Get-VstsTaskVariable -Name 'Build.BuildNumber' -Require)
[int]$SymbolsMaximumWaitTime = Get-VstsInput -Name 'SymbolsMaximumWaitTime' -Default '0' -AsInt
[string]$SymbolsFolder = Get-VstsInput -Name 'SymbolsFolder' -Default (Get-VstsTaskVariable -Name 'Build.SourcesDirectory' -Require)
[string]$SymbolsArtifactName = Get-VstsInput -Name 'SymbolsArtifactName'
[bool]$TreatNotIndexedAsWarning = Get-VstsInput -Name 'TreatNotIndexedAsWarning' -AsBool

# Default max wait time.
$maxWaitTime = if ($SymbolsMaximumWaitTime -gt 0) { [timespan]::FromMinutes($SymbolsMaximumWaitTime) } else { [timespan]::FromHours(2) }
Write-Verbose "Max wait time: $maxWaitTime"

# Default maxSemaphoreAge.
$maxSemaphoreAge = [timespan]::FromDays(1)
Write-Verbose "Max semaphore age: $maxSemaphoreAge"

# Get the PDB file paths.
$pdbFiles = @(Find-VstsFiles -LiteralDirectory $SymbolsFolder -LegacyPattern $SearchPattern)
Write-Host (Get-VstsLocString -Key "Found0SymbolFilesToIndex" -ArgumentList $pdbFiles.Count)

# Index the sources.
Import-Module -Name $PSScriptRoot\IndexHelpers\IndexHelpers.psm1
Invoke-IndexSources -SymbolsFilePaths $pdbFiles -TreatNotIndexedAsWarning:$TreatNotIndexedAsWarning

# Publish the symbols.
if ($SymbolsPath) {
    $utcNow = (Get-Date).ToUniversalTime()
    $semaphoreMessage = "Machine: $env:ComputerName, BuildUri: $env:Build_BuildUri, BuildNumber: $env:Build_BuildNumber, RepositoryName: $env:Build_Repository_Name, RepositoryUri: $env:Build_Repository_Uri, Team Project: $env:System_TeamProject, CollectionUri: $env:System_TeamFoundationCollectionUri at $utcNow UTC"
    Import-Module -Name $PSScriptRoot\PublishHelpers\PublishHelpers.psm1
    Invoke-PublishSymbols -PdbFiles $pdbFiles -Share $SymbolsPath -Product $SymbolsProduct -Version $SymbolsVersion -MaximumWaitTime $maxWaitTime.TotalMilliseconds -MaximumSemaphoreAge $maxSemaphoreAge.TotalMinutes -ArtifactName $SymbolsArtifactName -SemaphoreMessage $semaphoreMessage
} else {
    Write-Verbose "SymbolsPath was not set, publish symbols step was skipped."
}

Trace-VstsLeavingInvocation $MyInvocation
