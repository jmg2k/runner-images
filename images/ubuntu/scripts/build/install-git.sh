#!/bin/bash -e
################################################################################
##  File:  install-git.sh
##  Desc:  Install Git and Git-FTP
################################################################################

# Source the helpers for use with the script
source $HELPER_SCRIPTS/install.sh

GIT_REPO="ppa:git-core/ppa"

## Install git
add-apt-repository $GIT_REPO -y
apt-get update
apt-get install git

# Git version 2.35.2 introduces security fix that breaks action\checkout https://github.com/actions/checkout/issues/760
cat <<EOF >> /etc/gitconfig
[safe]
        directory = *
EOF

# Install git-ftp
apt-get install git-ftp

# Remove source repo's. On newer Ubuntu releases this can emit warnings about
# missing dbgsym components and return non-zero even after removing the source.
if ! add-apt-repository --remove -y $GIT_REPO; then
    echo "Non-fatal failure removing $GIT_REPO via add-apt-repository; cleaning up source list entries manually."
    rm -f /etc/apt/sources.list.d/git-core-ubuntu-ppa-*.list
    rm -f /etc/apt/sources.list.d/git-core-ubuntu-ppa-*.sources
    apt-get update
fi

# Document apt source repo's
echo "git-core $GIT_REPO" >> $HELPER_SCRIPTS/apt-sources.txt

# Add well-known SSH host keys to known_hosts.
# In some build environments outbound SSH is blocked even though HTTPS apt access works,
# so treat key prepopulation as best-effort.
for host in github.com ssh.dev.azure.com; do
    if ! ssh-keyscan -t rsa,ecdsa,ed25519 "$host" >> /etc/ssh/ssh_known_hosts 2>/dev/null; then
        echo "Warning: failed to fetch SSH host keys for $host; continuing."
    fi
done

invoke_tests "Tools" "Git"
