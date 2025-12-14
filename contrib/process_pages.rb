#!/usr/bin/env ruby
# frozen_string_literal: true

require 'mini_magick'

# Configuration
INPUT_DIR = 'kontenrahmen-pdf/pages'
OUTPUT_DIR = 'kontenrahmen-pdf/results'
CROP_Y_START = 300
CROP_Y_END = 1997
CROP_HEIGHT = CROP_Y_END - CROP_Y_START
SPLIT_X_ODD = 778
SPLIT_X_EVEN = 707
CONSECUTIVE_PIXELS_THRESHOLD = 30
CHECK_POSITIONS = [30, 90, 150]

# Ensure output directory exists
Dir.mkdir(OUTPUT_DIR) unless Dir.exist?(OUTPUT_DIR)

def white_pixel?(pixel)
  # Consider a pixel white if all RGB values are above 250
  pixel[0] > 250 && pixel[1] > 250 && pixel[2] > 250
end

def has_consecutive_non_white_pixels?(row_data, start_x, width)
  # Check if there are at least CONSECUTIVE_PIXELS_THRESHOLD consecutive non-white pixels
  # starting from start_x
  return false if start_x + CONSECUTIVE_PIXELS_THRESHOLD > width

  consecutive_count = 0

  (start_x...(start_x + CONSECUTIVE_PIXELS_THRESHOLD)).each do |x|
    pixel = row_data[x]
    if white_pixel?(pixel)
      return false
    else
      consecutive_count += 1
    end
  end

  consecutive_count >= CONSECUTIVE_PIXELS_THRESHOLD
end

def find_rows_to_blacken(image_path)
  rows_to_blacken = []

  # Load image for pixel inspection
  img = MiniMagick::Image.open(image_path)
  height = img.height
  width = img.width

  # Get pixel data
  pixels = img.get_pixels

  puts "  Analyzing #{height} rows for horizontal dividers..."

  (0...height).each do |y|
    row_data = pixels[y]

    # Check at different starting positions
    should_blacken = CHECK_POSITIONS.any? do |check_x|
      has_consecutive_non_white_pixels?(row_data, check_x, width)
    end

    rows_to_blacken << y if should_blacken
  end

  puts "  Found #{rows_to_blacken.size} rows to blacken"
  rows_to_blacken
end

def add_horizontal_dividers(image, rows_to_blacken)
  return if rows_to_blacken.empty?

  width = image.width

  # For each row that needs to be black, draw a black line
  rows_to_blacken.each do |y|
    image.combine_options do |c|
      c.fill 'black'
      c.draw "line 0,#{y} #{width - 1},#{y}"
    end
  end
end

def process_page(page_num, input_file)
  puts "\nProcessing page #{page_num}..."

  # Step 1: Crop the image
  img = MiniMagick::Image.open(input_file)
  original_width = img.width

  puts "  Original dimensions: #{img.width}x#{img.height}"
  puts "  Cropping to y=#{CROP_Y_START}..#{CROP_Y_END}"

  img.crop "#{original_width}x#{CROP_HEIGHT}+0+#{CROP_Y_START}"

  # Save temporary cropped image
  temp_cropped = File.join(OUTPUT_DIR, "temp_cropped_#{page_num}.png")
  img.write(temp_cropped)

  # Step 2: Split the page based on odd/even
  split_x = page_num.even? ? SPLIT_X_EVEN : SPLIT_X_ODD
  puts "  Splitting at x=#{split_x} (#{page_num.even? ? 'even' : 'odd'} page)"

  # Part A (left side)
  img_a = MiniMagick::Image.open(temp_cropped)
  img_a.crop "#{split_x}x#{CROP_HEIGHT}+0+0"
  temp_a = File.join(OUTPUT_DIR, "temp_a_#{page_num}.png")
  img_a.write(temp_a)

  # Part B (right side)
  img_b = MiniMagick::Image.open(temp_cropped)
  remaining_width = original_width - split_x
  img_b.crop "#{remaining_width}x#{CROP_HEIGHT}+#{split_x}+0"
  temp_b = File.join(OUTPUT_DIR, "temp_b_#{page_num}.png")
  img_b.write(temp_b)

  # Step 3: Add horizontal dividers
  puts "  Processing part A..."
  rows_a = find_rows_to_blacken(temp_a)
  final_img_a = MiniMagick::Image.open(temp_a)
  add_horizontal_dividers(final_img_a, rows_a)
  output_a = File.join(OUTPUT_DIR, format('result-%02da.png', page_num))
  final_img_a.write(output_a)

  puts "  Processing part B..."
  rows_b = find_rows_to_blacken(temp_b)
  final_img_b = MiniMagick::Image.open(temp_b)
  add_horizontal_dividers(final_img_b, rows_b)
  output_b = File.join(OUTPUT_DIR, format('result-%02db.png', page_num))
  final_img_b.write(output_b)

  # Clean up temporary files
  File.delete(temp_cropped, temp_a, temp_b)

  puts "  ✓ Created #{File.basename(output_a)} and #{File.basename(output_b)}"
end

# Main execution
puts "=" * 60
puts "PDF Page Processing Script"
puts "=" * 60

# Find all page files
page_files = Dir.glob(File.join(INPUT_DIR, 'page-*.png')).sort

if page_files.empty?
  puts "ERROR: No page files found in #{INPUT_DIR}"
  exit 1
end

puts "Found #{page_files.size} pages to process"

page_files.each do |file|
  # Extract page number from filename
  match = File.basename(file).match(/page-(\d+)\.png/)
  next unless match

  page_num = match[1].to_i

  begin
    process_page(page_num, file)
  rescue StandardError => e
    puts "ERROR processing page #{page_num}: #{e.message}"
    puts e.backtrace.first(5)
  end
end

puts "\n" + "=" * 60
puts "Processing complete!"
puts "Results saved to: #{OUTPUT_DIR}"
puts "=" * 60
