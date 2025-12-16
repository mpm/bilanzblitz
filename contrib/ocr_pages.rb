#!/usr/bin/env ruby
# frozen_string_literal: true

# This tool requires that all pages have been extracted from the PDF (and stored in the subfolder ./kontenrahmen-pdf/results)
# It will then submit each of these to OpenAI for extraction and print the result.

require 'net/http'
require 'json'
require 'base64'
require 'uri'

# OPENAI_API_KEY='<the key>'
ENV['OPENAI_API_KEY'] || raise("Please set OPENAI_API_KEY environment variable")

INPUT_DIR = 'kontenrahmen-pdf/results'

# Function to encode the image
def encode_image(image_path)
  Base64.strict_encode64(File.read(image_path))
end

def submit_page(image_path)
  # Getting the Base64 string
  base64_image = encode_image(image_path)

  # Prepare the request
  uri = URI('https://api.openai.com/v1/responses')
  http = Net::HTTP.new(uri.host, uri.port)
  http.use_ssl = true

  request = Net::HTTP::Post.new(uri.path, {
    'Content-Type' => 'application/json',
    'Authorization' => "Bearer #{ENV['OPENAI_API_KEY']}"
    # 'Authorization' => "Bearer #{OPENAI_API_KEY}"
  })

  request.body = {
    prompt: {
      id: "pmpt_6941d057e7a48195a626f2750ed43f9a05bb88a91753ca6c",
      version: "1"
    },
    input: [
      {
        role: "user",
        content: [
          {
            type: "input_image",
            image_url: "data:image/jpeg;base64,#{base64_image}"
          }
        ]
      }
    ],
    text: {
      format: {
        type: "text"
      }
    },
    reasoning: {},
    max_output_tokens: 5074,
    store: true,
    include: [ "web_search_call.action.sources" ]
  }.to_json

  response = http.request(request)

  result = JSON.parse(response.body)
  # puts "JSON response:"
  # puts result.inspect

  txt = []
  o = result['output']
  o.each do |omsg|
    omsg['content'].each do |content_msg|
      txt << content_msg['text']
    end
  end
  txt.join("\n")
end

OUTPUT_FILE = 'skr03-ocr-results.json'

# Helper to save results
def save_results(results)
  File.write(OUTPUT_FILE, JSON.pretty_generate(results))
  puts "Saved #{results.size} rows to #{OUTPUT_FILE}"
end

# Find all split files
page_files = Dir.glob(File.join(INPUT_DIR, 'result-*-L.png')).sort

# Group by unique row identifier (removes -L.png suffix)
# identifying key: result-{page}{part}-{row}
row_keys = page_files.map { |f| f.sub(/-L\.png$/, '') }.uniq

puts "Found #{row_keys.size} rows to process"

all_results = []

row_keys.each_with_index do |row_key_path, index|
  # Construct paths
  left_file = "#{row_key_path}-L.png"
  right_file = "#{row_key_path}-R.png"
  
  row_result = []
  
  # Process Left
  if File.exist?(left_file)
    puts "[#{index+1}/#{row_keys.size}] Processing Left: #{File.basename(left_file)}"
    begin
       text = submit_page(left_file)
       text = "" if text.strip == "(no text)"
       row_result << text
    rescue StandardError => e
       puts "ERROR processing #{left_file}: #{e.message}"
       row_result << ""
    end
  else
    puts "WARNING: Missing left file #{left_file}"
    row_result << ""
  end

  # Process Right
  if File.exist?(right_file)
    puts "[#{index+1}/#{row_keys.size}] Processing Right: #{File.basename(right_file)}"
    begin
       text = submit_page(right_file)
       text = "" if text.strip == "(no text)"
       row_result << text
    rescue StandardError => e
       puts "ERROR processing #{right_file}: #{e.message}"
       row_result << ""
    end
  else
    puts "WARNING: Missing right file #{right_file}"
    row_result << ""
  end
  
  all_results << row_result
  
  # Incremental Save every 10 rows
  if (index + 1) % 10 == 0
    save_results(all_results)
  end
  
  # Sleep briefly to be nice to API? (Optional)
  # sleep 0.5 
end

# Final Save
save_results(all_results)

puts "\n" + "=" * 60
puts "Processing complete!"
puts "Results saved to: #{OUTPUT_FILE}"
puts "=" * 60
