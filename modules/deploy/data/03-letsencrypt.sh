#!/bin/bash
#
# This file is part of Cisco Modeling Labs
# Copyright (c) 2019-2025, Cisco Systems, Inc.
# All rights reserved.
#

source /provision/common.sh
source /provision/copyfile.sh
source /provision/vars.sh

if ! is_controller; then
    echo "not a controller, exiting"
    return
fi

# define these in extras!
# CFG_UN=""
# CFG_PW=""
# CFG_HN=""
# CFG_EMAIL=""

# if there's no hostname then return immediately (these scripts are sourced)
if [ -z "${CFG_HN}" ]; then
    echo "no hostname configured, exiting"
    return
fi

# update our hostname on DynDNS
IP=$(curl -s4 canhazip.com)
auth=$(echo -n "$CFG_UN:$CFG_PW" | base64)
attempts=5
while [ $attempts -gt 0 ]; do
    status=$(curl -s -o/dev/null \
        -w "%{http_code}" \
        -H "Authorization: Basic $auth" \
        -H "User-Agent: Update Client/v1.0" \
        "https://members.dyndns.org/nic/update?hostname=$CFG_HN&myip=$IP")
    if [ $status -eq 200 ]; then
        break
    fi
    sleep 5
    echo "trying again... ($attempts)"
    ((attempts--))
done

echo

copyfile ${CFG_HN}-fullchain.pem /tmp/fullchain.pem
copyfile ${CFG_HN}-privkey.pem /tmp/privkey.pem

if openssl x509 -text </tmp/fullchain.pem | grep ${CFG_HN}; then
    mkdir -p /etc/letsencrypt/live/$CFG_HN
    mv /tmp/fullchain.pem /etc/letsencrypt/live/$CFG_HN/fullchain.pem
    mv /tmp/privkey.pem /etc/letsencrypt/live/$CFG_HN/privkey.pem
    chmod 400 /etc/letsencrypt/live/$CFG_HN/*.pem
fi

mkdir -p /etc/letsencrypt
cat >/etc/letsencrypt/cli.ini <<EOF
email = $CFG_EMAIL
agree-tos = true
EOF

snap install --classic certbot
ln -s /snap/bin/certbot /usr/bin/certbot

# ONLY request a cert if there's not already one present!
if ! [ -d /etc/letsencrypt/live/$CFG_HN ]; then
    /usr/bin/certbot --domain $CFG_HN --noninteractive --nginx certonly
    # could copy back to the cloud storage here? According to the naming
    # scheme hostname-fullchain.pem and hostname-privkey.pem
fi

# copy the cert to the nginx configuration
mkdir /etc/nginx/oldcerts
mv /etc/nginx/*.pem /etc/nginx/oldcerts/
cp /etc/letsencrypt/live/$CFG_HN/fullchain.pem /etc/nginx/pubkey.pem
cp /etc/letsencrypt/live/$CFG_HN/privkey.pem /etc/nginx/privkey.pem

# write the cert into the file that Cockpit uses, note that Cockpit wants
# the cert only, not the full chain.
cat /etc/letsencrypt/live/$CFG_HN/privkey.pem >/etc/cockpit/ws-certs.d/0-self-signed.key
sed '/-----END CERTIFICATE-----/q' $ /etc/letsencrypt/live/$CFG_HN/fullchain.pem >/etc/cockpit/ws-certs.d/0-self-signed.cert

# reload affected services
systemctl reload nginx
systemctl restart cockpit
