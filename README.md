# Mac Vision OCR PDF

Mac Vision OCR PDF cli is a Swift command-line tool that adds invisible, searchable OCR text layers to images and PDFs using Apple's Vision framework.

## Features
- **Image and PDF input support** - Process PNG, JPG, and PDF files
- **Batch processing** - Process entire directories and subdirectories of documents at once, preserving directory structure
- **Intelligent text layer detection** - Automatically skips PDFs that already have text layers (override with `--redo-ocr`)
- **Multi-page PDF support** - Processes all pages in PDF documents
- **Invisible text layer** - OCR text is completely invisible but fully selectable and searchable
- **High-resolution rendering** - 2x retina quality rendering for PDF inputs
- **Original quality preservation** - Avoids recompression to maintain pristine quality of original PDFs
- **Accurate text positioning** - OCR text precisely overlays the original image content
- **Safety features** - Never modifies originals, continues on errors, quality verification
- **Progress tracking** - Real-time progress display, explicit logging of output paths, and detailed log files
- **Debug mode** - Visualize recognized text bounding boxes for testing

## How It Works
The tool uses Apple's Vision framework to perform OCR and detect text bounding boxes. The recognized text is then rendered as an **invisible text layer** positioned precisely over the original image content. This creates a search-optimized PDF where:
- The visual appearance remains unchanged (no visible text overlay)
- Text can be selected, copied, and searched
- The PDF is fully searchable by content
- Original image quality is preserved at high resolution

## Requirements
- macOS 12+ (Monterey or later)
- Xcode with Swift support
- Command-line tools for macOS

## Installation
### Build from Source
Compile the project:
   ```sh
   swiftc macocrpdf.swift -o macocrpdf
   ```

## Usage

### Single File Mode
Process a single image or PDF file:
```sh
./macocrpdf <input_file> <output_pdf> [--debug] [--redo-ocr]
```

#### Examples
- Process a single image:
  ```sh
  ./macocrpdf image.png output.pdf
  ```
- Process a PDF without text layer:
  ```sh
  ./macocrpdf scanned.pdf output.pdf
  ```
- Force reprocessing of a PDF that already has a text layer:
  ```sh
  ./macocrpdf scanned.pdf output.pdf --redo-ocr
  ```
- Enable debug mode (shows bounding boxes and recognized text):
  ```sh
  ./macocrpdf image.png output.pdf --debug
  ```

### Directory Batch Mode
Process entire directories of documents:
```sh
./macocrpdf <input_dir> [<output_dir>] [--inplace] [--recursive | -r] [--debug] [--redo-ocr]
```

#### Default Mode
Creates an adjacent directory with `-ocr` suffix:
```sh
./macocrpdf /path/to/documents/
# Creates: /path/to/documents-ocr/
#   ├── file1.pdf
#   ├── file2.pdf
#   └── file3.pdf
```

#### Custom Output Directory
Specify a custom output location:
```sh
./macocrpdf /path/to/documents/ /path/to/output/
# Creates OCR files in: /path/to/output/
```

#### Recursive Mode
Process files in all subdirectories dynamically, preserving the directory structure:
```sh
./macocrpdf /path/to/documents/ --recursive
# Or use the short flag:
./macocrpdf /path/to/documents/ -r
```

#### Inplace Mode
Processes files in place with selective backup (only processed files are backed up):
```sh
./macocrpdf /path/to/documents/ --inplace
# Note: Cannot be combined with custom output directory (mutually exclusive)
# Original:                  After processing:
# documents/                 documents/              documents-source/
# ├── new.png               ├── new.pdf ✅          └── new.png (backup)
# ├── has-text.pdf          ├── has-text.pdf ✅
# ├── README.md       →     ├── README.md ✅
# └── archive/              └── archive/ ✅
#     └── old.txt               └── old.txt
```

**Smart backup strategy**:
- Files that need processing → Moved to `-source` backup BEFORE processing
- PDFs with existing text layers → Stay in place (no backup needed)
- Subdirectories → Stay in place (preserved completely)
- Non-processable files → Stay in place (README, etc.)

**Safety guarantee**: Only files that are actually modified get backed up to `-source`. Everything else stays untouched in the original directory. The backup contains pristine originals of processed files only.

### Batch Processing Features
- **Progress display**: Shows current file count (e.g., "Processing 5/20") and logs specific output paths upon success
- **Automatic skipping**: Files with existing text layers are skipped (override with `--redo-ocr`)
- **Recursive structures**: Preserves directory hierarchy dynamically when processing subdirectories
- **Error resilience**: One failed file doesn't stop the batch
- **Quality verification**: Warns about suspiciously low OCR results
- **Detailed logging**: Creates `ocr-process.log` in current directory
- **Summary report**: Shows processed, skipped, and failed counts

### Behavior
- **PDFs with existing text layers** are automatically skipped to prevent double-processing
- **Image files** (PNG, JPG, JPEG) are converted to searchable PDFs
- **Image-only PDFs** have an invisible OCR text layer added to each page
- **Originals are never modified** in default mode (safe by default)
- **Failed files** are logged but don't interrupt batch processing
- All output preserves the original visual appearance with invisible, selectable text

### Important Notes
- **Conflicting options**: You cannot use both a custom output directory and `--inplace` flag together. They are mutually exclusive:
  - Custom output directory means "put results elsewhere"
  - `--inplace` means "process in the original directory"
  - If both are specified, the tool will exit with an error message

## License
This project is licensed under the MIT License.

## Contributing
Pull requests are welcome! Please open an issue for any major changes first.

## Acknowledgments
This project uses [Apple's Vision framework for OCR](https://developer.apple.com/documentation/vision/locating-and-displaying-recognized-text) and PDFKit for PDF generation.

