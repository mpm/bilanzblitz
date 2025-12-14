#!/usr/bin/env ruby
# frozen_string_literal: true

# This tool requires that all pages have been extracted from the PDF (and stored in the subfolder ./kontenrahmen-pdf/results)
# It will then submit each of these to OpenAI for extraction and print the result.

require 'net/http'
require 'json'
require 'base64'
require 'uri'

# OPENAI_API_KEY='<the key>'

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
      id: "pmpt_693eeb30e4f88193a346cd71584a2fd001d5cd98eba3fcbb",
      version: "1"
    },
    input: [
      {
        role: "user",
        content: [
          { type: "input_text", text: "what's in this image?" },
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

page_files = Dir.glob(File.join(INPUT_DIR, 'result-*.png')).sort

page_files.each do |file|
  # Extract page number from filename
  # match = File.basename(file)
  # next unless match

  # page_num = match[1].to_i

  begin
    puts "OCRing #{file}"
    table = submit_page(file)
    File.write('skr03-ocr-results.txt', "#{table}\n", mode: 'a')
  rescue StandardError => e
    puts "ERROR ocr'ing #{file}: #{e.message}"
    puts e.backtrace.first(5)
  end
end

puts "\n" + "=" * 60
puts "Processing complete!"
puts "Results saved to: skr03-ocr-results.txt"
puts "=" * 60
