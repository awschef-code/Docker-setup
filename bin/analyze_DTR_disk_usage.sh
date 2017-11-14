#!/bin/bash
# this script must be run on the DTR host

dir="/var/local/dtr/image-storage/local/docker/registry/v2/blobs/sha256"
cd $dir
rm -f ~/dirs.out
touch ~/dirs.out 
for f in */*; do
    if [[ -d $f ]]; then
        # $f is a directory
        #echo "directory name is:" $f
        echo $f >> ~/dirs.out
    fi
done

rm -f ~/sortdirs.out
touch ~/sortdirs.out
while read -r line; do
   stat -c '%Y %n' "$line"
done < ~/dirs.out | sort -n | cut -d ' ' -f2 > ~/sortdirs.out
#cat ~/sortdirs.out

registrydir="/var/local/dtr/image-storage/local/docker/registry/v2/repositories/"
cat ~/sortdirs.out | while read line
do
   size=`du -k $dir/$line | cut -f1`
   if [ "$size" -le "500000" ]; then
     #echo "too small, skipping"
     sleep 0.1
   else
     echo "size: " $size " date: " `stat -c'%y %n' $dir/$line`
     layerid=${line##*/}
     #echo "just dir name is: " $layerid
     echo "see if this layer is present in " $registrydir
     find $registrydir -name "$layerid"
   fi
done
