#!/bin/bash

# Test suite for macOCRmyPDF batch processing
# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

TESTS_PASSED=0
TESTS_FAILED=0
TEST_DIR="test_temp"

# Cleanup function
cleanup() {
    echo -e "\n${BLUE}Cleaning up test files...${NC}"
    rm -rf "$TEST_DIR"
    rm -f ocr-process.log
}

# Setup
setup() {
    echo -e "${BLUE}Setting up test environment...${NC}"
    cleanup
    mkdir -p "$TEST_DIR"

    # Check if we have the test image
    if [ ! -f "in.png" ]; then
        echo -e "${RED}Error: in.png not found. Please ensure test image exists.${NC}"
        exit 1
    fi

    # Check if binary exists
    if [ ! -f "./macocrpdf" ]; then
        echo -e "${YELLOW}Binary not found, compiling...${NC}"
        swiftc macocrpdf.swift -o macocrpdf
        if [ $? -ne 0 ]; then
            echo -e "${RED}Compilation failed!${NC}"
            exit 1
        fi
    fi
}

# Test result helper
assert_success() {
    if [ $? -eq 0 ]; then
        echo -e "${GREEN}✓ PASS${NC}: $1"
        ((TESTS_PASSED++))
        return 0
    else
        echo -e "${RED}✗ FAIL${NC}: $1"
        ((TESTS_FAILED++))
        return 1
    fi
}

assert_file_exists() {
    if [ -f "$1" ]; then
        echo -e "${GREEN}✓ PASS${NC}: File exists: $1"
        ((TESTS_PASSED++))
        return 0
    else
        echo -e "${RED}✗ FAIL${NC}: File does not exist: $1"
        ((TESTS_FAILED++))
        return 1
    fi
}

assert_dir_exists() {
    if [ -d "$1" ]; then
        echo -e "${GREEN}✓ PASS${NC}: Directory exists: $1"
        ((TESTS_PASSED++))
        return 0
    else
        echo -e "${RED}✗ FAIL${NC}: Directory does not exist: $1"
        ((TESTS_FAILED++))
        return 1
    fi
}

assert_file_not_exists() {
    if [ ! -f "$1" ]; then
        echo -e "${GREEN}✓ PASS${NC}: File correctly does not exist: $1"
        ((TESTS_PASSED++))
        return 0
    else
        echo -e "${RED}✗ FAIL${NC}: File should not exist: $1"
        ((TESTS_FAILED++))
        return 1
    fi
}

assert_contains() {
    if grep -q "$2" "$1"; then
        echo -e "${GREEN}✓ PASS${NC}: File contains '$2'"
        ((TESTS_PASSED++))
        return 0
    else
        echo -e "${RED}✗ FAIL${NC}: File does not contain '$2'"
        ((TESTS_FAILED++))
        return 1
    fi
}

# Test 1: Single file mode (backward compatibility)
test_single_file_mode() {
    echo -e "\n${BLUE}=== Test 1: Single File Mode (Backward Compatibility) ===${NC}"

    ./macocrpdf in.png "$TEST_DIR/single-output.pdf" 2>&1 | grep -q "Processing complete"
    assert_success "Single file processing completes"

    assert_file_exists "$TEST_DIR/single-output.pdf"

    # Verify original unchanged
    assert_file_exists "in.png"
}

# Test 2: Directory mode with default output
test_directory_default_mode() {
    echo -e "\n${BLUE}=== Test 2: Directory Mode - Default Output ===${NC}"

    # Create test directory with files
    mkdir -p "$TEST_DIR/docs"
    cp in.png "$TEST_DIR/docs/file1.png"
    cp in.png "$TEST_DIR/docs/file2.png"

    ./macocrpdf "$TEST_DIR/docs/" > /dev/null 2>&1
    assert_success "Directory processing with default output"

    assert_dir_exists "$TEST_DIR/docs-ocr"
    assert_file_exists "$TEST_DIR/docs-ocr/file1.pdf"
    assert_file_exists "$TEST_DIR/docs-ocr/file2.pdf"

    # Verify filenames preserved (no -ocr suffix)
    assert_file_not_exists "$TEST_DIR/docs-ocr/file1-ocr.pdf"

    # Verify originals unchanged
    assert_file_exists "$TEST_DIR/docs/file1.png"
    assert_file_exists "$TEST_DIR/docs/file2.png"
}

