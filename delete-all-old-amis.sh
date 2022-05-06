#!/bin/bash

function print_usage {
  echo
  echo "Usage: ./delete-all-old-amis.sh [OPTIONS]"
  echo
  echo "This script can be used to delete old AMI's and snapshots. This script has been tested with AWS Cloudshell."
  echo
  echo "Options:"
  echo
  echo -e "  --days-old\t\tThis set the minimmum age in days to delete AMI's."
  echo
  echo "Example:"
  echo
  echo "  ./delete-all-old-amis.sh"
  echo
  echo "Example:"
  echo
  echo "  ./delete-all-old-amis.sh --days-old 14"
}

function log {
  local -r level="$1"
  local -r message="$2"
  local -r timestamp=$(date +"%Y-%m-%d %H:%M:%S")
  >&2 echo -e "${timestamp} [${level}] [$SCRIPT_NAME] ${message}"
}

function log_info {
  local -r message="$1"
  log "INFO" "$message"
}

function log_warn {
  local -r message="$1"
  log "WARN" "$message"
}

function log_error {
  local -r message="$1"
  log "ERROR" "$message"
}

function main {
    local -r days="$1"
    latest_date=$(date  --date="$days days ago" +"%Y-%m-%d")
    #---The following is to remove AMIs older than $days---#
    aws ec2 describe-images --owners self --query "Images[?CreationDate<\`${latest_date}\`].{ImageId:ImageId,date:CreationDate,Name:Name,SnapshotId:BlockDeviceMappings[0].Ebs.SnapshotId}" > /tmp/ami-delete.txt
    ami_delete=$(cat /tmp/ami-delete.txt)
    echo "ami_delete: $ami_delete"
    # aws ec2 describe-images --filters "Name=name,Values=`cat /tmp/ami-delete.txt`" | grep -i imageid | awk '{ print  $2 }' > /tmp/image-id.txt

    ami_delete_list=$(echo $ami_delete | jq -r '.[] | "\(.ImageId)"')
    # echo "ami_delete_list: $ami_delete_list"
    snap_delete_list=$(echo $ami_delete | jq -r '.[] | "\(.SnapshotId)"')
    # echo "snap_delete_list: $snap_delete_list"

    echo "WARNING: This script will delete ALL images in your account older than $days days"
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
}

function options { # Not all defaults are available as args, however the script has been built to easily alter this.
  local days_old="7"
  local run="true"

  while [[ $# > 0 ]]; do
    local key="$1"
    case "$key" in
      --days-old)
        days_old="$2"
        shift
        ;;
      *)
        log_error "Unrecognized argument: $key"
        print_usage
        run="false"
        ;;
    esac
    shift
  done
  if [[ "$run" == "true" ]]; then
    main "$days_old"
  fi
}

options "$@"