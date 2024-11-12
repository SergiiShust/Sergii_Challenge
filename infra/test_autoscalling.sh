#!/bin/bash

# Variables
SERVER_IP="98.84.151.122"
REQUESTS=100      # Number of requests to send
CONCURRENCY=10    # Number of concurrent requests

# Function to send a request
send_request() {
    curl -s "http://${SERVER_IP}" > /dev/null
}

# Send requests concurrently
echo "Sending $REQUESTS requests to $SERVER_IP with $CONCURRENCY concurrent requests..."
for ((i=1; i<=REQUESTS; i++)); do
    # Run in background to achieve concurrency
    send_request &
    
    # Limit concurrency by waiting for background jobs if needed
    if (( i % CONCURRENCY == 0 )); then
        wait
    fi
done

# Wait for remaining background jobs to complete
wait
echo "Completed sending requests."
