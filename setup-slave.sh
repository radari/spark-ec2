#!/bin/bash

# Make sure we are in the spark-ec2 directory
cd /root/spark-ec2

source ec2-variables.sh

# Set hostname based on EC2 private DNS name, so that it is set correctly
# even if the instance is restarted with a different private DNS name
PRIVATE_DNS=`wget -q -O - http://instance-data.ec2.internal/latest/meta-data/local-hostname`
hostname $PRIVATE_DNS
echo $PRIVATE_DNS > /etc/hostname
HOSTNAME=$PRIVATE_DNS  # Fix the bash built-in hostname variable too

echo "Setting up slave on `hostname`..."

function setup_ext4_volume {
  device=$1
  mount_point=$2

  echo "setting up $device at $mount_point"
  rm -rf $mount_point
  mkdir $mount_point
  # To turn TRIM support on, uncomment the following line.
  #echo '/dev/sdc /mnt2  ext4  defaults,noatime,nodiratime,discard 0 0' >> /etc/fstab
  mkfs.ext4 -E lazy_itable_init=0,lazy_journal_init=0 $device
  mount -o "defaults,noatime,nodiratime" $device $mount_point
}

# Work around for R3 instances without pre-formatted ext3 disks
instance_type=$(curl http://169.254.169.254/latest/meta-data/instance-type 2> /dev/null)

if [[ $instance_type == r3* ]]; then
  setup_ext4_volume /dev/sdb /mnt
  setup_ext4_volume /dev/sdc /mnt2
fi

if [[ $instance_type == i2* ]]; then
  setup_ext4_volume /dev/sdb /mnt
  setup_ext4_volume /dev/sdc /mnt2
  setup_ext4_volume /dev/sdd /mnt3
  setup_ext4_volume /dev/sde /mnt4
  setup_ext4_volume /dev/sdf /mnt5
  setup_ext4_volume /dev/sdg /mnt6
  setup_ext4_volume /dev/sdh /mnt7
  setup_ext4_volume /dev/sdi /mnt8
fi

# Mount options to use for ext3 and xfs disks (the ephemeral disks
# are ext3, but we use xfs for EBS volumes to format them faster)
XFS_MOUNT_OPTS="defaults,noatime,nodiratime,allocsize=8m"

function setup_xfs_volume {
  device=$1
  mount_point=$2
  if [[ -e $device ]]; then
    # Check if device is already formatted
    if ! blkid $device; then
      mkdir $mount_point
      yum install -q -y xfsprogs
      if mkfs.xfs -q $device; then
        mount -o $XFS_MOUNT_OPTS $device $mount_point
        chmod -R a+w $mount_point
      else
        # mkfs.xfs is not installed on this machine or has failed;
        # delete /vol so that the user doesn't think we successfully
        # mounted the EBS volume
        rmdir $mount_point
      fi
    else
      # EBS volume is already formatted. Mount it if its not mounted yet.
      if ! grep -qs '$mount_point' /proc/mounts; then
        mkdir $mount_point
        mount -o $XFS_MOUNT_OPTS $device $mount_point
        chmod -R a+w $mount_point
      fi
    fi
  fi
}

# Format and mount EBS volume (/dev/sd[s, t, u, v, w, x, y, z]) as /vol[x] if the device exists
setup_xfs_volume /dev/sds /vol0
setup_xfs_volume /dev/sdt /vol1
setup_xfs_volume /dev/sdu /vol2
setup_xfs_volume /dev/sdv /vol3
setup_xfs_volume /dev/sdw /vol4
setup_xfs_volume /dev/sdx /vol5
setup_xfs_volume /dev/sdy /vol6
setup_xfs_volume /dev/sdz /vol7



# Alias vol to vol3 for backward compatibility: the old spark-ec2 script supports only attaching
# one EBS volume at /dev/sdv.
if [[ -e /vol3 && ! -e /vol ]]; then
  ln -s /vol3 /vol
fi

# Make data dirs writable by non-root users, such as CDH's hadoop user
chmod -R a+w /mnt*

# Remove ~/.ssh/known_hosts because it gets polluted as you start/stop many
# clusters (new machines tend to come up under old hostnames)
rm -f /root/.ssh/known_hosts

# Create swap space on /mnt
#/root/spark-ec2/create-swap.sh $SWAP_MB

# Allow memory to be over committed. Helps in pyspark where we fork
echo 1 > /proc/sys/vm/overcommit_memory

# Add github to known hosts to get git@github.com clone to work
# TODO(shivaram): Avoid duplicate entries ?
cat /root/spark-ec2/github.hostkey >> /root/.ssh/known_hosts
