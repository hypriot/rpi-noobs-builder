#!/bin/bash
set -ex

echo "prepare"
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


#echo $REGION
#echo $AWS_REGION
#aws s3 --region eu-central-1 cp s3://buildserver-production/images/$imagename $BUILD_INPUTS/
#mkdir $BUILD_INPUTS 

#aws s3 cp s3://buildserver-production/images/$imagename .

#imagename=$BUILD_INPUTS/$imagename
  
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

echo "##### untar noobs template #####"
#tar xf $noobs_template -C ./tmp/

echo "##### unzip img #####"
unzip $imagename.zip

echo "##### create loopdevice #####"
loopdev=`kpartx -av $imagename | sed -E 's/.*(loop[0-9])p.*/\1/g' | head -1`

echo $loopdev

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
echo "##### list loopdevices #####"
kpartx -l $imagename
ls -l /dev/mapper/

sleep 2
echo "##### delete loopdevices #####"
kpartx -dv $imagename

echo "##### compress boot #####"
xz --compress $boot_archive
echo "##### compress root #####"
xz --compress $root_archive


echo "##### move filesystems #####"
mv $boot_archive".xz" template/os/hypriot/boot.tar.xz
mv $root_archive".xz" template/os/hypriot/root.tar.xz

echo "##### zip new noobs #####"
cd ./template/
#zip -r $path/NOOBS-$imagename.zip .
zip -r $NOOBS .

echo "##### delete folder #####"
cd $path
rm -r tmp

