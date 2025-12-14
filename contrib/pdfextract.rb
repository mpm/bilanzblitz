#!/usr/bin/env ruby
# This script will take the PDF containing the SKR03 accounts and associations with balance sheet positions,
# convert the PDF pages to images, extract the parts that are relevant and tries to use OpenAI's API to
# do reasonable OCR to get the account associations.
# This file should run on the developer's machine, not the dev container, because it needs poppler and imagemagick.
require 'fileutils'

pdf_file = '../local-contrib/11174_Kontenrahmen DATEV SKR 03.pdf'
output_dir = './kontenrahmen-pdf/pages'

dpi = 180

FileUtils.mkdir_p(output_dir) unless Dir.exist?(output_dir)

unless File.exist?(pdf_file)
  puts "Error: PDF file '#{pdf_file}' not found."
  exit 1
end

# Command to convert PDF to images using pdftoppm
command = "pdftoppm -png -r #{dpi} \"#{pdf_file}\" \"#{output_dir}/page\""

puts "Converting '#{pdf_file}' to images at #{dpi} DPI in '#{output_dir}'..."

# Execute the command
puts command
system(command)

if $?.success?
  puts "Conversion completed successfully. Images are saved in '#{output_dir}'."
else
  puts "Error: Conversion failed."
  exit 1
end
