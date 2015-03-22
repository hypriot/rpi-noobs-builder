#!/bin/bash
set -e

path=`pwd`
profile="hypriot-rpi"
version=`cat VERSION`
imagename="$profile-$version.img"
  
result="./result"
mkdir -p $result

NOOBS="$path/result/$profile-$version-noobs.zip"

SLIDES_DIR="."
OSPATH="os/hypriotos"
RELEASE_NOTES_URL="http://assets.hypriot.com/noobs_release_notes.txt"
SLIDES_URL="http://assets.hypriot.com/noobs_slides.zip"
NOOBS_URL="http://downloads.raspberrypi.org/NOOBS_lite_latest"


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


cd tmp/
echo " load noobs lite"
wget -qO tmp.zip $NOOBS_URL && unzip tmp.zip && rm tmp.zip

rm -r defaults os

echo "get slides for slideshow"
wget -qO slides.zip $SLIDES_URL && unzip -d $SLIDES_DIR slides.zip && rm slides.zip

echo "get release notes"
RELEASE_NOTES_URL="http://blog.hypriot.com/"
wget -O ${OSPATH}/release_notes.txt $RELEASE_NOTES_URL

echo "enable silentinstall"
cat << EOF > recovery.cmdline
runinstaller quiet vt.cur_default=1 elevator=deadline silentinstall
EOF

echo "##### move filesystems #####"
mv "$boot_archive.xz" os/hypriotos/boot.tar.xz
mv "$root_archive.xz" os/hypriotos/root.tar.xz


echo $uncompressed_boot
echo $uncompressed_root

stat -c %s os/hypriotos/boot.tar.xz
stat -c %s os/hypriotos/root.tar.xz



echo "create config files"

cat << EOWF > ${OSPATH}/flavours.json
{
  "flavours": [
    {
      "name": "hypriotOS",
      "description": "A Raspbian-based operating system optimised for Docker",
      "supported_hex_revisions": "2,3,4,5,6,7,8,9,d,e,f,10,11,12,14,1040,1041"
    }
  ]
}
EOWF

cat << EOWF > ${OSPATH}/os.json
{
  "name": "Raspbian",
  "version": "wheezy",
  "release_date": "2015-01-31",
  "kernel": "3.18",
  "description": "A community-created port of Debian wheezy, optimised for the Raspberry Pi",
  "url": "http://www.raspbian.org/",
  "username": "pi",
  "password": "raspberry",
  "supported_hex_revisions": "2,3,4,5,6,7,8,9,d,e,f,10,11,12,14,1040,1041"
}
EOWF

cat << EOWF > ${OSPATH}/partition_setup.sh
#!/bin/sh

set -ex

if [ -z "\${part1}" ] || [ -z "\${part2}" ]; then
  printf "Error: missing environment variable part1 or part2\n" 1>&2
  exit 1
fi

mkdir -p /tmp/1 /tmp/2

mount "\${part1}" /tmp/1
mount "\${part2}" /tmp/2

sed /tmp/1/cmdline.txt -i -e "s|root=/dev/[^ ]*|root=\${part2}|"
sed /tmp/2/etc/fstab -i -e "s|^.* / |\${part2}  / |"
sed /tmp/2/etc/fstab -i -e "s|^.* /boot |\${part1}  /boot |"

umount /tmp/1
umount /tmp/2
EOWF

cat << EOWF > ${OSPATH}/partitions.json
{
  "partitions": [
    {
      "label": "boot",
      "filesystem_type": "FAT",
      "partition_size_nominal": 60,
      "want_maximised": false,
      "uncompressed_tarball_size": 15,
      "mkfs_options": "-F 32"
    },
    {
      "label": "root",
      "filesystem_type": "ext4",
      "partition_size_nominal": 2700,
      "want_maximised": true,
      "mkfs_options": "-O ^huge_file",
      "uncompressed_tarball_size": 2313
    }
  ]
}
EOWF


echo "##### zip new noobs #####"
zip -r $NOOBS .

echo "##### delete folder #####"
cd $path && rm -r temp

echo "***** NOOBS created *****"

