#!/usr/bin/env bash

# Check for root

if [ "$EUID" -ne 0 ]
  then echo "Please run as root"
  exit
fi

# Variables
MAAS_VERSION=3.4
MAAS_DB_USER="maas"
MAAS_DB_PASS="maaspass"
MAAS_DB_NAME="maasdb"
POSTGRES_VERSION=16+257build1.1
POSTGRES_CONFIG_PATH="/etc/postgresql/16/main/pg_hba.conf"

# Install Pacakges
apt update
apt dist-upgrade -y
snap install --channel="$MAAS_VERSION" maas
systemctl disable --now systemd-timesyncd
apt install -y postgresql="$POSTGRES_VERSION"

# Configure Postgres
sudo -i -u postgres psql -c "CREATE USER \"$MAAS_DB_USER\" WITH ENCRYPTED PASSWORD '$MAAS_DB_PASS'"
sudo -i -u postgres createdb -O "$MAAS_DB_USER" "$MAAS_DB_NAME"
echo "host    $MAAS_DB_NAME    $MAAS_DB_USER    0/0     md5" >> "$POSTGRES_CONFIG_PATH"

# Initialize maas
sudo maas init region+rack --database-uri "postgres://$MAAS_DB_USER:$MAAS_DB_PASS@localhost/$MAAS_DB_NAME"

# Setup admin user and credentials

echo "Please enter your information to create admin user"
sudo maas createadmin

