#!/bin/bash
set -e

path=`pwd`
imagename=`cat VERSION`

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
result="./result"

boot_archive=$imagename"-boot.tar"
root_archive=$imagename"-root.tar"
noobs_template="noobs-template.tar"

NOOBS=$path/result/NOOBS-$imagename.zip

#loopdev="loop0"

echo "##### create folder #####"
mkdir -p $bootfs $rootfs $result

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

echo "##### compress boot #####"
xz --compress $boot_archive
echo "##### compress root #####"
xz --compress $root_archive



echo "##### move filesystems #####"
mkdir -p temp/
unzip NOOBS_lite_*.zip -d temp/
cp -rf template/* temp/
mv $boot_archive".xz" temp/os/hypriotos/boot.tar.xz
mv $root_archive".xz" temp/os/hypriotos/root.tar.xz

echo "##### FS size #####"
stat -c %s temp/os/hypriotos/boot.tar.xz
stat -c %s $boot_archive
stat -c %s $root_archive
stat -c %s temp/os/hypriotos/root.tar.xz

echo "##### zip new noobs #####"
cd ./temp/
#zip -r $path/NOOBS-$imagename.zip .
zip -r $NOOBS .

echo "##### delete folder #####"
cd $path
rm -r tmp

echo "***** NOOBS created *****"

