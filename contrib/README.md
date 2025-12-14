# About this directory

This directory contains scripts to help import SKR03 documentation and
transform it into data that can be used by BilanzBlitz.

## Overview

The directory contrib-local/ (not in git) contains PDFs that have the
SKR03.

This PDF will be transformed by a series of steps, resulting in a list
of all SKR03 accounts and mapping to the Bilanz and GuV positions.

## Pipeline

### Preparation

You'll need to setup an API key for OpenAI. This will be stored in
`OPENAI_API_KEY` environment variable.

The Ruby scripts here can be run on the developer machine (since the
required imagemagick and poppler-utils are not present in the dev
container). You'll probably need to install the `mini_magick` gem on the
host machine context.

### Run the pipeline steps

1. Run `ruby pdfextract.rb` to convert all PDF pages into images (180dpi).
2. Run `ruby process_pags.rb` to crop and slice the images into a format
   that is suitable for OCR.
   Check the directory (`kontenrahmen-pdf/results`) for valid output and
   remove the last couple of pages (that contain the footnotes and no
   tables.
3. Run `ruby ocr_pages.rb` to submit each result page to OpenAI for
   ocring (the results will be stored in `skr03-ocr-results.txt`)

### Treat the result
