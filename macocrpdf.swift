import AppKit
import CoreText
import Foundation
import NaturalLanguage
import PDFKit
import Vision

let fontScaleX = 0.7 // Magic number. Text wont render in PDF unless we scale it down a little bit against bounding box.
let a4PortraitSize = CGSize(width: 595, height: 842) // A4 portrait dimensions in points

func extractTitle(from text: String) -> String {
    let tagger = NLTagger(tagSchemes: [.nameType])
    tagger.string = text
    var title = "OCR Generated PDF"

    tagger.enumerateTags(
        in: text.startIndex..<text.endIndex, unit: .sentence, scheme: .nameType,
        options: [.omitOther, .joinNames]
    ) { tag, tokenRange in
        if let tag = tag, tag == .organizationName || tag == .personalName || tag == .placeName {
            title = String(text[tokenRange])
            return false  // Stop after finding the first key phrase
        }
        return true
    }

    return title
}

func pdfHasTextLayer(pdfURL: URL) -> Bool {
    guard let pdfDoc = PDFDocument(url: pdfURL) else {
        return false
    }

    for pageIndex in 0..<pdfDoc.pageCount {
        guard let page = pdfDoc.page(at: pageIndex) else { continue }
        if let pageContent = page.string, !pageContent.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            return true
        }
    }

    return false
}

func processImageToPDF(cgImage: CGImage, pdfContext: CGContext, pageBounds: CGRect, debug: Bool) -> String {
    var extractedText = ""

    let request = VNRecognizeTextRequest { request, error in
        guard let results = request.results as? [VNRecognizedTextObservation], error == nil else {
            print("Error: OCR processing failed: \(error?.localizedDescription ?? "Unknown error")")
            return
        }

        for observation in results {
            if let topCandidate = observation.topCandidates(1).first {
                extractedText.append(topCandidate.string + " ")
            }
        }
    }

    request.automaticallyDetectsLanguage = true
    request.usesLanguageCorrection = true
    request.recognitionLevel = .accurate

    let requestHandler = VNImageRequestHandler(cgImage: cgImage, options: [:])
    do {
        try requestHandler.perform([request])
    } catch {
        print("Error: VNImageRequestHandler failed with error: \(error)")
    }

    pdfContext.draw(cgImage, in: pageBounds)

    for observation in request.results ?? [] {
        guard let topCandidate = observation.topCandidates(1).first else { continue }
        let normalizedRect = observation.boundingBox
        let textRect = VNImageRectForNormalizedRect(normalizedRect, Int(pageBounds.size.width), Int(pageBounds.size.height))

        if debug {
            pdfContext.setStrokeColor(NSColor.orange.cgColor)
            pdfContext.stroke(textRect)
            print("Detected text: \(topCandidate.string) at \(textRect)")
        }

        let text = topCandidate.string
        let attributedString = NSAttributedString(
            string: text,
            attributes: [
                .font: CTFontCreateWithName("Helvetica" as CFString, 12, nil),
                .foregroundColor: NSColor.black.cgColor,
            ]
        )

        pdfContext.saveGState()
        pdfContext.setTextDrawingMode(.invisible)
        let widthScale = textRect.width / attributedString.size().width
        let heightScale = textRect.height / attributedString.size().height * fontScaleX
        pdfContext.translateBy(x: textRect.origin.x, y: textRect.origin.y)
        pdfContext.scaleBy(x: widthScale, y: heightScale)
        pdfContext.setLineWidth(1.0 / max(widthScale, heightScale))

        let textPath = CGMutablePath()
        textPath.addRect(
            CGRect(
                x: 0, y: 0, width: attributedString.size().width,
                height: attributedString.size().height / fontScaleX))
        let framesetter = CTFramesetterCreateWithAttributedString(attributedString)
        let textFrame = CTFramesetterCreateFrame(
            framesetter, CFRangeMake(0, attributedString.length), textPath, nil)
        CTFrameDraw(textFrame, pdfContext)
        pdfContext.restoreGState()
    }

    return extractedText
}

