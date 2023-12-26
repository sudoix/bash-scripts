#!/bin/bash
DEST="/tmp/"
PREFIX="backup"
now() {
        date "+%Y-%m-%dT%H:%M:%S"
}

log() {
         echo -e "`now` $@ "
}

now_second(){
        date +%s
}


check_env(){
        if [ -z $NAME ];then
                log "plz give me a name"
                exit 1
        elif [ -z $DB_TYPE ];then
                log "plz give me database type"
		log "DB_TYPE must be one of (mariadb,mongodb,redis,etcd,clickhouse)"
                exit 1
        elif [ -z $DB_PASS ];then
            if [[ "$DB_TYPE" != "redis" ]]; then
                log "plz give me database password"
                exit 1
            fi
        elif [ -z $DB_USER ];then
                log "plz give me database username"
                exit 1
        elif [ -z $DB_HOST ] && [ -z $DB_PORT ];then
                log "plz give me database HOST/IP and PORT"
                exit 1
        elif [ -z $S3_ACCESS_KEY  ];then
                log "plz give me object storage access key"
                exit 1
        elif [ -z $S3_BUCKET_NAME  ];then
                log "plz give me object storage bucket name"
                exit 1
        elif [ -z $SHR_S3_BUCKET_NAME  ];then
                log "plz give me Shahriyar object storage bucket name"
                exit 1
        elif [ -z $S3_SECRET_KEY ];then
                log "plz give me object storage secret key"
                exit 1
        elif [ -z $S3_ENDPOINT_URL  ];then
                log "plz give me object storage endpoint url"
                exit 1
        elif [ -z $STATSD_HOST ] && [ -z $STATSD_PORT ];then
                log "plz give me statsd exporter IP/HOST and PORT"
                exit 1
        elif [ -z $ENCRYPTION_PASSWORD ];then
                log "plz give me a backup encryption password"
                exit 1
        fi
}

check_db_type(){
	case $DB_TYPE in
        mariadb)
                log "db type is mariadb"
                mariadb_backup
                ;;
        postgres)
                log "db type is postgres"
                postgres_backup
                ;;
        mongodb)
                log "db type is mongodb"
                mongodb_backup
                ;;
        redis)
                log "db type is redis"
                redis_backup
                ;;

        etcd)
                log "db type is etcd"
                etcd_backup
                ;;

	clickhosue)
                log "db type is clickhouse"
		;;
        *)
		log "DB_TYPE not found , type must be one of (mariadb,mongodb,redis,etcd,clickhouse)"
                exit 1
        ;;
        esac

}

send_metric(){
        #log "send metric to $STATSD_HOST"
        echo "$PREFIX.$NAME.$1:$2|g" | nc -w 1 -u -t $STATSD_HOST $STATSD_PORT
}

file_size(){
	stat -c %s $1
}

send_to_object(){
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
	SIZE=$(file_size $1)
	send_metric "video_backup_size" $SIZE
        log "start send backup to object storage: $S3_ENDPOINT_URL"
        send_metric "video_start_send_to_object" `now_second`
        s3cmd put $1 s3://$S3_BUCKET_NAME
        log "send backup to object storage finished successfully "
        send_metric "video_finish_send_to_object" `now_second`
}

send_to_shr_object(){
        cat > ~/.s3cfg <<EOF
[default]
access_key = $S3_ACCESS_KEY
secret_key = $S3_SECRET_KEY
host_base = $SHR_S3_ENDPOINT_URL
host_bucket = $SHR_S3_ENDPOINT_URL
enable_multipart = True
multipart_chunk_size_mb = 15
use_https = True
EOF
	SIZE=$(file_size $1)
	send_metric "video_backup_size" $SIZE
        log "start send backup to Shahriyar object storage: $SHR_S3_ENDPOINT_URL"
        send_metric "video_start_send_to_object" `now_second`
        s3cmd put $1 s3://$SHR_S3_BUCKET_NAME
        log "send backup to Shahriyar object storage finished successfully "
        send_metric "video_finish_send_to_object" `now_second`
}

mariadb_check_if_master(){
#        MASTER_STATUS=$(mysql -u $DB_USER -p$DB_PASS -h $DB_HOST -P $DB_PORT -s -e "SELECT COUNT(1) FROM information_schema.processlist WHERE command = 'binlog dump';")

        MASTER_STATUS=1
}

mariadb_backup(){

                mariadb_check_if_master
                if [[ $MASTER_STATUS == 2 || $MASTER_STATUS == 1 ]] ;then
                        log "the address is master"
                        DB_HOST=$DB_HOST
                        OUTPUT="$DEST""$NAME".`now`.sql.gz
                        log "start backup from $DB_HOST and compress it"
                        send_metric "video_start_backup_and_compress" `now_second`
                        mysqldump -u $DB_USER -p$DB_PASS -h $DB_HOST -P $DB_PORT --all-databases --routines --single-transaction --skip-lock-tables --master-data=2 | gzip -9 > $OUTPUT
                        log "backup from $DB_HOST and compressing finished"
                        log "start encrypting backup file"
                        7z a -p$ENCRYPTION_PASSWORD $OUTPUT.7z $OUTPUT
                        log "delete $OUTPUT file"
                        rm -f $OUTPUT
                        OUTPUT=$OUTPUT.7z
                        log "output is $OUTPUT"
                        send_metric "video_finish_backup_and_compress" `now_second`
                        send_to_object $OUTPUT
                        send_to_shr_object $OUTPUT
                        rm -f $OUTPUT

                else
                IFS=,
                set $DB_SLAVES
                for i in $DB_SLAVES
                do
                        DB_HOST=$i
                        OUTPUT="$DEST""$NAME""$i".`now`.sql.gz
                        log "Cant find master!!Start backup from $DB_HOST and compress it"
                        send_metric "video_start_backup_and_compress" `now_second`
                        mysqldump -u $DB_USER -p$DB_PASS -h $DB_HOST -P $DB_PORT --all-databases --routines --single-transaction --skip-lock-tables --master-data=2 | gzip -9 > $OUTPUT
                        log "backup from $DB_HOST and compressing finished"
                        log "start encrypting backup file"
                        7z a -p$ENCRYPTION_PASSWORD $OUTPUT.7z $OUTPUT
                        log "delete $OUTPUT file"
                        rm -f $OUTPUT
                        OUTPUT=$OUTPUT.7z
                        log "output is $OUTPUT"
                        send_metric "video_finish_backup_and_compress" `now_second`
                        send_to_object $OUTPUT
                        send_to_shr_object $OUTPUT
                        rm -f $OUTPUT
                done

                fi


}

