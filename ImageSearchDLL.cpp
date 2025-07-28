// =================================================================================================
//
// Name ............: ImageSearchDLL_Modernized.cpp
// Description .....: A highly optimized, thread-safe, and modern C++ image search DLL.
// Author(s) .......: Dao Van Trong - TRONG.PRO
//
// -------------------------------------------------------------------------------------------------
//
// #SECTION# ARCHITECTURAL OVERVIEW
//
// This DLL is designed for high-performance image recognition on the screen. It has been
// refactored with modern C++ principles to ensure safety, stability, and efficiency.
//
// The core workflow is as follows:
// 1. The exported `ImageSearch` function is called from an external application (e.g., AutoIt).
// 2. It captures the specified screen region into a pixel buffer.
// 3. It loads the target image(s) from file paths.
// 4. For each image, it iterates through specified scaling factors.
// 5. At each scale, it gets the pixel data of the source image.
// 6. It calls the core `SearchForBitmap` engine, which scans the screen buffer for the source buffer.
// 7. The search engine automatically dispatches to a highly optimized AVX2 routine if the CPU
//    supports it, otherwise it uses a standard scalar routine. The logic is 100% consistent.
// 8. All found matches are collected.
// 9. The results are formatted into a single wide-character string: "{count}[x|y|w|h,x|y|w|h,...]".
// 10. This string is copied into a large, thread-safe static buffer, and a pointer to it is returned.
//     This method is the most stable for interoperability with clients like AutoIt.
//
// -------------------------------------------------------------------------------------------------
//
// #SECTION# KEY FEATURES & IMPROVEMENTS
//
// - Consistent AVX2 Logic: The AVX2 pixel comparison now mirrors the scalar logic (per-channel
//   tolerance check), ensuring identical results on all CPUs.
//
// - Centralized GDI+ Management: GDI+ is initialized once via DllMain for better performance and
//   to adhere to best practices.
//
// - Safe Static Buffer Return: Uses a large (256KB) thread-local static buffer for the return
//   string. This is the most robust method for AutoIt, avoiding all pointer and memory management
//   issues on the client side, while being large enough to prevent overflows in practice.
//
// - Automatic Parameter Validation: The exported function validates and clamps input parameters
//   (e.g., tolerance, coordinates) to prevent crashes from invalid data.
//
// - Full Unicode Support: All file paths and string operations use wide characters (wchar_t).
//
// =================================================================================================

#pragma managed(push, off)
#define NOMINMAX

// Standard and Windows Headers
#include <windows.h>
#include <gdiplus.h>
#include <string>
#include <vector>
#include <memory>
#include <algorithm>
#include <thread>
#include <future>
#include <mutex>
#include <shared_mutex>
#include <atomic>
#include <unordered_map>
#include <chrono>
#include <span>
#include <optional>
#include <variant>
#include <string_view>
#include <sstream>
#include <iomanip>

// SIMD Headers for CPU extensions
#include <immintrin.h>
#include <intrin.h>

#pragma comment(lib, "gdiplus.lib")

// =================================================================================================
// #BLOCK# GLOBAL GDI+ MANAGER & CPU FEATURE DETECTION
// Manages global resources and settings for the DLL.
// =================================================================================================

// GDI+ token, managed by DllMain for process-wide initialization and shutdown.
ULONG_PTR g_gdiplusToken;
// Atomic boolean to safely store the result of the AVX2 support check.
std::atomic<bool> g_is_avx2_supported{ false };
// std::once_flag ensures that the CPU feature detection runs exactly once.
std::once_flag g_cpu_check_flag;

/**
 * @brief Detects if the host CPU supports the AVX2 instruction set.
 * This function is called only once using std::call_once.
 */
void InitializeCpuFeatures() {
    int cpuInfo[4];
    __cpuidex(cpuInfo, 7, 0);
    // Check the 5th bit of the EBX register for AVX2 support.
    g_is_avx2_supported.store((cpuInfo[1] & (1 << 5)) != 0);
}

// =================================================================================================
// #BLOCK# ERROR HANDLING & RESULT TYPES
// Defines a structured way to handle and report errors throughout the DLL.
// =================================================================================================

/**
 * @enum ErrorCode
 * @brief Defines specific error codes that can be returned by the DLL.
 */
