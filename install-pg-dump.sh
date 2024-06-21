#!/usr/bin/env bash

set -o errexit -o pipefail -o nounset


if [[ -z "$POSTGRES_VERSION" ]]; then
  echo "POSTGRES_VERSION must be set"
  exit 1
fi

if [[ "$POSTGRES_VERSION" != @(11|12|13|14|15|16) ]]; then
  echo "POSTGRES_VERSION must be one of 11, 12, 13, 14, 15, 16"
  exit 1
fi

[[ $POSTGRES_VERSION == 16 ]] \
    && POSTGRES_DOWNLOAD_URL="http://download.postgresql.org/pub/repos/yum/$POSTGRES_VERSION/redhat/rhel-8-x86_64" \
    || POSTGRES_DOWNLOAD_URL="http://download.postgresql.org/pub/repos/yum/$POSTGRES_VERSION/redhat/rhel-7-x86_64"

cat <<EOF > /etc/yum.repos.d/pgdg.repo
[pgdg$POSTGRES_VERSION]
name=PostgreSQL $POSTGRES_VERSION for RHEL/CentOS - x86_64
baseurl=$POSTGRES_DOWNLOAD_URL
enabled=1
gpgcheck=0
EOF

yum install postgresql$POSTGRES_VERSION -y
