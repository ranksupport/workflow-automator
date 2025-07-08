#!/usr/bin/env ruby

# Debug script to test the API locally
require 'net/http'
require 'json'
require 'uri'

def test_api_endpoint
  # Correct URL with /api/ not /pi/
  uri = URI('http://localhost:5000/api/v1/external/execute/rebrandly')
  uri.query = URI.encode_www_form({
    api_key: '8bf1d44c94ffb2e6d3003007cd6c00892b96840f8d250a2417d302d358035c4e'
  })

  http = Net::HTTP.new(uri.host, uri.port)
  
  request = Net::HTTP::Post.new(uri)
  request['X-API-Key'] = '8bf1d44c94ffb2e6d3003007cd6c00892b96840f8d250a2417d302d358035c4e'
  request['Content-Type'] = 'application/json'
  
  # Test with mock response first (no rebrandly_api_key)
  request.body = {
    action: 'create_link',
    destination: 'https://www.youtube.com/watch?v=3VmtibKpmXI',
    slashtag: 't1235adasdhqweest'
  }.to_json

  puts "Testing API endpoint: #{uri}"
  puts "Request body: #{request.body}"
  puts "Headers: #{request.to_hash}"
  puts "\n--- Response ---"
  
  response = http.request(request)
  puts "Status: #{response.code}"
  puts "Body: #{response.body}"
  
  # Test with real Rebrandly API key
  puts "\n\n--- Testing with Rebrandly API Key ---"
  request.body = {
    action: 'create_link',
    destination: 'https://www.youtube.com/watch?v=3VmtibKpmXI',
    slashtag: 't1235adasdhqweest',
    rebrandly_api_key: 'bdf0d3c2f4204a08b1d2732e87929a76'
  }.to_json
  
  response = http.request(request)
  puts "Status: #{response.code}"
  puts "Body: #{response.body}"
  
rescue => e
  puts "Error: #{e.message}"
  puts "Make sure the server is running on localhost:5000"
end

test_api_endpoint