postgres_backup(){
	DB_HOST=$DB_HOST
 	send_metric "video_backup_from_slave" 0
	OUTPUT="$DEST""$NAME".`now`.sql.gz
	log "start backup from $DB_HOST and compress it"
	send_metric "video_start_backup_and_compress" `now_second`
	pg_dump -U $DB_USER -F p -h $DB_HOST $DB_NAME -w | gzip -9 > $OUTPUT
	log "backup from $DB_HOST and compressing finished"
        send_metric "video_finish_backup_and_compress" `now_second`
        send_to_object $OUTPUT
        rm -f $OUTPUT

}

mongodb_backup(){
        send_metric "video_backup_from_slave" 0
        OUTPUT="$DEST""$NAME".`now`.gz
        log "start backup from $DB_HOST and compress it"
        send_metric "video_start_backup_and_compress" `now_second`
        mongodump  --host $DB_HOST  -u $DB_USER --port $DB_PORT -p $DB_PASS --gzip --archive=$OUTPUT
        log "backup from $DB_HOST and compressing finished"
        send_metric "video_finish_backup_and_compress" `now_second`
        send_to_object $OUTPUT
        rm -f $OUTPUT
}

redis_bgsave_status() {
        redis-cli -h $DB_HOST -p $DB_PORT info Persistence | grep "rdb_bgsave_in_progress" | awk -F ':' '{print $2} ' | tr -d '\r'
}

redis_find_slave(){
        redis-cli -h $DB_HOST -p $DB_PORT info replication | grep "slave0" | grep "ip" | awk -F ',' '{print $1}' | awk -F '=' '{print $2}'
}

redis_backup(){
        #SLAVE0=$(redis_find_slave)
        if [ -z "$SLAVE0" ];then
                log "cant find any suitable slaves, I go to backup from master"
                DB_HOST=$DB_HOST
                send_metric "video_backup_from_slave" 0
        else
                log "find slave for $DB_HOST slave is: $SLAVE0"
                log "try to backup from slave"
                DB_HOST=$SLAVE0
                send_metric "video_backup_from_slave" 1
        fi

        OUTPUT="$DEST""$NAME".`now`.rdb
        log "start backup from $DB_HOST and compress it"
        send_metric "video_start_backup_and_compress" `now_second`

        if [ -z $DB_PASS ]; then
            redis-cli -h $DB_HOST -p $DB_PORT --rdb $OUTPUT
            while [ "$(redis_bgsave_status $1 $2)" == "1" ]
            do
                log  "backup in progress ....."
                sleep 0.5
            done
        else
            redis-cli -a $DB_PASS -h $DB_HOST -p $DB_PORT --rdb $OUTPUT
            while [ "$(redis_bgsave_status $1 $2)" == "1" ]
            do
                log  "backup in progress ....."
                sleep 0.5
            done
        fi

        gzip -9 $OUTPUT
        OUTPUT=$OUTPUT.gz
        log "backup from $DB_HOST and compressing finished"
        send_metric "video_finish_backup_and_compress" `now_second`
        send_to_object $OUTPUT
        rm -f $OUTPUT
}

etcd_check_env(){
        if [ -z $ETCD_ENDPOINTS ];then
                log "plz give etcd endpoints"
                exit 1
        elif [ ${#ETCD_CACERT} -eq 0 ];then
                log "plz give etcd ca cert"
                exit 1
	elif [ ${#ETCD_CERT} -eq 0 ];then
                log "plz give etcd server cert"
                exit 1
	elif [ ${#ETCD_KEY} -eq 0 ];then
                log "plz give etcd server key"
                exit 1
        fi
}

etcd_backup(){
        etcd_check_env
	echo "$ETCD_CACERT" > /tmp/ca.crt
	echo "$ETCD_CERT" > /tmp/etcd.crt
	echo "$ETCD_KEY" > /tmp/etcd.key
	ETCD_CACERT=/tmp/ca.crt
	ETCD_CERT=/tmp/etcd.crt
	ETCD_KEY=/tmp/etcd.key
        OUTPUT="$DEST""$NAME".`now`.db
        log "start backup from $DB_HOST and compress it"
        send_metric "video_start_backup_and_compress" `now_second`
        ETCDCTL_API=3 etcdctl --endpoints=$ETCD_ENDPOINTS --cacert=$ETCD_CACERT --cert=$ETCD_CERT --key=$ETCD_KEY snapshot save $OUTPUT
        gzip -9 $OUTPUT
        OUTPUT=$OUTPUT.gz
        log "backup from $DB_HOST and compressing finished"
        send_metric "video_finish_backup_and_compress" `now_second`
        send_to_object $OUTPUT
        rm -f $OUTPUT
}

main(){
        log "start backup process"
        check_env
        send_metric "video_start_backup_process_all" `now_second`
        check_db_type
        log "backup process finished"
        send_metric "video_finish_backup_process_all" `now_second`
}
main
