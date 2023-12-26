FROM debian:11
RUN apt-get update && apt-get install -y vim bash netcat-openbsd redis default-mysql-client s3cmd wget curl postgresql-client p7zip-full
RUN wget https://fastdl.mongodb.org/tools/db/mongodb-database-tools-debian11-x86_64-100.5.3.deb -O mongodb-database-tools.deb
RUN apt install ./mongodb-database-tools.deb
RUN rm -f mongodb-database-tools.deb
ENV ETCD_VER=v3.4.7
ENV GOOGLE_URL=https://storage.googleapis.com/etcd
ENV GITHUB_URL=https://github.com/etcd-io/etcd/releases/download
ENV DOWNLOAD_URL=${GOOGLE_URL}
RUN rm -f /tmp/etcd-${ETCD_VER}-linux-amd64.tar.gz
RUN rm -rf /tmp/etcd-download-test && mkdir -p /tmp/etcd-download-test
RUN curl -L ${DOWNLOAD_URL}/${ETCD_VER}/etcd-${ETCD_VER}-linux-amd64.tar.gz -o /tmp/etcd-${ETCD_VER}-linux-amd64.tar.gz
RUN tar xzvf /tmp/etcd-${ETCD_VER}-linux-amd64.tar.gz -C /tmp/etcd-download-test --strip-components=1
RUN rm -f /tmp/etcd-${ETCD_VER}-linux-amd64.tar.gz
RUN cp /tmp/etcd-download-test/etcd* /usr/local/bin
COPY ["backup.sh", "delete_old_backups.sh", "delete_shr_old_backups.sh", "/script/"]
RUN chmod +x /script/*.sh
CMD ["/script/backup.sh"]