# Test 3: Directory mode with custom output
test_directory_custom_output() {
    echo -e "\n${BLUE}=== Test 3: Directory Mode - Custom Output ===${NC}"

    mkdir -p "$TEST_DIR/input"
    mkdir -p "$TEST_DIR/custom-output"
    cp in.png "$TEST_DIR/input/doc1.png"
    cp in.png "$TEST_DIR/input/doc2.png"

    ./macocrpdf "$TEST_DIR/input/" "$TEST_DIR/custom-output/" > /dev/null 2>&1
    assert_success "Directory processing with custom output"

    assert_file_exists "$TEST_DIR/custom-output/doc1.pdf"
    assert_file_exists "$TEST_DIR/custom-output/doc2.pdf"

    # Verify originals unchanged
    assert_file_exists "$TEST_DIR/input/doc1.png"
    assert_file_exists "$TEST_DIR/input/doc2.png"
}

# Test 4: Inplace mode
test_inplace_mode() {
    echo -e "\n${BLUE}=== Test 4: Inplace Mode ===${NC}"

    mkdir -p "$TEST_DIR/inplace"
    cp in.png "$TEST_DIR/inplace/report.png"
    cp in.png "$TEST_DIR/inplace/scan.png"

    # Get checksums of original files before processing
    CHECKSUM1=$(md5 -q "$TEST_DIR/inplace/report.png" 2>/dev/null || md5sum "$TEST_DIR/inplace/report.png" | awk '{print $1}')
    CHECKSUM2=$(md5 -q "$TEST_DIR/inplace/scan.png" 2>/dev/null || md5sum "$TEST_DIR/inplace/scan.png" | awk '{print $1}')

    ./macocrpdf "$TEST_DIR/inplace/" --inplace 2>&1 | grep -q "Created backup directory"
    assert_success "Inplace mode executes"

    assert_dir_exists "$TEST_DIR/inplace-source"
    assert_file_exists "$TEST_DIR/inplace-source/report.png"
    assert_file_exists "$TEST_DIR/inplace-source/scan.png"

    assert_file_exists "$TEST_DIR/inplace/report.pdf"
    assert_file_exists "$TEST_DIR/inplace/scan.pdf"

    # Verify originals moved (not copied)
    assert_file_not_exists "$TEST_DIR/inplace/report.png"
    assert_file_not_exists "$TEST_DIR/inplace/scan.png"

    # CRITICAL: Verify backup files were NOT modified during processing
    CHECKSUM1_AFTER=$(md5 -q "$TEST_DIR/inplace-source/report.png" 2>/dev/null || md5sum "$TEST_DIR/inplace-source/report.png" | awk '{print $1}')
    CHECKSUM2_AFTER=$(md5 -q "$TEST_DIR/inplace-source/scan.png" 2>/dev/null || md5sum "$TEST_DIR/inplace-source/scan.png" | awk '{print $1}')

    if [ "$CHECKSUM1" = "$CHECKSUM1_AFTER" ] && [ "$CHECKSUM2" = "$CHECKSUM2_AFTER" ]; then
        echo -e "${GREEN}✓ PASS${NC}: Backup files remain untouched"
        ((TESTS_PASSED++))
    else
        echo -e "${RED}✗ FAIL${NC}: Backup files were modified during processing!"
        ((TESTS_FAILED++))
    fi
}

