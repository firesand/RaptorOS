#!/bin/bash
# Force Git Sync Wrapper for RaptorOS
# This script ensures git sync is used instead of rsync

# Force git sync environment variables
export PORTAGE_SYNC_STALE=0
export PORTAGE_SYNC_EXTRA_OPTS="--git"
export SYNC="git"

# Create repos.conf if it doesn't exist
sudo mkdir -p /etc/portage/repos.conf
sudo tee /etc/portage/repos.conf/gentoo.conf > /dev/null << 'EOF'
[DEFAULT]
main-repo = gentoo

[gentoo]
location = /var/db/repos/gentoo
sync-type = git
sync-uri = https://github.com/gentoo/gentoo.git
auto-sync = yes
sync-depth = 1
EOF

# Force git sync
echo "Forcing git sync instead of rsync..."
emerge --sync --git

echo "Git sync completed successfully!"
