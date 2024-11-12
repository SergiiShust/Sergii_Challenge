#!/bin/bash

# Configuration: Replace with your ALB DNS Name
ALB_DNS_NAME="nginx-alb-1449919506.us-east-1.elb.amazonaws.com"
HTTP_PORT=80
HTTPS_PORT=443
EXPECTED_CONTENT="<h1>Hello World!</h1>"

# 1. Get all IPs of the ALB
 echo "-----------------------------"
echo "Resolving IP addresses for ALB DNS name: $ALB_DNS_NAME..."
ALB_IPS=$(dig +short $ALB_DNS_NAME)

if [[ -z "$ALB_IPS" ]]; then
    echo "❌ Unable to resolve IPs for ALB DNS name: $ALB_DNS_NAME"
else
    echo "✅ Resolved ALB IPs: $ALB_IPS"
fi

echo "-----------------------------"
# 2. Loop through each IP and run tests
for ALB_IP in $ALB_IPS; do
    
    echo "Testing ALB IP: $ALB_IP"

    # Check connectivity on HTTP and HTTPS ports
    echo "Checking connectivity on HTTP (port $HTTP_PORT) and HTTPS (port $HTTPS_PORT)..."

    if nc -zv $ALB_IP $HTTP_PORT 2>/dev/null; then
        echo "✅ HTTP port $HTTP_PORT is open on $ALB_IP"
    else
        echo "❌ HTTP port $HTTP_PORT is not accessible on $ALB_IP"
        continue
    fi

    if nc -zv $ALB_IP $HTTPS_PORT 2>/dev/null; then
        echo "✅ HTTPS port $HTTPS_PORT is open on $ALB_IP"
    else
        echo "❌ HTTPS port $HTTPS_PORT is not accessible on $ALB_IP"
        continue
    fi

    # Verify HTTP to HTTPS redirection
    echo "Verifying HTTP to HTTPS redirection on $ALB_IP..."
    REDIRECT_CODE=$(curl -o /dev/null -s -w "%{http_code}" -L -I http://$ALB_IP)

    if [[ "$REDIRECT_CODE" -eq 301 || "$REDIRECT_CODE" -eq 302 ]]; then
        echo "✅ HTTP redirection is in place with status code $REDIRECT_CODE on $ALB_IP"
    else
        echo "❌ HTTP redirection failed. Expected 301 or 302 but got $REDIRECT_CODE on $ALB_IP"
        continue
    fi

    # Check SSL certificate
    echo "Checking SSL certificate on $ALB_IP..."
    CERT_STATUS=$(echo | openssl s_client -connect $ALB_IP:$HTTPS_PORT -servername $ALB_DNS_NAME 2>/dev/null | openssl x509 -noout -dates)

    if [[ -n "$CERT_STATUS" ]]; then
        echo "✅ SSL certificate is present on $ALB_IP"
    else
        echo "❌ SSL certificate is missing on $ALB_IP"
        continue
    fi

    # Verify content served over HTTPS
    echo "Checking content served over HTTPS on $ALB_IP..."
    RESPONSE_CONTENT=$(curl -ks https://$ALB_IP | grep -o "$EXPECTED_CONTENT")

    if [[ "$RESPONSE_CONTENT" == "$EXPECTED_CONTENT" ]]; then
        echo "✅ Correct content is served on $ALB_IP: $EXPECTED_CONTENT"
    else
        echo "❌ Content check failed on $ALB_IP. Expected: $EXPECTED_CONTENT"
    fi

    echo "Completed tests for $ALB_IP."
    echo "-----------------------------"
done

echo "All IPs have been tested!"