# Test 5: Skip behavior for files with existing text layers
test_skip_existing_text_layer() {
    echo -e "\n${BLUE}=== Test 5: Skip Files with Existing Text Layers ===${NC}"

    mkdir -p "$TEST_DIR/skip-test"
    cp in.png "$TEST_DIR/skip-test/new.png"

    # First process to create OCR PDF
    ./macocrpdf "$TEST_DIR/skip-test/" > /dev/null 2>&1

    # Copy OCR'd PDF back to input directory
    cp "$TEST_DIR/skip-test-ocr/new.pdf" "$TEST_DIR/skip-test/already-ocr.pdf"

    # Clear log
    rm -f ocr-process.log

    # Process again
    ./macocrpdf "$TEST_DIR/skip-test/" 2>&1 | grep -q "Skipped.*1"
    assert_success "Files with text layers are skipped"

    # Check log contains skip message
    if [ -f ocr-process.log ]; then
        assert_contains "ocr-process.log" "Skipped already-ocr.pdf"
    fi
}

# Test 6: Error handling for corrupt files
test_error_handling() {
    echo -e "\n${BLUE}=== Test 6: Error Handling for Corrupt Files ===${NC}"

    mkdir -p "$TEST_DIR/error-test"
    cp in.png "$TEST_DIR/error-test/good.png"
    echo "not a pdf" > "$TEST_DIR/error-test/corrupt.pdf"

    # Clear log
    rm -f ocr-process.log

    ./macocrpdf "$TEST_DIR/error-test/" 2>&1 | grep -q "Failed.*1"
    assert_success "Corrupt files are handled gracefully"

    # Verify good file still processed
    assert_file_exists "$TEST_DIR/error-test-ocr/good.pdf"

    # Check log contains error
    if [ -f ocr-process.log ]; then
        assert_contains "ocr-process.log" "Failed corrupt.pdf"
    fi
}

# Test 7: Progress tracking and logging
test_progress_and_logging() {
    echo -e "\n${BLUE}=== Test 7: Progress Tracking and Logging ===${NC}"

    mkdir -p "$TEST_DIR/progress-test"
    cp in.png "$TEST_DIR/progress-test/file1.png"
    cp in.png "$TEST_DIR/progress-test/file2.png"
    cp in.png "$TEST_DIR/progress-test/file3.png"

    # Clear log
    rm -f ocr-process.log

    OUTPUT=$(./macocrpdf "$TEST_DIR/progress-test/" 2>&1)

    # Check progress display
    echo "$OUTPUT" | grep -q "Processing 1/3"
    assert_success "Progress display shows file count"

    echo "$OUTPUT" | grep -q "Processing 2/3"
    assert_success "Progress continues for each file"

    echo "$OUTPUT" | grep -q "=== OCR Processing Complete ==="
    assert_success "Summary report is displayed"

    # Check log file created
    assert_file_exists "ocr-process.log"

    # Check log contents
    assert_contains "ocr-process.log" "OCR Batch Processing Started"
    assert_contains "ocr-process.log" "Found 3 files to process"
    assert_contains "ocr-process.log" "Successfully processed: file1.png"
    assert_contains "ocr-process.log" "OCR Batch Processing Completed"
}

# Test 8: Mixed file types
test_mixed_file_types() {
    echo -e "\n${BLUE}=== Test 8: Mixed File Types (PNG, JPG, PDF) ===${NC}"

    mkdir -p "$TEST_DIR/mixed"
    cp in.png "$TEST_DIR/mixed/image.png"
    cp in.png "$TEST_DIR/mixed/photo.jpg"

    # Create a PDF without text layer by processing an image first
    ./macocrpdf in.png "$TEST_DIR/mixed/scan.pdf" > /dev/null 2>&1

    # Copy to input dir (will be skipped as it has text layer)
    cp "$TEST_DIR/mixed/scan.pdf" "$TEST_DIR/mixed/"

    # Create README (should be ignored)
    echo "test" > "$TEST_DIR/mixed/README.md"

    OUTPUT=$(./macocrpdf "$TEST_DIR/mixed/" 2>&1)

    # Should find 3 files (png, jpg, pdf) and ignore .md
    echo "$OUTPUT" | grep -q "Found 3"
    assert_success "Correctly identifies supported file types"

    assert_file_exists "$TEST_DIR/mixed-ocr/image.pdf"
    assert_file_exists "$TEST_DIR/mixed-ocr/photo.pdf"

    # scan.pdf should be skipped (already has text layer)
    echo "$OUTPUT" | grep -q "Skipped.*1"
    assert_success "PDF with text layer is skipped"
}

