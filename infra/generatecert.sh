#!/bin/bash

# Set your variables
DOMAIN_NAME="nginx-alb-685300535.us-east-1.elb.amazonaws.com"  # Replace with your domain name
KEY_SIZE=2048              # Key size for the private key
DAYS_VALID=365             # Number of days the self-signed certificate is valid (for testing purposes)

# File names for generated files
PRIVATE_KEY_FILE="${DOMAIN_NAME}.key"
CSR_FILE="${DOMAIN_NAME}.csr"
CERTIFICATE_FILE="${DOMAIN_NAME}.crt"
CERTIFICATE_CHAIN_FILE="${DOMAIN_NAME}_chain.pem"

# Generate the private key
echo "Generating private key..."
openssl genrsa -out "${PRIVATE_KEY_FILE}" "${KEY_SIZE}"
echo "Private key saved to ${PRIVATE_KEY_FILE}"

# Generate the CSR
echo "Generating CSR..."
openssl req -new -key "${PRIVATE_KEY_FILE}" -out "${CSR_FILE}" -subj "/CN=${DOMAIN_NAME}"
echo "CSR saved to ${CSR_FILE}"

# (Optional) Self-sign the certificate (for testing purposes)
echo "Generating self-signed certificate..."
openssl x509 -req -days "${DAYS_VALID}" -in "${CSR_FILE}" -signkey "${PRIVATE_KEY_FILE}" -out "${CERTIFICATE_FILE}"
echo "Self-signed certificate saved to ${CERTIFICATE_FILE}"

# Concatenate the certificate and key to create the certificate chain file
cat "${CERTIFICATE_FILE}" > "${CERTIFICATE_CHAIN_FILE}"
echo "Certificate chain saved to ${CERTIFICATE_CHAIN_FILE}"

echo "Certificate generation completed. Files generated:"
echo "  - Private Key: ${PRIVATE_KEY_FILE}"
echo "  - CSR: ${CSR_FILE}"
echo "  - Certificate: ${CERTIFICATE_FILE} (self-signed for testing)"
echo "  - Certificate Chain: ${CERTIFICATE_CHAIN_FILE}"