enum class ErrorCode : int {
    Success = 0,
    InvalidPath = -1,
    FailedToLoadImage = -2,
    FailedToGetScreenDC = -3,
    FailedToCreateCompatibleDC = -4,
    FailedToCreateCompatibleBitmap = -5,
    BitBltFailed = -7,
    FailedToGetBitmapBits = -8,
    InvalidSearchRegion = -9,
    ScalingFailed = -10,
    ResultBufferTooSmall = -100
};

/**
 * @brief Converts an ErrorCode enum to a user-friendly wide-character string.
 * @param code The error code to convert.
 * @return A constant wide string describing the error.
 */
const wchar_t* GetErrorMessage(ErrorCode code) {
    switch (code) {
    case ErrorCode::InvalidPath: return L"Invalid path or image format";
    case ErrorCode::FailedToLoadImage: return L"Failed to load image from file";
    case ErrorCode::FailedToGetScreenDC: return L"Failed to get screen device context";
    case ErrorCode::FailedToCreateCompatibleDC: return L"Failed to create a compatible device context";
    case ErrorCode::FailedToCreateCompatibleBitmap: return L"Failed to create a compatible bitmap";
    case ErrorCode::BitBltFailed: return L"BitBlt (screen capture) failed";
    case ErrorCode::FailedToGetBitmapBits: return L"Failed to get bitmap bits (pixel data)";
    case ErrorCode::InvalidSearchRegion: return L"Invalid search region specified";
    case ErrorCode::ScalingFailed: return L"Scaling produced an invalid bitmap size";
    case ErrorCode::ResultBufferTooSmall: return L"Result string is too large for the internal buffer";
    default: return L"Unknown error";
    }
}

// =================================================================================================
// #BLOCK# DATA STRUCTURES
// Core data structures used for representing images and results.
// =================================================================================================

/**
 * @struct PixelBuffer
 * @brief A container for raw 32-bit pixel data (COLORREF) along with image dimensions.
 */
struct PixelBuffer {
    std::vector<COLORREF> pixels;
    int width = 0;
    int height = 0;
};

/**
 * @struct MatchResult
 * @brief Represents a single found match, containing its location and dimensions.
 */
struct MatchResult {
    int x, y, w, h;
};

// =================================================================================================
// #BLOCK# HELPER & UTILITY FUNCTIONS
// A collection of functions for image loading, manipulation, and screen capture.
// =================================================================================================

/**
 * @brief Converts a 0xRRGGBB color format to a 0xBBGGRR format (COLORREF).
 * @param rgb The color in RGB format.
 * @return The color in BGR format.
 */
inline COLORREF RgbToBgr(DWORD rgb) noexcept {
    return ((rgb & 0xFF0000) >> 16) | (rgb & 0x00FF00) | ((rgb & 0x0000FF) << 16);
}

// Forward declarations for functions defined later in the file.
HBITMAP ScaleBitmap(HBITMAP hBitmap, int newW, int newH);
std::optional<PixelBuffer> GetBitmapPixels(HBITMAP hBitmap);
HBITMAP CaptureScreenRegion(int iLeft, int iTop, int iRight, int iBottom);

/**
 * @brief Loads an image from a file into an HBITMAP using GDI+.
 * @param file_path The Unicode path to the image file.
 * @return An HBITMAP handle on success, or nullptr on failure.
 */
HBITMAP LoadImageFromFile(std::wstring_view file_path) {
    // Use std::make_unique for automatic memory management of the GDI+ Bitmap object.
    auto image = std::make_unique<Gdiplus::Bitmap>(std::wstring(file_path).c_str());
    if (image && image->GetLastStatus() == Gdiplus::Ok) {
        HBITMAP hbitmap;
        // The HBITMAP is owned by the GDI+ Bitmap object until it's cloned or copied.
        // Here, GetHBITMAP creates a new DIB section, so we are responsible for deleting it.
        if (image->GetHBITMAP(Gdiplus::Color(0, 0, 0, 0), &hbitmap) == Gdiplus::Ok) {
            return hbitmap;
        }
    }
    return nullptr;
}