# Test 9: Empty directory
test_empty_directory() {
    echo -e "\n${BLUE}=== Test 9: Empty Directory ===${NC}"

    mkdir -p "$TEST_DIR/empty"

    OUTPUT=$(./macocrpdf "$TEST_DIR/empty/" 2>&1)
    echo "$OUTPUT" | grep -q "No supported files found"
    assert_success "Empty directory handled gracefully"
}

# Test 10: Usage messages
test_usage_messages() {
    echo -e "\n${BLUE}=== Test 10: Usage Messages ===${NC}"

    OUTPUT=$(./macocrpdf 2>&1 || true)
    echo "$OUTPUT" | grep -q "Single file:"
    assert_success "Usage message shows single file mode"

    echo "$OUTPUT" | grep -q "Directory:"
    assert_success "Usage message shows directory mode"

    echo "$OUTPUT" | grep -F -q -- "--inplace"
    assert_success "Usage message mentions --inplace flag"
}

# Test 11: Debug mode
test_debug_mode() {
    echo -e "\n${BLUE}=== Test 11: Debug Mode ===${NC}"

    mkdir -p "$TEST_DIR/debug"
    cp in.png "$TEST_DIR/debug/test.png"

    OUTPUT=$(./macocrpdf "$TEST_DIR/debug/" --debug 2>&1)
    echo "$OUTPUT" | grep -q "Detected text:"
    assert_success "Debug mode shows OCR details"
}

# Test 13: Conflicting flags
test_conflicting_flags() {
    echo -e "\n${BLUE}=== Test 13: Conflicting Flags (output dir + --inplace) ===${NC}"

    mkdir -p "$TEST_DIR/conflict"
    cp in.png "$TEST_DIR/conflict/test.png"

    OUTPUT=$(./macocrpdf "$TEST_DIR/conflict/" /tmp/output/ --inplace 2>&1 || true)
    echo "$OUTPUT" | grep -q "Cannot use custom output directory with --inplace"
    assert_success "Error shown for conflicting flags"

    # Verify no processing occurred
    assert_file_not_exists "$TEST_DIR/conflict/test.pdf"
    assert_success "No processing occurred with conflicting flags"
}

# Test 14: Dot directory handling
test_dot_directory() {
    echo -e "\n${BLUE}=== Test 14: Dot Directory (.) Handling ===${NC}"

    # Test default mode with "."
    mkdir -p "$TEST_DIR/dottest"
    cp in.png "$TEST_DIR/dottest/file.png"

    cd "$TEST_DIR/dottest"
    OUTPUT=$(../../macocrpdf . 2>&1)
    cd - > /dev/null

    # Should create dottest-ocr, not .-ocr
    assert_dir_exists "$TEST_DIR/dottest-ocr"
    assert_file_exists "$TEST_DIR/dottest-ocr/file.pdf"

    echo "$OUTPUT" | grep -q "Found 1"
    assert_success "Dot directory processed in default mode"

    # Test inplace mode with "."
    mkdir -p "$TEST_DIR/dottest2"
    cp in.png "$TEST_DIR/dottest2/file2.png"

    cd "$TEST_DIR/dottest2"
    OUTPUT=$(../../macocrpdf . --inplace 2>&1)
    cd - > /dev/null

    # Should create dottest2-source, not .-source
    assert_dir_exists "$TEST_DIR/dottest2-source"
    assert_file_exists "$TEST_DIR/dottest2-source/file2.png"
    assert_file_exists "$TEST_DIR/dottest2/file2.pdf"

    echo "$OUTPUT" | grep -q "dottest2-source"
    assert_success "Dot directory uses actual directory name in inplace mode"
}

