#!/bin/bash

# Test script for the API endpoints

echo "Testing API endpoints..."

# 1. Test Health Check
echo "1. Testing health check..."
curl -X GET "http://localhost:5000/health"
echo -e "\n"

# 2. Test Public App List (no API key needed)
echo "2. Testing public app list..."
curl -X GET "http://localhost:5000/api/v1/public/app_list"
echo -e "\n"

# 3. Test Rebrandly service with mock response (no Rebrandly API key)
echo "3. Testing Rebrandly service with mock response..."
curl --location --request POST 'http://localhost:5000/api/v1/external/execute/rebrandly?api_key=8bf1d44c94ffb2e6d3003007cd6c00892b96840f8d250a2417d302d358035c4e' \
--header 'X-API-Key: 8bf1d44c94ffb2e6d3003007cd6c00892b96840f8d250a2417d302d358035c4e' \
--header 'Content-Type: application/json' \
--data-raw '{
  "action": "create_link",
  "destination": "https://www.youtube.com/watch?v=3VmtibKpmXI",
  "slashtag": "t1235adasdhqweest"
}'
echo -e "\n"

# 4. Test Rebrandly service with real API key
echo "4. Testing Rebrandly service with real API key..."
curl --location --request POST 'http://localhost:5000/api/v1/external/execute/rebrandly?api_key=8bf1d44c94ffb2e6d3003007cd6c00892b96840f8d250a2417d302d358035c4e' \
--header 'X-API-Key: 8bf1d44c94ffb2e6d3003007cd6c00892b96840f8d250a2417d302d358035c4e' \
--header 'Content-Type: application/json' \
--data-raw '{
  "action": "create_link",
  "destination": "https://www.youtube.com/watch?v=3VmtibKpmXI",
  "slashtag": "t1235adasdhqweest",
  "rebrandly_api_key": "bdf0d3c2f4204a08b1d2732e87929a76"
}'
echo -e "\n"

echo "Test completed!"