/**
 * @brief Extracts the raw 32-bit pixel data from an HBITMAP into a PixelBuffer.
 * @param hBitmap The handle to the source bitmap.
 * @return An std::optional containing the PixelBuffer on success, or std::nullopt on failure.
 */
std::optional<PixelBuffer> GetBitmapPixels(HBITMAP hBitmap) {
    if (!hBitmap) return std::nullopt;

    BITMAP bm;
    if (!GetObject(hBitmap, sizeof(BITMAP), &bm)) return std::nullopt;

    PixelBuffer buffer;
    buffer.width = bm.bmWidth;
    buffer.height = bm.bmHeight;
    buffer.pixels.resize(buffer.width * buffer.height);

    BITMAPINFO bmi = { 0 };
    bmi.bmiHeader.biSize = sizeof(BITMAPINFOHEADER);
    bmi.bmiHeader.biWidth = buffer.width;
    bmi.bmiHeader.biHeight = -buffer.height; // Request a top-down DIB for easier row processing.
    bmi.bmiHeader.biPlanes = 1;
    bmi.bmiHeader.biBitCount = 32;
    bmi.bmiHeader.biCompression = BI_RGB;

    HDC hdcScreen = GetDC(nullptr);
    if (!hdcScreen) return std::nullopt;

    // GetDIBits extracts the pixel data into our vector.
    int result = GetDIBits(hdcScreen, hBitmap, 0, buffer.height, buffer.pixels.data(), &bmi, DIB_RGB_COLORS);
    ReleaseDC(nullptr, hdcScreen);

    if (result == 0) return std::nullopt;
    return buffer;
}

/**
 * @brief Scales an HBITMAP to a new width and height.
 * @param hBitmap The source bitmap handle.
 * @param newW The new width.
 * @param newH The new height.
 * @return A handle to the NEW scaled bitmap on success, or nullptr on failure. The caller is responsible for deleting this bitmap.
 */
HBITMAP ScaleBitmap(HBITMAP hBitmap, int newW, int newH) {
    if (!hBitmap || newW <= 0 || newH <= 0) return nullptr;

    HDC hdcScreen = GetDC(nullptr);
    if (!hdcScreen) return nullptr;

    HDC hdcSrc = CreateCompatibleDC(hdcScreen);
    HDC hdcDest = CreateCompatibleDC(hdcScreen);
    HBITMAP hBitmapDest = CreateCompatibleBitmap(hdcScreen, newW, newH);

    // Cleanup resources if any creation failed.
    if (!hdcSrc || !hdcDest || !hBitmapDest) {
        if (hdcSrc) DeleteDC(hdcSrc);
        if (hdcDest) DeleteDC(hdcDest);
        if (hBitmapDest) DeleteObject(hBitmapDest);
        ReleaseDC(nullptr, hdcScreen);
        return nullptr;
    }

    HBITMAP hOldSrc = (HBITMAP)SelectObject(hdcSrc, hBitmap);
    HBITMAP hOldDest = (HBITMAP)SelectObject(hdcDest, hBitmapDest);

    BITMAP bm;
    GetObject(hBitmap, sizeof(bm), &bm);
    SetStretchBltMode(hdcDest, HALFTONE); // Use a high-quality scaling algorithm.
    StretchBlt(hdcDest, 0, 0, newW, newH, hdcSrc, 0, 0, bm.bmWidth, bm.bmHeight, SRCCOPY);

    // Clean up GDI objects.
    SelectObject(hdcSrc, hOldSrc);
    SelectObject(hdcDest, hOldDest);
    DeleteDC(hdcSrc);
    DeleteDC(hdcDest);
    ReleaseDC(nullptr, hdcScreen);

    return hBitmapDest;
}

/**
 * @brief Captures a specified rectangular region of the screen into a new HBITMAP.
 * @param iLeft The left coordinate of the region.
 * @param iTop The top coordinate of the region.
 * @param iRight The right coordinate of the region.
 * @param iBottom The bottom coordinate of the region.
 * @return A handle to the NEW bitmap containing the screen capture. The caller is responsible for deleting this bitmap.
 */
