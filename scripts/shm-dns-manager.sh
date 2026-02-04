#!/bin/bash

# SHM DNS Zone Management Script
# Usage: shm-dns-manager.sh <action> <domain> [args]

ACTION=$1
DOMAIN=$2

if [ -z "$ACTION" ] || [ -z "$DOMAIN" ]; then
    echo "Usage: shm-dns-manager.sh <add|remove|update-record> <domain> [args]"
    exit 1
fi

DNS_DIR="/etc/bind/zones"
ZONES_CONF="/etc/bind/named.conf.local"

case "$ACTION" in
    add)
        # Create zone file from template
        cat <<EOF > "$DNS_DIR/db.$DOMAIN"
\$TTL    604800
@       IN      SOA     ns1.$DOMAIN. admin.$DOMAIN. (
                              1         ; Serial
                         604800         ; Refresh
                          86400         ; Retry
                        2419200         ; Expire
                         604800 )       ; Negative Cache TTL
;
@       IN      NS      ns1.$DOMAIN.
@       IN      NS      ns2.$DOMAIN.
@       IN      A       $(hostname -I | awk '{print $1}')
www     IN      A       $(hostname -I | awk '{print $1}')
ns1     IN      A       $(hostname -I | awk '{print $1}')
ns2     IN      A       $(hostname -I | awk '{print $1}')
EOF
        
        # Add to named.conf.local
        echo "zone \"$DOMAIN\" { type master; file \"$DNS_DIR/db.$DOMAIN\"; };" >> "$ZONES_CONF"
        
        systemctl reload bind9
        echo "DNS Zone for $DOMAIN created."
        ;;
    remove)
        rm "$DNS_DIR/db.$DOMAIN"
        # Remove from named.conf.local (sed command to remove the line)
        sed -i "/zone \"$DOMAIN\"/d" "$ZONES_CONF"
        systemctl reload bind9
        echo "DNS Zone for $DOMAIN removed."
        ;;
    *)
        echo "Unknown action: $ACTION"
        exit 1
        ;;
esac