func processPDF(from pdfPath: String, outputPDFPath: String, debug: Bool = false) {
    let pdfURL = URL(fileURLWithPath: pdfPath)

    guard let inputPDF = PDFDocument(url: pdfURL) else {
        print("Error: Unable to load PDF at \(pdfPath)")
        return
    }

    if pdfHasTextLayer(pdfURL: pdfURL) {
        print("PDF already has a text layer. Skipping.")
        return
    }

    print("Processing PDF with \(inputPDF.pageCount) page(s)...")

    var allExtractedText = ""
    let pdfData = NSMutableData()
    guard let pdfConsumer = CGDataConsumer(data: pdfData) else { return }

    var firstPageBounds = CGRect(x: 0, y: 0, width: 595, height: 842)
    if let firstPage = inputPDF.page(at: 0) {
        firstPageBounds = firstPage.bounds(for: .mediaBox)
    }

    let pdfMetaData: [CFString: Any] = [
        kCGPDFContextCreator: "Mac Vision OCR PDF",
        kCGPDFContextTitle: "OCR Generated PDF",
        kCGPDFContextSubject: "Text extracted from images",
    ]

    guard let pdfContext = CGContext(
        consumer: pdfConsumer, mediaBox: &firstPageBounds, pdfMetaData as CFDictionary)
    else { return }

    for pageIndex in 0..<inputPDF.pageCount {
        guard let page = inputPDF.page(at: pageIndex) else { continue }

        var pageBounds = page.bounds(for: .mediaBox)
        let scaleFactor = max(
            pageBounds.width / a4PortraitSize.width,
            pageBounds.height / a4PortraitSize.height
        )

        if scaleFactor > 1 {
            pageBounds.size.width = pageBounds.width / scaleFactor
            pageBounds.size.height = pageBounds.height / scaleFactor
        }

        // Render page at high resolution (2x for retina quality)
        let renderScale: CGFloat = 2.0
        let renderSize = CGSize(
            width: page.bounds(for: .mediaBox).width * renderScale,
            height: page.bounds(for: .mediaBox).height * renderScale
        )

        let colorSpace = CGColorSpaceCreateDeviceRGB()
        let bitmapInfo = CGBitmapInfo(rawValue: CGImageAlphaInfo.premultipliedLast.rawValue)

        guard let context = CGContext(
            data: nil,
            width: Int(renderSize.width),
            height: Int(renderSize.height),
            bitsPerComponent: 8,
            bytesPerRow: 0,
            space: colorSpace,
            bitmapInfo: bitmapInfo.rawValue
        ) else {
            print("Warning: Unable to create rendering context for page \(pageIndex + 1)")
            continue
        }

        context.setFillColor(NSColor.white.cgColor)
        context.fill(CGRect(origin: .zero, size: renderSize))

        context.scaleBy(x: renderScale, y: renderScale)

        page.draw(with: .mediaBox, to: context)

        guard let cgImage = context.makeImage() else {
            print("Warning: Unable to get CGImage from page \(pageIndex + 1)")
            continue
        }

        print("Processing page \(pageIndex + 1)/\(inputPDF.pageCount)...")

        pdfContext.beginPage(mediaBox: &pageBounds)
        let pageText = processImageToPDF(cgImage: cgImage, pdfContext: pdfContext, pageBounds: pageBounds, debug: debug)
        allExtractedText.append(pageText)
        pdfContext.endPage()
    }

    pdfContext.closePDF()

    do {
        try pdfData.write(to: URL(fileURLWithPath: outputPDFPath))
        print("PDF saved at \(outputPDFPath)")
    } catch {
        print("Error: Failed to write PDF to file \(outputPDFPath)")
    }
}

func recognizeText(from imagePath: String, outputPDFPath: String, debug: Bool = false) {
    guard let image = NSImage(contentsOfFile: imagePath),
        let cgImage = image.cgImage(forProposedRect: nil, context: nil, hints: nil)
    else {
        print("Error: Unable to load image at \(imagePath)")
        return
    }

    var pageBounds = CGRect(x: 0, y: 0, width: cgImage.width, height: cgImage.height)
    let scaleFactor = max(
        CGFloat(cgImage.width) / a4PortraitSize.width, CGFloat(cgImage.height) / a4PortraitSize.height)
    if scaleFactor > 1 {
        pageBounds.size.width = CGFloat(cgImage.width) / scaleFactor
        pageBounds.size.height = CGFloat(cgImage.height) / scaleFactor
    } else {
        pageBounds.size = CGSize(width: cgImage.width, height: cgImage.height)
    }

    let pdfMetaData: [CFString: Any] = [
        kCGPDFContextCreator: "Mac Vision OCR PDF",
        kCGPDFContextTitle: "OCR Generated PDF",
        kCGPDFContextSubject: "Text extracted from image",
    ]

    let pdfData = NSMutableData()
    guard let pdfConsumer = CGDataConsumer(data: pdfData) else { return }
    guard
        let pdfContext = CGContext(
            consumer: pdfConsumer, mediaBox: &pageBounds, pdfMetaData as CFDictionary)
    else { return }

    pdfContext.beginPage(mediaBox: &pageBounds)
    _ = processImageToPDF(cgImage: cgImage, pdfContext: pdfContext, pageBounds: pageBounds, debug: debug)
    pdfContext.endPage()
    pdfContext.closePDF()

    do {
        try pdfData.write(to: URL(fileURLWithPath: outputPDFPath))
        print("PDF saved at \(outputPDFPath)")
    } catch {
        print("Error: Failed to write PDF to file \(outputPDFPath)")
    }
}

if CommandLine.arguments.count < 3 {
    print("Usage: macocrpdf <input_file_path> <output_pdf_path> [--debug]")
    print("  Supports image files (PNG, JPG, etc.) and PDF files")
    print("  PDF files with existing text layers will be skipped")
    exit(1)
}

let inputFilePath = CommandLine.arguments[1]
let outputPDFPath = CommandLine.arguments[2]
let debugMode = CommandLine.arguments.contains("--debug")

let fileExtension = (inputFilePath as NSString).pathExtension.lowercased()

if fileExtension == "pdf" {
    processPDF(from: inputFilePath, outputPDFPath: outputPDFPath, debug: debugMode)
} else {
    recognizeText(from: inputFilePath, outputPDFPath: outputPDFPath, debug: debugMode)
}