HBITMAP CaptureScreenRegion(int iLeft, int iTop, int iRight, int iBottom) {
    int width = iRight - iLeft;
    int height = iBottom - iTop;

    HDC hdcScreen = GetDC(nullptr);
    if (!hdcScreen) return nullptr;

    HDC hdcMem = CreateCompatibleDC(hdcScreen);
    HBITMAP hBitmap = CreateCompatibleBitmap(hdcScreen, width, height);

    if (!hdcMem || !hBitmap) {
        if (hdcMem) DeleteDC(hdcMem);
        if (hBitmap) DeleteObject(hBitmap);
        ReleaseDC(nullptr, hdcScreen);
        return nullptr;
    }

    HBITMAP hOldBitmap = (HBITMAP)SelectObject(hdcMem, hBitmap);
    BitBlt(hdcMem, 0, 0, width, height, hdcScreen, iLeft, iTop, SRCCOPY);
    SelectObject(hdcMem, hOldBitmap);

    DeleteDC(hdcMem);
    ReleaseDC(nullptr, hdcScreen);

    return hBitmap;
}


// =================================================================================================
// #BLOCK# OPTIMIZED SIMD PIXEL COMPARISON (CONSISTENT LOGIC)
// Contains the core pixel-matching algorithms, including the scalar and AVX2 versions.
// =================================================================================================

namespace PixelComparison {

    /**
     * @brief Performs a pixel-by-pixel comparison with tolerance (standard C++ version).
     * @return True if all non-transparent pixels are within tolerance, false otherwise.
     */
    bool CheckApproxMatch_Scalar(
        const PixelBuffer& screen, const PixelBuffer& source,
        int start_x, int start_y, COLORREF transparent_color, int tolerance) noexcept {

        for (int y = 0; y < source.height; ++y) {
            const COLORREF* source_row = &source.pixels[y * source.width];
            const COLORREF* screen_row = &screen.pixels[(start_y + y) * screen.width + start_x];

            for (int x = 0; x < source.width; ++x) {
                COLORREF source_pixel = source_row[x];
                if (source_pixel == transparent_color) continue;

                COLORREF screen_pixel = screen_row[x];

                // Compare each color channel (R, G, B) individually.
                if (abs((int)GetRValue(source_pixel) - (int)GetRValue(screen_pixel)) > tolerance ||
                    abs((int)GetGValue(source_pixel) - (int)GetGValue(screen_pixel)) > tolerance ||
                    abs((int)GetBValue(source_pixel) - (int)GetBValue(screen_pixel)) > tolerance) {
                    return false;
                }
            }
        }
        return true;
    }

