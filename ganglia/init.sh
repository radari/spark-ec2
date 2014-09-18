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

/etc/init.d/gmetad restart
/etc/init.d/gmond restart
/root/spark-ec2/pssh.sh "/etc/init.d/gmond restart"
/etc/init.d/httpd restart
