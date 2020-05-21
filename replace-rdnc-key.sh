#!/etc/bash

# elevate sudo priviledges
[ "$UID" -eq 0 ] || exec sudo bash "$0" "$@"

# remove auto-generated /etc/rndc.key-file
FILE=/etc/rndc.key
if [ -f "$FILE" ]; then
    echo "removing auto-generated $FILE "
    rm  /etc/rndc.key
fi

# genetare new rndc key and assign proper permissions and group
rndc-confgen -r /dev/urandom > /etc/rndc.conf &&
chmod 640 /etc/rndc.conf &&
chgrp named /etc/rndc.conf

# replace old key if exists in /etc/named.conf
sed -i "/# Use with the following in named.conf, adjusting the allow list as needed:/q" /etc/named.conf
sed -i '/# Use with the following in named.conf, adjusting the allow list as needed:/d' /etc/named.conf

# add new key to file
RNDC_KEY=$(cat /etc/rndc.conf | grep -Pzo "key\s\"rndc-key\"\s{\s*algorithm.*\s*secret.*\s};")

tee -a /etc/named.conf > /dev/null <<EOT
# Use with the following in named.conf, adjusting the allow list as needed:
$RNDC_KEY

controls {
       inet 127.0.0.1 port 953
       allow { 127.0.0.1; }  keys { "rndc-key"; };
};
EOT

# restart service
systemctl restart named

# reload RNDC
rndc reload

# check status of RNDC
rndc status
