#!/bin/bash

now() {
        date "+%Y-%m-%d %H:%M:%S"
}

log() {
         echo -e "`now` $@ "
}

check_variables(){
  if [ -z "$buckets" ]; then
    echo "buckets is empty"
    exit 1
  fi
}

cat > ~/.s3cfg <<EOF
[default]
access_key = $S3_ACCESS_KEY
secret_key = $S3_SECRET_KEY
host_base = $S3_ENDPOINT_URL
host_bucket = $S3_ENDPOINT_URL
enable_multipart = True
multipart_chunk_size_mb = 15
use_https = True
EOF


# Set the time in seconds for files older than 7 days
OLDER_THAN=$(($(date +%s) - 604800))

list_objects(){
  s3cmd ls s3://"$1" | awk -F' ' '{print $4}'
}

delete_object() {
	s3cmd del "$1"
}

main(){
  log "script started"
  for i in $buckets
  do
    FILES=$(list_objects "$i")
    for FILE in $FILES
    do
      # Get the modification time of the file in seconds
      MOD_TIME=$(s3cmd ls $FILE | awk -F' ' '{print $1}' | xargs -I {} date +%s -d {})

      # If the modification time is older than 7 days, delete the file
      if [ $MOD_TIME -lt $OLDER_THAN ]; then
        delete_object $FILE
        log "$FILE deleted"
      fi
    done
  done

}

main

