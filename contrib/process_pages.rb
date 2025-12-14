#!/usr/bin/env ruby
# frozen_string_literal: true

require 'mini_magick'

# Configuration
INPUT_DIR = 'kontenrahmen-pdf/pages'
OUTPUT_DIR = 'kontenrahmen-pdf/results'
CROP_Y_START = 300
CROP_Y_END = 1997
CROP_HEIGHT = CROP_Y_END - CROP_Y_START
# Margin removal (before split)
MARGIN_X_START_EVEN = 72
MARGIN_X_END_EVEN = 1340
MARGIN_X_START_ODD = 142
MARGIN_X_END_ODD = 1416
# Split position (after margins removed)
SPLIT_X = 636
CONSECUTIVE_PIXELS_THRESHOLD = 30
CHECK_POSITIONS = [30]

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

  # Step 1: Crop the image vertically and save
  img = MiniMagick::Image.open(input_file)
  original_width = img.width

  puts "  Original dimensions: #{img.width}x#{img.height}"
  puts "  Step 1: Cropping vertically to y=#{CROP_Y_START}..#{CROP_Y_END}"

  img.combine_options do |c|
    c.crop "#{original_width}x#{CROP_HEIGHT}+0+#{CROP_Y_START}"
    c << "+repage"
  end

  temp_vertical_crop = File.join(OUTPUT_DIR, "temp_vert_#{page_num}.png")
  img.write(temp_vertical_crop)

  # Step 2: Load vertically cropped image fresh and remove horizontal margins
  img2 = MiniMagick::Image.open(temp_vertical_crop)
  puts "    After vertical crop, image dimensions: #{img2.width}x#{img2.height}"

  is_even = page_num.even?
  margin_x_start = is_even ? MARGIN_X_START_EVEN : MARGIN_X_START_ODD
  margin_x_end = is_even ? MARGIN_X_END_EVEN : MARGIN_X_END_ODD
  content_width = margin_x_end - margin_x_start

  puts "  Step 2: Removing margins: keeping x=#{margin_x_start}..#{margin_x_end} (#{is_even ? 'even' : 'odd'} page, calculated width=#{content_width})"

  img2.combine_options do |c|
    c.crop "#{content_width}x#{CROP_HEIGHT}+#{margin_x_start}+0"
    c << "+repage"
  end

  temp_margins_removed = File.join(OUTPUT_DIR, "temp_margins_#{page_num}.png")
  img2.write(temp_margins_removed)

  # Verify actual dimensions
  img2_verify = MiniMagick::Image.open(temp_margins_removed)
  puts "    After margin removal, actual image dimensions: #{img2_verify.width}x#{img2_verify.height}"

  # Step 3: Load margin-removed image fresh and create split A
  puts "  Step 3: Splitting at x=#{SPLIT_X}"

  img_a = MiniMagick::Image.open(temp_margins_removed)
  puts "    Part A: cropping to width=#{SPLIT_X} from position 0"
  img_a.combine_options do |c|
    c.crop "#{SPLIT_X}x#{CROP_HEIGHT}+0+0"
    c << "+repage"
  end
  temp_a = File.join(OUTPUT_DIR, "temp_a_#{page_num}.png")
  img_a.write(temp_a)

  # Verify part A dimensions
  img_a_verify = MiniMagick::Image.open(temp_a)
  puts "    Part A actual dimensions: #{img_a_verify.width}x#{img_a_verify.height}"

  # Step 4: Load margin-removed image fresh again and create split B
  img_b = MiniMagick::Image.open(temp_margins_removed)
  remaining_width = content_width - SPLIT_X
  puts "    Part B: cropping to width=#{remaining_width} from position #{SPLIT_X}"
  img_b.combine_options do |c|
    c.crop "#{remaining_width}x#{CROP_HEIGHT}+#{SPLIT_X}+0"
    c << "+repage"
  end
  temp_b = File.join(OUTPUT_DIR, "temp_b_#{page_num}.png")
  img_b.write(temp_b)

  # Verify part B dimensions
  img_b_verify = MiniMagick::Image.open(temp_b)
  puts "    Part B actual dimensions: #{img_b_verify.width}x#{img_b_verify.height}"

  # DON'T clean up intermediate files for debugging
  # File.delete(temp_vertical_crop, temp_margins_removed)
  puts "    [DEBUG] Keeping intermediate files: #{File.basename(temp_vertical_crop)}, #{File.basename(temp_margins_removed)}"

  # Step 5: Add horizontal dividers
  puts "  Step 4: Adding horizontal dividers..."
  puts "    Processing part A..."
  rows_a = find_rows_to_blacken(temp_a)
  final_img_a = MiniMagick::Image.open(temp_a)
  add_horizontal_dividers(final_img_a, rows_a)
  output_a = File.join(OUTPUT_DIR, format('result-%02da.png', page_num))
  final_img_a.write(output_a)

  puts "    Processing part B..."
  rows_b = find_rows_to_blacken(temp_b)
  final_img_b = MiniMagick::Image.open(temp_b)
  add_horizontal_dividers(final_img_b, rows_b)
  output_b = File.join(OUTPUT_DIR, format('result-%02db.png', page_num))
  final_img_b.write(output_b)

  # Clean up temporary files
  File.delete(temp_a, temp_b)

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