# Test 12: Inplace mode with skipped files and subdirectories
test_inplace_with_skipped_files() {
    echo -e "\n${BLUE}=== Test 12: Inplace Mode - Skipped Files & Subdirs Preserved ===${NC}"

    mkdir -p "$TEST_DIR/inplace-skip/archive"
    cp in.png "$TEST_DIR/inplace-skip/new.png"

    # Create a PDF with text layer (will be skipped)
    ./macocrpdf in.png "$TEST_DIR/inplace-skip/existing.pdf" > /dev/null 2>&1

    # Create non-processable files
    echo "readme" > "$TEST_DIR/inplace-skip/README.md"
    echo "old stuff" > "$TEST_DIR/inplace-skip/archive/old.txt"

    OUTPUT=$(./macocrpdf "$TEST_DIR/inplace-skip/" --inplace 2>&1)

    # Verify backup contains ONLY processed files
    assert_dir_exists "$TEST_DIR/inplace-skip-source"
    assert_file_exists "$TEST_DIR/inplace-skip-source/new.png"
    assert_file_not_exists "$TEST_DIR/inplace-skip-source/existing.pdf"
    assert_file_not_exists "$TEST_DIR/inplace-skip-source/README.md"

    # Verify output contains ALL original files
    assert_file_exists "$TEST_DIR/inplace-skip/new.pdf"
    assert_file_exists "$TEST_DIR/inplace-skip/existing.pdf"
    assert_file_exists "$TEST_DIR/inplace-skip/README.md"
    assert_dir_exists "$TEST_DIR/inplace-skip/archive"
    assert_file_exists "$TEST_DIR/inplace-skip/archive/old.txt"

    # Verify the skipped file was reported
    echo "$OUTPUT" | grep -q "Skipped.*1"
    assert_success "Skipped file reported correctly"

    # Verify only processed file is in backup
    if [ -f "$TEST_DIR/inplace-skip-source/new.png" ] && [ ! -f "$TEST_DIR/inplace-skip-source/existing.pdf" ]; then
        echo -e "${GREEN}✓ PASS${NC}: Only processed files backed up, skipped files and subdirs stay in place"
        ((TESTS_PASSED++))
    else
        echo -e "${RED}✗ FAIL${NC}: Backup contains wrong files"
        ((TESTS_FAILED++))
    fi
}

# Run all tests
main() {
    echo -e "${BLUE}╔════════════════════════════════════════════╗${NC}"
    echo -e "${BLUE}║  macOCRmyPDF Batch Processing Test Suite  ║${NC}"
    echo -e "${BLUE}╚════════════════════════════════════════════╝${NC}"

    setup

    test_single_file_mode
    test_directory_default_mode
    test_directory_custom_output
    test_inplace_mode
    test_skip_existing_text_layer
    test_error_handling
    test_progress_and_logging
    test_mixed_file_types
    test_empty_directory
    test_usage_messages
    test_debug_mode
    test_inplace_with_skipped_files
    test_conflicting_flags
    test_dot_directory

    cleanup

    # Summary
    echo -e "\n${BLUE}╔════════════════════════════════════════════╗${NC}"
    echo -e "${BLUE}║             Test Summary                   ║${NC}"
    echo -e "${BLUE}╚════════════════════════════════════════════╝${NC}"
    echo -e "${GREEN}Passed: $TESTS_PASSED${NC}"
    echo -e "${RED}Failed: $TESTS_FAILED${NC}"

    if [ $TESTS_FAILED -eq 0 ]; then
        echo -e "\n${GREEN}✓ All tests passed!${NC}\n"
        exit 0
    else
        echo -e "\n${RED}✗ Some tests failed!${NC}\n"
        exit 1
    fi
}

# Trap to ensure cleanup on exit
trap cleanup EXIT

main
