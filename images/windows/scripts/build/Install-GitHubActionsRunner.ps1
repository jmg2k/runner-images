################################################################################
##  File:  Install-GitHubActionsRunner.ps1
##  Desc:  Preinstall the GitHub Actions runner binaries for later JIT setup.
################################################################################

$runnerRoot = "C:\actions-runner"
$downloadUrl = Resolve-GithubReleaseAssetUrl `
    -Repo "actions/runner" `
    -Version "latest" `
    -UrlMatchPattern "actions-runner-win-x64-*.zip"

$archivePath = Invoke-DownloadWithRetry -Url $downloadUrl -Path "$env:TEMP\actions-runner-win-x64.zip"

Write-Host "Installing GitHub Actions runner from $downloadUrl"
if (Test-Path -LiteralPath $runnerRoot) {
    Remove-Item -LiteralPath $runnerRoot -Recurse -Force
}

New-Item -Path $runnerRoot -ItemType Directory -Force | Out-Null
Expand-Archive -Path $archivePath -DestinationPath $runnerRoot -Force
Remove-Item -LiteralPath $archivePath -Force
