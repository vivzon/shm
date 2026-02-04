#!/bin/bash

# SHM SSL Issuance Script
# Usage: shm-ssl-issue.sh <domain>

DOMAIN=$1

if [ -z "$DOMAIN" ]; then
    echo "Error: Domain is required."
    exit 1
fi

# Issue SSL via Certbot (Nginx plugin)
# -n: Non-interactive
# --nginx: Use nginx plugin
# --agree-tos: Agree to terms of service
# -m: Email address for renewal notices (could be managed by SHM)
certbot --nginx -d "$DOMAIN" -d "www.$DOMAIN" --non-interactive --agree-tos --redirect

if [ $? -eq 0 ]; then
    echo "SSL certificate for $DOMAIN issued and applied successfully."
else
    echo "Error: Certificate issuance failed for $DOMAIN."
    exit 1
fi
