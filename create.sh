#!/bin/bash
set -e

path=`pwd`
profile="hypriot-rpi"
version=`cat VERSION`
imagename="$profile-$version.img"

boot_archive="$profile-$version-boot.tar"
root_archive="$profile-$version-root.tar"

./prepare_filesystem.sh $boot_archive $root_archive
./prepare_template.sh $boot_archive $root_archive
