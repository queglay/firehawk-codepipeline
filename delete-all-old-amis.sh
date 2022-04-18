#!/bin/bash
latest_date=$(date  --date="7 days ago" +"%Y-%m-%d")
#---The following is to remove AMIs older than 3 days---#
aws ec2 describe-images --owners self --query "Images[?CreationDate<\`${latest_date}\`].{ImageId:ImageId,date:CreationDate,Name:Name,SnapshotId:BlockDeviceMappings[0].Ebs.SnapshotId}" > /tmp/ami-delete.txt
ami_delete=$(cat /tmp/ami-delete.txt)
echo "ami_delete: $ami_delete"
# aws ec2 describe-images --filters "Name=name,Values=`cat /tmp/ami-delete.txt`" | grep -i imageid | awk '{ print  $2 }' > /tmp/image-id.txt

ami_delete_list=$(echo $ami_delete | jq -r '.[] | "\(.ImageId)"')
# echo "ami_delete_list: $ami_delete_list"
snap_delete_list=$(echo $ami_delete | jq -r '.[] | "\(.SnapshotId)"')
# echo "snap_delete_list: $snap_delete_list"

echo "WARNING: This script will delete ALL images in your account older than 7 days"
read -r -p "Are you sure you want to delete the above images?: [Y/n] " input

echo "Selected: $input"

case $input in
    [yY][eE][sS]|[yY])
    echo "Yes"
    ;;
    [nN][oO]|[nN])
    echo "No"
    exit 1
    ;;
    *)
    echo "Invalid input: $input"
    exit 1
    ;;
esac

echo "...Deleting images"
# aws ec2 deregister-image --image-id $ami_delete_list
for i in $ami_delete_list; do
    echo "Delete: $i"
    aws ec2 deregister-image --image-id $i
done

echo "...Deleting snapshots"
for i in $snap_delete_list; do
    echo "Delete: $i"
    aws ec2 delete-snapshot --snapshot-id $i
done
