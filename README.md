# Mac Vision OCR PDF

Mac Vision OCR PDF cli is a Swift command-line tool that adds invisible, searchable OCR text layers to images and PDFs using Apple's Vision framework.

## Features
- **Image and PDF input support** - Process PNG, JPG, and PDF files
- **Intelligent text layer detection** - Automatically skips PDFs that already have text layers
- **Multi-page PDF support** - Processes all pages in PDF documents
- **Invisible text layer** - OCR text is completely invisible but fully selectable and searchable
- **High-resolution rendering** - 2x retina quality rendering for PDF inputs
- **Accurate text positioning** - OCR text precisely overlays the original image content
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
```sh
./macocrpdf <input_file_path> <output_pdf_path> [--debug]
```

### Examples
- Process a single image:
  ```sh
  ./macocrpdf image.png output.pdf
  ```
- Process a PDF without text layer:
  ```sh
  ./macocrpdf scanned.pdf output.pdf
  ```
- Enable debug mode (shows bounding boxes and recognized text):
  ```sh
  ./macocrpdf image.png output.pdf --debug
  ```

### Behavior
- **PDFs with existing text layers** are automatically skipped to prevent double-processing
- **Image files** (PNG, JPG, JPEG) are converted to searchable PDFs
- **Image-only PDFs** have an invisible OCR text layer added to each page
- All output preserves the original visual appearance with invisible, selectable text

## License
This project is licensed under the MIT License.

## Contributing
Pull requests are welcome! Please open an issue for any major changes first.

## Acknowledgments
This project uses [Apple's Vision framework for OCR](https://developer.apple.com/documentation/vision/locating-and-displaying-recognized-text) and PDFKit for PDF generation.

