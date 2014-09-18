#!/bin/bash

# NOTE: Remove all rrds which might be around from an earlier run
rm -rf /var/lib/ganglia/rrds/*
rm -rf /mnt/ganglia/rrds/*

# Symlink /var/lib/ganglia/rrds to /mnt/ganglia/rrds
rmdir /var/lib/ganglia/rrds

# Make sure rrd storage directory has right permissions
mkdir -p /mnt/ganglia/rrds
chown -R nobody:nobody /mnt/ganglia/rrds

ln -s /mnt/ganglia/rrds /var/lib/ganglia/rrds

/root/spark-ec2/copy-dir /etc/ganglia/

# Start gmond everywhere
/root/spark-ec2/pssh.sh "/etc/init.d/gmond restart"

# gmeta needs rrds to be owned by nobody
chown -R ganglia:ganglia /var/lib/ganglia/rrds
chown -R ganglia:ganglia /mnt/ganglia/rrds
# cluster-wide aggregates only show up with this. TODO: Fix this cleanly ?
ln -s /usr/share/ganglia/conf/default.json /var/lib/ganglia/conf/

/etc/init.d/gmetad restart
/etc/init.d/gmond restart
/etc/init.d/httpd restart
