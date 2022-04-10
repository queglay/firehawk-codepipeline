#!/bin/bash
latest_date=$(date  --date="7 days ago" +"%Y-%m-%d")
#---The following is to remove AMIs older than 3 days---#
aws ec2 describe-images --owners self --query "Images[?CreationDate<\`${latest_date}\`].{ImageId:ImageId,date:CreationDate,Name:Name,SnapshotId:BlockDeviceMappings[0].Ebs.SnapshotId}" > /tmp/ami-delete.txt
ami_delete=$(cat /tmp/ami-delete.txt)
echo "ami_delete: $ami_delete"
# aws ec2 describe-images --filters "Name=name,Values=`cat /tmp/ami-delete.txt`" | grep -i imageid | awk '{ print  $2 }' > /tmp/image-id.txt

ami_delete_list=$(echo $ami_delete | jq -r '.[] | "\(.ImageId)"')
echo "ami_delete_list: $ami_delete_list"
snap_delete_list=$(echo $ami_delete | jq -r '.[] | "\(.SnapshotId)"')
echo "snap_delete_list: $snap_delete_list"
# aws ec2 describe-images --image-ids $delete_list | grep snap | awk ' { print $4 }' > /tmp/snapshots.txt

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

echo "deleting images"

# aws ec2 deregister-image --image-id $ami_delete_list
# for i in $snap_delete_list; do aws ec2 delete-snapshot --snapshot-id $i ; done


# aws ec2 describe-images \
#     --owners self \
#     --query 'reverse(sort_by(Images,&CreationDate))[:].{id:ImageId,date:CreationDate}'

# aws ec2 describe-images --owners self --query 'Images[?CreationDate<`2022-04-04`].{id:ImageId,date:CreationDate,name:Name}' | jq -r 'list(.id) | from_entries'
# aws ec2 describe-images --owners self --query 'Images[?CreationDate<`2022-04-04`].{id:ImageId,date:CreationDate,name:Name}' | jq -r 'map({key: .name, value: .id}) | from_entries'
# aws ec2 describe-images --owners self --query 'Images[?CreationDate<`2022-04-04`].{id:ImageId,date:CreationDate,name:Name}' | jq -r '.[] | "\(.id)"'

# aws ec2 describe-images --image-ids "ami-027f24a75a0439c2e" "ami-0100d1ee2bc3f68d1"