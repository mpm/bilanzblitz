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
CHECK_POSITIONS = [ 30 ]

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

def find_vertical_split_points(image_path)
  # Look for vertical lines scanning from Right to Left
  img = MiniMagick::Image.open(image_path)
  height = img.height
  width = img.width
  pixels = img.get_pixels

  puts "  Scanning for vertical dividers (Right to Left)..."

  col_split_points = []

  # Scan from right to left
  # We expect 2 lines.
  # A vertical line should be mostly black (or at least non-white)

  (width - 1).downto(0) do |x|
    non_white_count = 0
    (0...height).each do |y|
      pixel = pixels[y][x]
      unless white_pixel?(pixel)
        non_white_count += 1
      end
    end

    # If > 50% of column is non-white, consider it a line
    if non_white_count > (height * 0.5)
      # Optimization: Debounce lines. If we just found a line at x+1, ignore this one or group it.
      # Simple approach: If this x is adjacent to the last found x, just update the last found x (finding the "left" edge of the line)
      if !col_split_points.empty? && (col_split_points.last - x).abs < 5
         col_split_points[-1] = x
      else
         col_split_points << x
      end
    end

    break if col_split_points.size >= 2
  end

  # The scan was Right-to-Left, so the first found point is the Right line (higher X),
  # second found point is the Left line (lower X).
  # We want them sorted [x1, x2]
  col_split_points.sort
end

def find_row_split_points(image_path)
  # Renamed from find_rows_to_blacken
  rows_to_split = []

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
    should_split = CHECK_POSITIONS.any? do |check_x|
      has_consecutive_non_white_pixels?(row_data, check_x, width)
    end

    rows_to_split << y if should_split
  end

  # Filter consecutive lines to single split points (take the middle or first of a block)
  # Simple approach: if we have 100, 101, 102 -> just take 101.
  # For now, let's just take all of them and filter during processing if they create tiny rows?
  # Better: group them.
  grouped_splits = []
  current_group = []

  rows_to_split.each do |y|
    if current_group.empty? || (y - current_group.last).abs <= 2
       current_group << y
    else
       # Finish group
       grouped_splits << (current_group.sum / current_group.size) # Midpoint
       current_group = [ y ]
    end
  end
  grouped_splits << (current_group.sum / current_group.size) unless current_group.empty?

  puts "  Found #{grouped_splits.size} split points"
  grouped_splits
end

def process_split_rows(image_path, row_split_points, col_split_points, page_num, suffix)
  img = MiniMagick::Image.open(image_path)
  width = img.width
  height = img.height

  # Define row segments. Start at 0.
  # split points are the lines themselves.
  # segment 1: 0 ... split_point_1
  # segment 2: split_point_1 ... split_point_2
  # ...
  # last segment: split_point_N ... height

  # Add 0 and height to points to make loop generic
  boundaries = [ 0 ] + row_split_points + [ height ]

  # Remove duplicates and sort
  boundaries = boundaries.uniq.sort

  puts "    Slicing into #{boundaries.size - 1} potential rows..."

  row_idx = 0

  (0...(boundaries.size - 1)).each do |i|
    y_start = boundaries[i]
    y_end = boundaries[i+1]

    # Calculate height
    h = y_end - y_start

    # Check for empty/tiny rows (often just the divider line itself)
    if h < 21
       # puts "      Skipping row starting at #{y_start} (height #{h} < 21)"
       next
    end

    # Crop the row
    # We open fresh because we don't want to destructively edit the original object in loop (though clone is better)
    # Using combine_options on a fresh open is safest
    row_img = MiniMagick::Image.open(image_path)
    row_img.combine_options do |c|
      c.crop "#{width}x#{h}+0+#{y_start}"
      c << "+repage"
    end

    # Split Columns
    # If we didn't find columns, fallback?
    # User said: "The middle column is always about 95px wide"
    # If detection fail, we might want to warn.

    cols = []

    if col_split_points.size == 2
       x1, x2 = col_split_points

       # Left Column: 0 .. x1
       left_width = x1
       if left_width > 10
         left_img = MiniMagick::Image.open(row_img.path)
         left_img.combine_options do |c|
            c.crop "#{left_width}x#{h}+0+0"
            c << "+repage"
         end
         cols << left_img
       end

       # Right Column: x2 .. width
       right_width = width - x2
       if right_width > 10
         right_img = MiniMagick::Image.open(row_img.path)
         right_img.combine_options do |c|
            c.crop "#{right_width}x#{h}+#{x2}+0"
            c << "+repage"
         end
         cols << right_img
       end

    else
       puts "      WARNING: Could not detect 2 vertical lines. Keeping full row."
       cols << row_img
    end

    # Save Columns
    cols.each_with_index do |col_img, col_idx|
       # 0 is Left, 1 is Right (effectively)
       side = (col_idx == 0) ? "L" : "R"

       out_name = format('result-%02d%s-%03d-%s.png', page_num, suffix, row_idx, side)
       out_path = File.join(OUTPUT_DIR, out_name)
       col_img.write(out_path)
    end

    row_idx += 1
  end
  puts "      Generated #{row_idx} actual rows."
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

  # Clean up intermediate files
  File.delete(temp_vertical_crop, temp_margins_removed)

  # Step 5: Process Rows and Columns (Replacing horizontal dividers)
  puts "  Step 4: Splitting rows and columns..."

  puts "    Processing part A..."
  rows_a = find_row_split_points(temp_a) # Find horizontal lines
  cols_a = find_vertical_split_points(temp_a) # Find vertical lines
  puts "      Found #{cols_a.size} vertical split points for Part A: #{cols_a.inspect}"
  process_split_rows(temp_a, rows_a, cols_a, page_num, "a")

  puts "    Processing part B..."
  rows_b = find_row_split_points(temp_b)
  cols_b = find_vertical_split_points(temp_b)
  puts "      Found #{cols_b.size} vertical split points for Part B: #{cols_b.inspect}"
  process_split_rows(temp_b, rows_b, cols_b, page_num, "b")

  # Clean up temporary files
  File.delete(temp_a, temp_b)

  puts "  ✓ Processed page #{page_num}"
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
