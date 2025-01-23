#! /bin/bash

# check if cluster node is active and user rights are sufficent for update
if [ ! -w /data/opt/gitea ]; then
  echo "No write access for /data/opt/gitea Maybe inactive cluster node?"
  echo "exiting"
  exit 1
fi

rm -f /tmp/gitea-*

LATEST=$(curl -s -L https://dl.gitea.io/gitea/version.json | jq .latest.version)
LATEST=$(echo ${LATEST} | tr -d \")

# force version
#LATEST=1.15.6

if [ ${#LATEST} -gt 5 ]; then
  echo "updating gitea to version ${LATEST}"
  echo "abort with CTRL + C"
  echo ""
  echo "sleeping for 10 seconds and then continuing with the update to ${LATEST}"
  sleep 10
  cd /tmp/
  wget https://dl.gitea.io/gitea/${LATEST}/gitea-${LATEST}-linux-amd64
  if [ $? -ne 0 ]; then
    echo "Unable to download https://dl.gitea.io/gitea/${LATEST}/gitea-${LATEST}-linux-amd64"
    echo "exiting"
    exit 1
  fi
  wget https://dl.gitea.io/gitea/${LATEST}/gitea-${LATEST}-linux-amd64.sha256
  if [ $? -ne 0 ]; then
    echo "Unable to download https://dl.gitea.io/gitea/${LATEST}/gitea-${LATEST}-linux-amd64.sha256"
    echo "exiting"
    exit 1
  fi
  HASHSUM=$(sha256sum /tmp/gitea-${LATEST}-linux-amd64 | cut -f 1 -d " ")
  $(grep -q $HASHSUM /tmp/gitea-${LATEST}-linux-amd64.sha256)
  if [ $? -ne 0 ]; then
    echo "Hashsum for /tmp/gitea-${LATEST}-linux-amd64 did not match /tmp/gitea-${LATEST}-linux-amd64.sha256"
    echo "exiting"
    exit 1
  fi
  systemctl stop httpd
  service gitea stop
  sleep 1
  cp /tmp/gitea-${LATEST}-linux-amd64 /data/opt/gitea && chown gitea. /data/opt/gitea && chmod 755 /data/opt/gitea
  systemctl start httpd
  service gitea start
  if [ $? -eq 0 ]; then
    echo "gitea successfully restart"
    echo "checking version..."
    /data/opt/gitea -version
  fi
else
  echo "Unable to get latest version number from https://dl.gitea.io/gitea/version.json"
  echo "exiting"
  exit 1
fi
