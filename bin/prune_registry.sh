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

prune-tags() {

while true ; do
 rm -f tag-list.out
 curl -u$USERNAME:$PASSWORD https://dockerhub.servicemesh.com/api/v0/repositories/$NAMESPACE/$REPOSITORY/tags --insecure > tag-list.out
 echo "USERNAME is: " $USERNAME
 echo "PASSWORD is: " $PASSWORD
 echo "NAMESPACE is: " $NAMESPACE
 echo "REPOSITORY is: " $REPOSITORY
 echo "ARTIFACTLIMIT is: " $ARTIFACTLIMIT
 #echo "taglist is: " `cat tag-list.out`

 rm -f tag-list*.txt

 cat tag-list.out | jq -r ".tags" | jq -r ".[] | .name" > tag-list1.txt
 if [ -s tag-list1.txt ]; then
   echo "tag-list1.txt is not empty, continue"
 else
   echo "tag-list1.txt is empty, which means no tags exist or an error occurred, exiting"
   callGarbageCollection
   checkGarbageCollectionStatus
   exit 0
 fi
 #tr '\n' ':' < tag-list1.txt > tag-list2.txt
 cat tag-list1.txt | tr '\n' '::' > tag-list2.txt
 echo "taglist2.txt is: " `cat tag-list2.txt`

 read TAGLIST < tag-list2.txt
 
  # Set the field separator
 IFS="::"

 set $TAGLIST      # Breaks the string into $1, $2, ...
 i=0
 z=0
 declare -a cleanlist=();
 declare -a revlist=();
 for item    # A for loop by default loop through $1, $2, ...
 do
     case "$item" in
       "")
         echo "uninteresting element found: $item, skipping"
         ;;
       latest)
         echo "uninteresting element found: $item, skipping"
         ;;
       develop)
         echo "uninteresting element found: $item, skipping"
         ;;
       *-*) 
         echo "non-blank item: $item"
         cleanlist["$z"]=$item
         #rev=`echo $item | sed 's/\(.*\)-.*/\1/' | sed 's/.*\.//'`
         rev=`echo $item | sed "s/-[^-]*$//" | sed 's/.*-//'`
         echo "rev is: " $rev
         revlist["$z"]=$rev
         echo "cleanlist["$z"] is: " ${cleanlist["$z"]}
         ((z++))
         echo "Element $i: $item"
         ;;
       *)
         echo "uninteresting element found: $item, skipping"
         ;;
     esac
     ((i++))
 done
 x=0
 oldest=${revlist["0"]}
 for x in "${!revlist[@]}" ; do
     #echo "cleanlist($x) is: " ${cleanlist["$x"]}
    if [ "$oldest" '<' "${revlist["$x"]}" ]; then
       echo "$oldest is less than or equal to ${revlist["$x"]}"
    else
       echo "$oldest is greater than ${revlist["$x"]}"
       oldest=${revlist["$x"]}
       fulloldest=${cleanlist["$x"]}
    fi
    ((x++))
    tagcount=$x
 done
 echo "fulloldest is: $fulloldest"
 if [ "Z$fulloldest" = "Z" ]; then
   echo "fulloldest should not be blank, halt"
   exit 0
 fi
 
 if [ "$tagcount" -le "$ARTIFACTLIMIT" ]; then
   echo "This repository has $tagcount tags, which is less than or equal to the max of $ARTIFACTLIMIT, skipping prune, exiting"
   break
 else
   echo "This repository has $tagcount tags, which is greater than the max of $ARTIFACTLIMIT, prune the oldest: $fulloldest"
   curl -u$USERNAME:$PASSWORD -X DELETE https://dockerhub.servicemesh.com/api/v0/repositories/agility/$REPOSITORY/manifests/$fulloldest --insecure | tee -a prunelog.txt
   echo "waiting for 60 seconds so that DTR has a chance to update"
   sleep 60
 fi
done
}


USAGE=$*
USAGECOUNT=`echo $USAGE | wc -w`
#echo "usagecount is: " $USAGECOUNT
if [ "$USAGECOUNT" -ne "5" ]; then
  echo "error: $USAGECOUNT is not the correct number of parameters"
  echo "usage: $0 USERNAME PASSWORD NAMESPACE REPOSITORY ARTIFACTLIMIT"
  exit 1
fi

USERNAME=$1
PASSWORD=$2
NAMESPACE=$3
REPOSITORY=$4
ARTIFACTLIMIT=$5
#echo "USAGE is: " $USAGE

#retrieve list of repositories in the namespace
#rm -f repo-list.out
#curl -u$USERNAME:$PASSWORD https://dockerhub.servicemesh.com/api/v0/repositories/$NAMESPACE --insecure > repo-list.out
#echo "repolist is: " `cat repo-list.out`

#rm -f repo-list*.txt

#cat repo-list.out | jq -r ".repositories" | jq -r ".[] | .name" > repo-list1.txt
#cat repo-list1.txt | tr '\n' '::' > repo-list2.txt
#echo "repolist2.txt is: " `cat repo-list2.txt`
#read REPOLIST < repo-list2.txt

# Set the field separator
#IFS="::"
#
#set $REPOLIST      # Breaks the string into $1, $2, ...
#a=0
#b=0
#for repo    # A for loop by default loop through $1, $2, ...
#do
#    if [ "Z$repo" = "Z" ]; then
#       sleep 0
#       # uninteresting element found, skipping
#       echo "uninteresting element found: $repo"
#    else
#       sleep 0
#       #echo "non-blank item: $repo"
#       repolist["$b"]=$repo
#       echo "repolist["$b"] is: " ${repolist["$b"]}
#       prune-tags $repo
#       ((b++))
#    fi
#    ((a++))
#done

# main
prune-tags
callGarbageCollection
checkGarbageCollectionStatus
