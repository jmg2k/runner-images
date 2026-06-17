#!/bin/bash -e
################################################################################
##  File:  install-github-actions-runner.sh
##  Desc:  Preinstall the GitHub Actions runner binaries for later JIT setup.
################################################################################

source "$HELPER_SCRIPTS/install.sh"

RUNNER_DIR="/opt/actions-runner"
RUNNER_REPO="actions/runner"
RUNNER_ASSET_URL=$(resolve_github_release_asset_url "$RUNNER_REPO" 'contains("actions-runner-linux-x64-") and endswith(".tar.gz")' "latest")
RUNNER_ARCHIVE_PATH=$(download_with_retry "$RUNNER_ASSET_URL")

echo "Installing GitHub Actions runner from $RUNNER_ASSET_URL"
rm -rf "$RUNNER_DIR"
mkdir -p "$RUNNER_DIR"
tar -xzf "$RUNNER_ARCHIVE_PATH" -C "$RUNNER_DIR"
rm -f "$RUNNER_ARCHIVE_PATH"

chmod -R 755 "$RUNNER_DIR"
