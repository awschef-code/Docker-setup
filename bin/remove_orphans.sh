#!/bin/bash
# get list of tags from /var/local/dtr/image-storage/local/docker/registry/v2/repositories/$namespace/$repository/_manifests/tags/
#
#for each tag, get current sha from $tagname/current/link
# more /var/local/dtr/image-storage/local/docker/registry/v2/repositories/$namespace/$repository/_manifests/tags/$tagname/current/link 
# sha256:90243eb9e302feac93a1357324b21e4c6ec187d4ea3f2a55468f1d98dbfb383b
#
# for loop through the sha's in $tagname/index/sha256
#  ls /var/local/dtr/image-storage/local/docker/registry/v2/repositories/$namespace/$repository/_manifests/tags/$tagname/index/sha256/
#  if the sha = the sha from above
#   skip that sha
#  else
#   delete with sudo rm -rf /var/local/dtr/image-storage/local/docker/registry/v2/repositories/$namespace/$repository/_manifests/revisions/sha256/$sha
#  fi
# done
#done
#!/bin/bash

callGarbageCollection () {
 echo "call DTR garbage collection..."
 curl --insecure -u$USERNAME:$PASSWORD -X POST -H "Content-Type: application/json" "https://dockerhub.servicemesh.com/api/v0/admin/jobs" -d "{ \"job\" : \"registryGC\"}" | tee -a gclog.txt
 sleep 10
}

checkGarbageCollectionStatus () {
 echo "check GC status..."
 curl --insecure -u$USERNAME:$PASSWORD "https://dockerhub.servicemesh.com/api/v0/admin/settings/registry/garbageCollection/lastSavings" | tee -a gcstatus.txt
 sleep 10
}

