#!/bin/bash

#---The following is to remove AMIs older than 3 days---#
echo "instance-`date +%d%b%y --date '3 days ago'`" > /tmp/ami-delete.txt
aws ec2 describe-images --filters "Name=name,Values=`cat /tmp/ami-delete.txt`" | grep -i imageid | awk '{ print  $2 }' > /tmp/image-id.txt

aws ec2 describe-images --image-ids `cat /tmp/image-id.txt` | grep snap | awk ' { print $4 }' > /tmp/snapshots.txt
# aws ec2 deregister-image --image-id `cat /tmp/image-id.txt`
# for i in `cat /tmp/snapshots.txt`;do aws ec2 delete-snapshot --snapshot-id $i ; done