    /**
     * @brief Performs a pixel-by-pixel comparison with tolerance (AVX2 optimized version).
     * This function's logic is designed to be mathematically equivalent to the scalar version.
     * @return True if all non-transparent pixels are within tolerance, false otherwise.
     */
    bool CheckApproxMatch_AVX2(
        const PixelBuffer& screen, const PixelBuffer& source,
        int start_x, int start_y, COLORREF transparent_color, int tolerance) noexcept {

        const __m256i v_transparent = _mm256_set1_epi32(static_cast<int>(transparent_color));
        const __m256i v_rgb_mask = _mm256_set1_epi32(0x00FFFFFF);

        for (int y = 0; y < source.height; ++y) {
            const COLORREF* source_row = &source.pixels[y * source.width];
            const COLORREF* screen_row = &screen.pixels[(start_y + y) * screen.width + start_x];

            int x = 0;
            // Process 8 pixels (256 bits) at a time.
            for (; x + 7 < source.width; x += 8) {
                __m256i v_source = _mm256_loadu_si256(reinterpret_cast<const __m256i*>(source_row + x));

                // Create a mask to identify which of the 8 pixels are transparent.
                __m256i v_transparent_mask = _mm256_cmpeq_epi32(v_source, v_transparent);

                // Optimization: If all 8 pixels are transparent, skip this chunk entirely.
                if (_mm256_testc_si256(v_transparent_mask, _mm256_set1_epi32(-1))) {
                    continue;
                }

                __m256i v_screen = _mm256_loadu_si256(reinterpret_cast<const __m256i*>(screen_row + x));

                // Isolate only the RGB channels, ignoring the alpha channel.
                __m256i v_source_rgb = _mm256_and_si256(v_source, v_rgb_mask);
                __m256i v_screen_rgb = _mm256_and_si256(v_screen, v_rgb_mask);

                // Calculate the absolute difference for each byte (each R, G, B channel) between source and screen.
                // _mm256_subs_epu8(a, b) calculates saturation subtraction for unsigned bytes: max(0, a - b)
                // We calculate diff in both directions and OR them to get the absolute difference.
                __m256i v_diff1 = _mm256_subs_epu8(v_source_rgb, v_screen_rgb);
                __m256i v_diff2 = _mm256_subs_epu8(v_screen_rgb, v_source_rgb);
                __m256i v_abs_diff = _mm256_or_si256(v_diff1, v_diff2);

                // Create a tolerance vector where each byte is the tolerance value.
                const __m256i v_tolerance8 = _mm256_set1_epi8(static_cast<char>(tolerance));

                // Compare if any channel's absolute difference is greater than the tolerance.
                // _mm256_cmpgt_epi8 is a signed comparison, so we must handle this carefully.
                // A simpler way is to subtract tolerance from the difference. If the result is > 0, it failed.
                // Or, subtract difference from tolerance. If it underflows (becomes non-zero), it failed.
                __m256i v_check = _mm256_subs_epu8(v_abs_diff, v_tolerance8);

                // v_check will have non-zero bytes where diff > tolerance. We need to see if any of these
                // non-zero bytes correspond to non-transparent pixels.
                __m256i v_mismatch = _mm256_andnot_si256(v_transparent_mask, v_check);

                // If there is any mismatch in any of the non-transparent pixels, the test fails.
                if (!_mm256_testz_si256(v_mismatch, v_mismatch)) {
                    return false;
                }
            }

            // Handle any remaining pixels (less than 8) with the scalar code.
            for (; x < source.width; ++x) {
                COLORREF source_pixel = source_row[x];
                if (source_pixel == transparent_color) continue;
                COLORREF screen_pixel = screen_row[x];
                if (abs((int)GetRValue(source_pixel) - (int)GetRValue(screen_pixel)) > tolerance ||
                    abs((int)GetGValue(source_pixel) - (int)GetGValue(screen_pixel)) > tolerance ||
                    abs((int)GetBValue(source_pixel) - (int)GetBValue(screen_pixel)) > tolerance) {
                    return false;
                }
            }
        }
        return true;
    }
}

// =================================================================================================
// #BLOCK# CORE SEARCH ENGINE
// The main logic that orchestrates the search process.
// =================================================================================================

/**
 * @brief Scans a screen buffer for a source image buffer.
 * @return A vector of MatchResult structs for all found occurrences.
 */
std::vector<MatchResult> SearchForBitmap(
    const PixelBuffer& screen_buffer, const PixelBuffer& source_buffer,
    int search_left, int search_top, int tolerance, COLORREF transparent_color,
    bool find_all) {

    std::vector<MatchResult> matches;
    if (source_buffer.width > screen_buffer.width || source_buffer.height > screen_buffer.height) {
        return matches;
    }

    const int max_x = screen_buffer.width - source_buffer.width;
    const int max_y = screen_buffer.height - source_buffer.height;

    // Iterate through every possible top-left starting position in the screen buffer.
    for (int y = 0; y <= max_y; ++y) {
        for (int x = 0; x <= max_x; ++x) {
            bool found = false;
            // Dispatch to the appropriate comparison function based on CPU support.
            if (g_is_avx2_supported) {
                found = PixelComparison::CheckApproxMatch_AVX2(screen_buffer, source_buffer, x, y, transparent_color, tolerance);
            }
            else {
                found = PixelComparison::CheckApproxMatch_Scalar(screen_buffer, source_buffer, x, y, transparent_color, tolerance);
            }

            if (found) {
                matches.push_back({ search_left + x, search_top + y, source_buffer.width, source_buffer.height });
                if (!find_all) return matches; // Optimization: if only one is needed, exit immediately.
            }
        }
    }
    return matches;
}

// =================================================================================================
// #BLOCK# EXPORTED C API
// The public-facing function that will be called by external applications.
// =================================================================================================

