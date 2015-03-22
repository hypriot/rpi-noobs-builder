#!/bin/bash
set -e

path=`pwd`
profile="hypriot-rpi"
version=`cat VERSION`
imagename="$profile-$version.img"


# set up error handling for cleaning up
# after having an error
handle_error() {
echo "FAILED: line $1, exit code $2"
echo "Removing loop device"
# ensure we are outside mounted image filesystem
cd /
# remove loop device for image
kpartx -vds ${imagename}
exit 1
}

trap 'handle_error $LINENO $?' ERR

#aws s3 cp s3://buildserver-production/images/$imagename.zip .
  
bootfs="./tmp/boot"
rootfs="./tmp/root"

boot_archive="$profile-$version-boot.tar"
root_archive="$profile-$version-root.tar"

#loopdev="loop0"

echo "##### create folder #####"
mkdir -p $bootfs $rootfs

echo "##### unzip img #####"
unzip $imagename.zip

echo "##### create loopdevice #####"
loopdev=`kpartx -avs $imagename | sed -E 's/.*(loop[0-9])p.*/\1/g' | head -1`

echo "##### mount partitions #####"
mount -o loop /dev/mapper/${loopdev}p1 $bootfs
mount -o loop /dev/mapper/${loopdev}p2 $rootfs

echo "##### archive boot #####"
tar -C $bootfs -cf $boot_archive .

echo "##### archive root #####"
tar -C $rootfs -cf $root_archive --exclude $bootfs .

echo "##### umount partitions #####"
cd $path
umount "$bootfs"
umount "$rootfs"

sleep 2

echo "##### delete loopdevices #####"
kpartx -dvs $imagename

echo "##### remove folder #####"
rm -r $bootfs $rootfs

echo "infos"
ls -la 

export uncompressed_boot=$(stat -c %s $boot_archive)
export uncompressed_root=$(stat -c %s $root_archive)

export boot_archive=$boot_archive
export root_archive=$root_archive

echo "##### compress boot #####"
xz --compress $boot_archive
echo "##### compress root #####"
xz --compress $root_archive