remove-orphans() {

REPOSITORY=$1
#loop through all tags ever created on the filesystem
declare -a taglist=();
tagcount=0
for tags in $STORAGELOCATION/$NAMESPACE/$REPOSITORY/_manifests/tags/*; do
   tagname=`basename "$tags"`
   echo 
   echo "starting next tag - tagname is: " $tagname
   if [ "Z$tagname" = "Z" ]; then
     sleep 0
     # uninteresting element found, skipping
     #echo "uninteresting element found: $tagname"
   else
     #echo "non-blank item: $tagname"
     taglist["$tagcount"]=$tagname
     rawcurrentlink=`cat $STORAGELOCATION/$NAMESPACE/$REPOSITORY/_manifests/tags/$tagname/current/link`
     #echo "rawcurrentlink is: " $rawcurrentlink
     currentlink=`echo $rawcurrentlink | sed 's/sha256 //'`
     currentlink=`echo $currentlink | sed 's/sha256://'`
     echo " looking for orphans for tag: " $tagname
     echo " ./$NAMESPACE/$REPOSITORY/_manifests/tags/$tagname/current/link is: " $currentlink

     # for loop through the sha's in $tagname/index/sha256
     #  ls /var/local/dtr/image-storage/local/docker/registry/v2/repositories/$namespace/$repository/_manifests/tags/$tagname/index/sha256/
     #  if the sha = the sha from above
     #   skip that sha
     #  else
     #   delete with sudo rm -rf /var/local/dtr/image-storage/local/docker/registry/v2/repositories/$namespace/$repository/_manifests/revisions/sha256/$sha
     #  fi
     # done

     indexcount=0
     declare -a indexlist=();
     for dirs in $STORAGELOCATION/$NAMESPACE/$REPOSITORY/_manifests/tags/$tagname/index/sha256/*; do
       dir=`basename "$dirs"`
       #echo "dir is: " $dir
       if [ "Z$dir" = "Z" ]; then
         sleep 0
         # uninteresting element found, skipping
         #echo "uninteresting element found: $dir"
       else
         sleep 0
         #echo "non-blank item: $dir"
         indexlist["$indexcount"]=$dir
         #echo "indexlist["$indexcount"] is: " ${indexlist["$indexcount"]}
         #echo "currentlink is $currentlink"
         if [ "$dir" = "$currentlink" ]; then
           echo "  the tag: $tagname has a ./current/link sha that matches a manifest found in the index, so we skip removing manifest: $dir"
         else
           echo "  the tag: $tagname has an orphaned manifest in the index, removing manifest: $dir" 
           #insert removal code
           if [ -d "$STORAGELOCATION/$NAMESPACE/$REPOSITORY/_manifests/revisions/sha256/$dir/signatures/sha256" ]; then
             echo "  the directory exists, so lets delete it"
             echo "  issuing the following command: SUDO rm -rvf $STORAGELOCATION/$NAMESPACE/$REPOSITORY/_manifests/revisions/sha256/$dir"
             sudo rm -rvf $STORAGELOCATION/$NAMESPACE/$REPOSITORY/_manifests/revisions/sha256/$dir
             echo "  now, lets delete the index file"
             echo "  issuing the following command: SUDO rm -f $STORAGELOCATION/$NAMESPACE/$REPOSITORY/_manifests/tags/$tagname/index/sha256/$dir/link"
             sudo rm -vf $STORAGELOCATION/$NAMESPACE/$REPOSITORY/_manifests/tags/$tagname/index/sha256/$dir/link
             echo "  issuing the following command: SUDO rmdir $STORAGELOCATION/$NAMESPACE/$REPOSITORY/_manifests/tags/$tagname/index/sha256/$dir"
             sudo rmdir -v $STORAGELOCATION/$NAMESPACE/$REPOSITORY/_manifests/tags/$tagname/index/sha256/$dir
           else
             echo "  the directory doesnt exist, so it appears this index has already been cleaned up, removing index"
             echo "  issuing the following command: SUDO rm -f $STORAGELOCATION/$NAMESPACE/$REPOSITORY/_manifests/tags/$tagname/index/sha256/$dir/link"
             sudo rm -vf $STORAGELOCATION/$NAMESPACE/$REPOSITORY/_manifests/tags/$tagname/index/sha256/$dir/link
             echo "  issuing the following command: SUDO rmdir $STORAGELOCATION/$NAMESPACE/$REPOSITORY/_manifests/tags/$tagname/index/sha256/$dir"
             sudo rmdir -v $STORAGELOCATION/$NAMESPACE/$REPOSITORY/_manifests/tags/$tagname/index/sha256/$dir
           fi
         fi
         ((indexcount++))
         #echo "Element $indexcount: $dir"
       fi
     done
     #echo "taglist["$tagcount"] is: " ${taglist["$tagcount"]}
     ((tagcount++))
   fi
done
}

USAGE=$*
USAGECOUNT=`echo $USAGE | wc -w`
#echo "usagecount is: " $USAGECOUNT
if [ "$USAGECOUNT" -ne "3" ]; then
  echo "error: $USAGECOUNT is not the correct number of parameters"
  echo "usage: $0 USERNAME PASSWORD NAMESPACE"
  exit 1
fi

USERNAME=$1
PASSWORD=$2
NAMESPACE=$3

#echo "USAGE is: " $USAGE

# main
STORAGELOCATION="/var/local/dtr/image-storage/local/docker/registry/v2/repositories"
#retrieve list of repositories in the namespace
rm -f repo-list.out
curl -u$USERNAME:$PASSWORD https://dockerhub.servicemesh.com/api/v0/repositories/$NAMESPACE?limit=25 --insecure > repo-list.out
echo "repolist is: " `cat repo-list.out`

rm -f repo-list*.txt

cat repo-list.out | jq -r ".repositories" | jq -r ".[] | .name" > repo-list1.txt
cat repo-list1.txt | tr '\n' '::' > repo-list2.txt
echo "repolist2.txt is: " `cat repo-list2.txt`
read REPOLIST < repo-list2.txt

# Set the field separator
IFS="::"

set $REPOLIST      # Breaks the string into $1, $2, ...
a=0
b=0
for repo    # A for loop by default loop through $1, $2, ...
do
    if [ "Z$repo" = "Z" ]; then
       sleep 0
       # uninteresting element found, skipping
       echo "uninteresting element found: $repo"
    else
       sleep 0
       #echo "non-blank item: $repo"
       repolist["$b"]=$repo
       echo "repolist["$b"] is: " ${repolist["$b"]}
       ((b++))
       remove-orphans $repo
    fi
    ((a++))
done

# finish up with GC
callGarbageCollection
checkGarbageCollectionStatus