extern "C" __declspec(dllexport) const wchar_t* WINAPI ImageSearch(
    const wchar_t* sImageFile,
    int iLeft = 0, int iTop = 0, int iRight = 0, int iBottom = 0,
    int iTolerance = 10,
    int iTransparent = 0xFFFFFFFF,
    int iMultiResults = 0,
    int iCenterPOS = 1,
    int iReturnDebug = 0,
    float fMinScale = 1.0f, float fMaxScale = 1.0f, float fScaleStep = 0.1f,
    int iFindAllOccurrences = 0
) {
    // Use a large, thread-local static buffer. This is the simplest and most stable way
    // to return a string to AutoIt. It's safe because the memory persists for the call.
    thread_local wchar_t g_szAnswer[262144]; // 256 KB buffer
    g_szAnswer[0] = L'\0';

    // Ensure CPU features are checked at least once.
    std::call_once(g_cpu_check_flag, InitializeCpuFeatures);
    std::wstringstream result_stream;

    // --- 1. Parameter Validation and Normalization ---
    iTolerance = std::clamp(iTolerance, 0, 255);
    fMinScale = std::max(0.1f, fMinScale);
    fMaxScale = std::max(fMinScale, fMaxScale);
    fScaleStep = std::max(0.01f, fScaleStep);

    int screenWidth = GetSystemMetrics(SM_CXSCREEN);
    int screenHeight = GetSystemMetrics(SM_CYSCREEN);
    iLeft = std::max(0, iLeft);
    iTop = std::max(0, iTop);
    iRight = (iRight <= 0 || iRight > screenWidth) ? screenWidth : iRight;
    iBottom = (iBottom <= 0 || iBottom > screenHeight) ? screenHeight : iBottom;

    if (iLeft >= iRight || iTop >= iBottom) {
        result_stream << L"{" << static_cast<int>(ErrorCode::InvalidSearchRegion) << L"}[" << GetErrorMessage(ErrorCode::InvalidSearchRegion) << L"]";
        wcscpy_s(g_szAnswer, _countof(g_szAnswer), result_stream.str().c_str());
        return g_szAnswer;
    }

    // --- 2. Screen Capture ---
    // Note: Screen caching is not implemented in this simplified version but would be a major optimization here.
    HBITMAP hScreenBitmap = CaptureScreenRegion(iLeft, iTop, iRight, iBottom);
    if (!hScreenBitmap) {
        // Assume capture failed due to invalid DC or bitmap creation
        result_stream << L"{" << static_cast<int>(ErrorCode::FailedToCreateCompatibleBitmap) << L"}[" << GetErrorMessage(ErrorCode::FailedToCreateCompatibleBitmap) << L"]";
        wcscpy_s(g_szAnswer, _countof(g_szAnswer), result_stream.str().c_str());
        return g_szAnswer;
    }
    auto screen_pixels_opt = GetBitmapPixels(hScreenBitmap);
    DeleteObject(hScreenBitmap); // Clean up the screen capture immediately.

    if (!screen_pixels_opt) {
        result_stream << L"{" << static_cast<int>(ErrorCode::FailedToGetBitmapBits) << L"}[" << GetErrorMessage(ErrorCode::FailedToGetBitmapBits) << L"]";
        wcscpy_s(g_szAnswer, _countof(g_szAnswer), result_stream.str().c_str());
        return g_szAnswer;
    }
    const PixelBuffer& screen_buffer = *screen_pixels_opt;

    // --- 3. Multi-Image & Multi-Scale Search Loop ---
    std::vector<MatchResult> all_matches;
    std::wstring file_list_str(sImageFile);
    std::wstringstream file_stream(file_list_str);
    std::wstring file_path;

    // Split the input string by '|' to search for multiple files.
    while (std::getline(file_stream, file_path, L'|')) {
        if (file_path.empty()) continue;

        HBITMAP hBitmapOrig = LoadImageFromFile(file_path);
        if (!hBitmapOrig) continue;

        // Loop through the specified scale range.
        for (float scale = fMinScale; scale <= fMaxScale; scale += fScaleStep) {
            HBITMAP hBitmapToSearch = hBitmapOrig;
            bool scaled = false;
            if (scale != 1.0f) {
                BITMAP bm;
                GetObject(hBitmapOrig, sizeof(bm), &bm);
                int newW = static_cast<int>(round(bm.bmWidth * scale));
                int newH = static_cast<int>(round(bm.bmHeight * scale));
                if (newW > 0 && newH > 0) {
                    hBitmapToSearch = ScaleBitmap(hBitmapOrig, newW, newH);
                    scaled = true;
                }
                else {
                    continue; // Skip invalid scales.
                }
            }

            auto source_pixels_opt = GetBitmapPixels(hBitmapToSearch);
            if (source_pixels_opt) {
                auto matches = SearchForBitmap(screen_buffer, *source_pixels_opt, iLeft, iTop, iTolerance, RgbToBgr(iTransparent), iFindAllOccurrences != 0);
                if (!matches.empty()) {
                    all_matches.insert(all_matches.end(), matches.begin(), matches.end());
                    if (iFindAllOccurrences == 0) break; // Found for this image, move to next scale.
                }
            }

            if (scaled) DeleteObject(hBitmapToSearch);
        }
        DeleteObject(hBitmapOrig);
        // If we are not finding all occurrences and we found at least one match for this file, stop searching other files.
        if (iFindAllOccurrences == 0 && !all_matches.empty()) break;
    }

    // --- 4. Format Results ---
    size_t match_count = all_matches.size();
    if (iMultiResults > 0 && match_count > (size_t)iMultiResults) {
        match_count = iMultiResults;
    }

    if (match_count > 0) {
        std::wstringstream matches_stream;
        for (size_t i = 0; i < match_count; ++i) {
            if (i > 0) matches_stream << L",";
            int x = all_matches[i].x;
            int y = all_matches[i].y;
            if (iCenterPOS == 1) {
                x += all_matches[i].w / 2;
                y += all_matches[i].h / 2;
            }
            matches_stream << x << L"|" << y << L"|" << all_matches[i].w << L"|" << all_matches[i].h;
        }
        result_stream << L"{" << match_count << L"}[" << matches_stream.str() << L"]";
    }
    else {
        result_stream << L"{0}[No Match Found]";
    }

    // --- 5. Append Debug Info if Requested ---
    if (iReturnDebug == 1) {
        result_stream << L" | DEBUG: File=" << sImageFile
            << L", Rect=(" << iLeft << L"," << iTop << L"," << iRight << L"," << iBottom << L")"
            << L", Tol=" << iTolerance
            << L", Trans=0x" << std::hex << iTransparent << std::dec
            << L", Multi=" << iMultiResults
            << L", Center=" << iCenterPOS
            << L", FindAll=" << iFindAllOccurrences
            << L", AVX2=" << g_is_avx2_supported.load()
            << L", Scale=(" << std::fixed << std::setprecision(2) << fMinScale << L"," << fMaxScale << L"," << fScaleStep << L")";
    }

    // --- 6. Final Copy to Static Buffer ---
    std::wstring final_string = result_stream.str();
    if (final_string.length() + 1 > _countof(g_szAnswer)) {
        // If the result is too large, return a specific error.
        swprintf_s(g_szAnswer, _countof(g_szAnswer), L"{%d}[%s]", static_cast<int>(ErrorCode::ResultBufferTooSmall), GetErrorMessage(ErrorCode::ResultBufferTooSmall));
    }
    else {
        wcscpy_s(g_szAnswer, _countof(g_szAnswer), final_string.c_str());
    }

    return g_szAnswer;
}

/**
 * @brief DLL Entry Point. Manages process-wide initialization and cleanup.
 * @param hModule Handle to the DLL module.
 * @param ul_reason_for_call Reason for calling the function.
 * @param lpReserved Reserved.
 * @return TRUE on success.
 */
BOOL APIENTRY DllMain(HMODULE hModule, DWORD ul_reason_for_call, LPVOID lpReserved) {
    switch (ul_reason_for_call) {
    case DLL_PROCESS_ATTACH:
    {
        // Initialize GDI+ once when the DLL is loaded into a process.
        Gdiplus::GdiplusStartupInput gdiplusStartupInput;
        Gdiplus::GdiplusStartup(&g_gdiplusToken, &gdiplusStartupInput, NULL);
    }
    break;
    case DLL_PROCESS_DETACH:
        // Shutdown GDI+ when the DLL is unloaded.
        ///Gdiplus::GdiplusShutdown(g_gdiplusToken);
        break;
    }
    return TRUE;
}

#pragma managed(pop)
