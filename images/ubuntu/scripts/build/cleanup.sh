#!/bin/bash -e
################################################################################
##  File:  cleanup.sh
##  Desc:  Perform cleanup
################################################################################

# before cleanup
before=$(df / -Pm | awk 'NR==2{print $4}')

# clears out the local repository of retrieved package files
# It removes everything but the lock file from /var/cache/apt/archives/ and /var/cache/apt/archives/partial
apt-get clean || true

# Leave /tmp alone while Packer is still provisioning, otherwise we can remove
# active temporary scripts and sockets that the communicator still needs.
find /var/tmp -mindepth 1 -maxdepth 1 -exec rm -rf {} + || true
rm -rf /root/.cache || true

# journalctl
if command -v journalctl; then
    journalctl --rotate || true
    journalctl --vacuum-time=1s || true
fi

# delete all .gz and rotated file
find /var/log -type f -regex ".*\.gz$" -delete || true
find /var/log -type f -regex ".*\.[0-9]$" -delete || true

# wipe log files
find /var/log/ -type f -exec sh -c '> "$1"' _ {} \; || true

# delete symlink for tests running
rm -f /usr/local/bin/invoke_tests || true

# remove apt mock
prefix=/usr/local/bin
for tool in apt apt-get apt-key;do
    sudo rm -f $prefix/$tool || true
done

# after cleanup
after=$(df / -Pm | awk 'NR==2{print $4}')

# display size
echo "Before: $before MB"
echo "After : $after MB"
echo "Delta : $(($after-$before)) MB"
