// =================================================================================================
//
// Name ............: ImageSearchDLL_VS2010.cpp
// Description .....: A C++ image search DLL compatible with Visual Studio 2010
// Author(s) .......: Dao Van Trong - TRONG.PRO
//
// -------------------------------------------------------------------------------------------------
//
// #SECTION# ARCHITECTURAL OVERVIEW
//
// This DLL is designed for high-performance image recognition on the screen.
// Compatible with Visual Studio 2010, without modern C++ features.
//
// The core workflow is as follows:
// 1. The exported `ImageSearch` function is called from an external application (e.g., AutoIt).
// 2. It captures the specified screen region into a pixel buffer.
// 3. It loads the target image(s) from file paths.
// 4. For each image, it iterates through specified scaling factors.
// 5. At each scale, it gets the pixel data of the source image.
// 6. It calls the core `SearchForBitmap` engine, which scans the screen buffer for the source buffer.
// 7. All found matches are collected.
// 8. The results are formatted into a single wide-character string: "{count}[x|y|w|h,x|y|w|h,...]".
// 9. This string is copied into a large, thread-safe static buffer, and a pointer to it is returned.
//
// =================================================================================================

#pragma managed(push, off)

// Standard and Windows Headers
#include <windows.h>

// Define min/max macros before including GDI+ to avoid conflicts
#ifndef max
#define max(a,b) (((a) > (b)) ? (a) : (b))
#endif
#ifndef min
#define min(a,b) (((a) < (b)) ? (a) : (b))
#endif

#include <gdiplus.h>

// Undefine min/max after GDI+ to prevent conflicts with std::min/std::max
#ifdef max
#undef max
#endif
#ifdef min
#undef min
#endif
#include <string>
#include <vector>
#include <algorithm>
#include <sstream>
#include <iomanip>
#include <cmath>

#pragma comment(lib, "gdiplus.lib")

// =================================================================================================
// #BLOCK# GLOBAL GDI+ MANAGER
// Manages global resources and settings for the DLL.
// =================================================================================================

// GDI+ token, managed by DllMain for process-wide initialization and shutdown.
ULONG_PTR g_gdiplusToken;

// =================================================================================================
// #BLOCK# ERROR HANDLING & RESULT TYPES
// Defines a structured way to handle and report errors throughout the DLL.
// =================================================================================================

/**
 * @enum ErrorCode
 * @brief Defines specific error codes that can be returned by the DLL.
 */
enum ErrorCode {
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
    case InvalidPath: return L"Invalid path or image format";
    case FailedToLoadImage: return L"Failed to load image from file";
    case FailedToGetScreenDC: return L"Failed to get screen device context";
    case FailedToCreateCompatibleDC: return L"Failed to create a compatible device context";
    case FailedToCreateCompatibleBitmap: return L"Failed to create a compatible bitmap";
    case BitBltFailed: return L"BitBlt (screen capture) failed";
    case FailedToGetBitmapBits: return L"Failed to get bitmap bits (pixel data)";
    case InvalidSearchRegion: return L"Invalid search region specified";
    case ScalingFailed: return L"Scaling produced an invalid bitmap size";
    case ResultBufferTooSmall: return L"Result string is too large for the internal buffer";
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
    int width;
    int height;
    
    PixelBuffer() : width(0), height(0) {}
};

/**
 * @struct MatchResult
 * @brief Represents a single found match, containing its location and dimensions.
 */
struct MatchResult {
    int x, y, w, h;
    
    MatchResult() : x(0), y(0), w(0), h(0) {}
    MatchResult(int _x, int _y, int _w, int _h) : x(_x), y(_y), w(_w), h(_h) {}
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
inline COLORREF RgbToBgr(DWORD rgb) {
    return ((rgb & 0xFF0000) >> 16) | (rgb & 0x00FF00) | ((rgb & 0x0000FF) << 16);
}

// Helper function to clamp values
template<typename T>
T Clamp(T value, T min_val, T max_val) {
    if (value < min_val) return min_val;
    if (value > max_val) return max_val;
    return value;
}

// Helper functions for min/max
template<typename T>
T Min(T a, T b) {
    return (a < b) ? a : b;
}

template<typename T>
T Max(T a, T b) {
    return (a > b) ? a : b;
}

// Forward declarations for functions defined later in the file.
HBITMAP ScaleBitmap(HBITMAP hBitmap, int newW, int newH);
bool GetBitmapPixels(HBITMAP hBitmap, PixelBuffer& buffer);
HBITMAP CaptureScreenRegion(int iLeft, int iTop, int iRight, int iBottom);

/**
 * @brief Loads an image from a file into an HBITMAP using GDI+.
 * @param file_path The Unicode path to the image file.
 * @return An HBITMAP handle on success, or NULL on failure.
 */
HBITMAP LoadImageFromFile(const std::wstring& file_path) {
    Gdiplus::Bitmap* image = new Gdiplus::Bitmap(file_path.c_str());
    if (image && image->GetLastStatus() == Gdiplus::Ok) {
        HBITMAP hbitmap;
        if (image->GetHBITMAP(Gdiplus::Color(0, 0, 0, 0), &hbitmap) == Gdiplus::Ok) {
            delete image;
            return hbitmap;
        }
    }
    if (image) delete image;
    return NULL;
}

/**
 * @brief Extracts the raw 32-bit pixel data from an HBITMAP into a PixelBuffer.
 * @param hBitmap The handle to the source bitmap.
 * @param buffer The PixelBuffer to fill with pixel data.
 * @return True on success, false on failure.
 */
bool GetBitmapPixels(HBITMAP hBitmap, PixelBuffer& buffer) {
    if (!hBitmap) return false;

    BITMAP bm;
    if (!GetObject(hBitmap, sizeof(BITMAP), &bm)) return false;

    buffer.width = bm.bmWidth;
    buffer.height = bm.bmHeight;
    buffer.pixels.resize(buffer.width * buffer.height);

    BITMAPINFO bmi;
    ZeroMemory(&bmi, sizeof(bmi));
    bmi.bmiHeader.biSize = sizeof(BITMAPINFOHEADER);
    bmi.bmiHeader.biWidth = buffer.width;
    bmi.bmiHeader.biHeight = -buffer.height; // Request a top-down DIB for easier row processing.
    bmi.bmiHeader.biPlanes = 1;
    bmi.bmiHeader.biBitCount = 32;
    bmi.bmiHeader.biCompression = BI_RGB;

    HDC hdcScreen = GetDC(NULL);
    if (!hdcScreen) return false;

    // GetDIBits extracts the pixel data into our vector.
    int result = GetDIBits(hdcScreen, hBitmap, 0, buffer.height, &buffer.pixels[0], &bmi, DIB_RGB_COLORS);
    ReleaseDC(NULL, hdcScreen);

    return (result != 0);
}

/**
 * @brief Scales an HBITMAP to a new width and height.
 * @param hBitmap The source bitmap handle.
 * @param newW The new width.
 * @param newH The new height.
 * @return A handle to the NEW scaled bitmap on success, or NULL on failure.
 */
HBITMAP ScaleBitmap(HBITMAP hBitmap, int newW, int newH) {
    if (!hBitmap || newW <= 0 || newH <= 0) return NULL;

    HDC hdcScreen = GetDC(NULL);
    if (!hdcScreen) return NULL;

    HDC hdcSrc = CreateCompatibleDC(hdcScreen);
    HDC hdcDest = CreateCompatibleDC(hdcScreen);
    HBITMAP hBitmapDest = CreateCompatibleBitmap(hdcScreen, newW, newH);

    // Cleanup resources if any creation failed.
    if (!hdcSrc || !hdcDest || !hBitmapDest) {
        if (hdcSrc) DeleteDC(hdcSrc);
        if (hdcDest) DeleteDC(hdcDest);
        if (hBitmapDest) DeleteObject(hBitmapDest);
        ReleaseDC(NULL, hdcScreen);
        return NULL;
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
    ReleaseDC(NULL, hdcScreen);

    return hBitmapDest;
}

/**
 * @brief Captures a specified rectangular region of the screen into a new HBITMAP.
 * @param iLeft The left coordinate of the region.
 * @param iTop The top coordinate of the region.
 * @param iRight The right coordinate of the region.
 * @param iBottom The bottom coordinate of the region.
 * @return A handle to the NEW bitmap containing the screen capture.
 */
HBITMAP CaptureScreenRegion(int iLeft, int iTop, int iRight, int iBottom) {
    int width = iRight - iLeft;
    int height = iBottom - iTop;

    HDC hdcScreen = GetDC(NULL);
    if (!hdcScreen) return NULL;

    HDC hdcMem = CreateCompatibleDC(hdcScreen);
    HBITMAP hBitmap = CreateCompatibleBitmap(hdcScreen, width, height);

    if (!hdcMem || !hBitmap) {
        if (hdcMem) DeleteDC(hdcMem);
        if (hBitmap) DeleteObject(hBitmap);
        ReleaseDC(NULL, hdcScreen);
        return NULL;
    }

    HBITMAP hOldBitmap = (HBITMAP)SelectObject(hdcMem, hBitmap);
    BitBlt(hdcMem, 0, 0, width, height, hdcScreen, iLeft, iTop, SRCCOPY);
    SelectObject(hdcMem, hOldBitmap);

    DeleteDC(hdcMem);
    ReleaseDC(NULL, hdcScreen);

    return hBitmap;
}

// =================================================================================================
// #BLOCK# PIXEL COMPARISON (SCALAR VERSION ONLY)
// Contains the core pixel-matching algorithm.
// =================================================================================================

/**
 * @brief Performs a pixel-by-pixel comparison with tolerance.
 * @return True if all non-transparent pixels are within tolerance, false otherwise.
 */
bool CheckApproxMatch(
    const PixelBuffer& screen, const PixelBuffer& source,
    int start_x, int start_y, COLORREF transparent_color, int tolerance) {

    for (int y = 0; y < source.height; ++y) {
        for (int x = 0; x < source.width; ++x) {
            COLORREF source_pixel = source.pixels[y * source.width + x];
            if (source_pixel == transparent_color) continue;

            COLORREF screen_pixel = screen.pixels[(start_y + y) * screen.width + (start_x + x)];

            // Compare each color channel (R, G, B) individually.
            int r_diff = abs((int)GetRValue(source_pixel) - (int)GetRValue(screen_pixel));
            int g_diff = abs((int)GetGValue(source_pixel) - (int)GetGValue(screen_pixel));
            int b_diff = abs((int)GetBValue(source_pixel) - (int)GetBValue(screen_pixel));
            
            if (r_diff > tolerance || g_diff > tolerance || b_diff > tolerance) {
                return false;
            }
        }
    }
    return true;
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
            bool found = CheckApproxMatch(screen_buffer, source_buffer, x, y, transparent_color, tolerance);

            if (found) {
                matches.push_back(MatchResult(search_left + x, search_top + y, source_buffer.width, source_buffer.height));
                if (!find_all) return matches; // Optimization: if only one is needed, exit immediately.
            }
        }
    }
    return matches;
}

// Helper function to split string by delimiter
std::vector<std::wstring> SplitString(const std::wstring& str, wchar_t delimiter) {
    std::vector<std::wstring> tokens;
    std::wstring token;
    std::wistringstream tokenStream(str);
    
    while (std::getline(tokenStream, token, delimiter)) {
        if (!token.empty()) {
            tokens.push_back(token);
        }
    }
    return tokens;
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
    // Use a large static buffer. This is the simplest and most stable way
    // to return a string to AutoIt.
    static wchar_t g_szAnswer[262144]; // 256 KB buffer
    g_szAnswer[0] = L'\0';

    std::wstringstream result_stream;

    // --- 1. Parameter Validation and Normalization ---
    iTolerance = Clamp(iTolerance, 0, 255);
    fMinScale = Max(0.1f, fMinScale);
    fMaxScale = Max(fMinScale, fMaxScale);
    fScaleStep = Max(0.01f, fScaleStep);

    int screenWidth = GetSystemMetrics(SM_CXSCREEN);
    int screenHeight = GetSystemMetrics(SM_CYSCREEN);
    iLeft = Max(0, iLeft);
    iTop = Max(0, iTop);
    iRight = (iRight <= 0 || iRight > screenWidth) ? screenWidth : iRight;
    iBottom = (iBottom <= 0 || iBottom > screenHeight) ? screenHeight : iBottom;

    if (iLeft >= iRight || iTop >= iBottom) {
        result_stream << L"{" << static_cast<int>(InvalidSearchRegion) << L"}[" << GetErrorMessage(InvalidSearchRegion) << L"]";
        wcscpy_s(g_szAnswer, _countof(g_szAnswer), result_stream.str().c_str());
        return g_szAnswer;
    }

    // --- 2. Screen Capture ---
    HBITMAP hScreenBitmap = CaptureScreenRegion(iLeft, iTop, iRight, iBottom);
    if (!hScreenBitmap) {
        result_stream << L"{" << static_cast<int>(FailedToCreateCompatibleBitmap) << L"}[" << GetErrorMessage(FailedToCreateCompatibleBitmap) << L"]";
        wcscpy_s(g_szAnswer, _countof(g_szAnswer), result_stream.str().c_str());
        return g_szAnswer;
    }
    
    PixelBuffer screen_buffer;
    bool screen_capture_success = GetBitmapPixels(hScreenBitmap, screen_buffer);
    DeleteObject(hScreenBitmap); // Clean up the screen capture immediately.

    if (!screen_capture_success) {
        result_stream << L"{" << static_cast<int>(FailedToGetBitmapBits) << L"}[" << GetErrorMessage(FailedToGetBitmapBits) << L"]";
        wcscpy_s(g_szAnswer, _countof(g_szAnswer), result_stream.str().c_str());
        return g_szAnswer;
    }

    // --- 3. Multi-Image & Multi-Scale Search Loop ---
    std::vector<MatchResult> all_matches;
    std::wstring file_list_str(sImageFile);
    std::vector<std::wstring> file_paths = SplitString(file_list_str, L'|');

    // Process each file path
    for (size_t file_idx = 0; file_idx < file_paths.size(); ++file_idx) {
        const std::wstring& file_path = file_paths[file_idx];
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
                int newW = static_cast<int>(floor(bm.bmWidth * scale + 0.5)); // round
                int newH = static_cast<int>(floor(bm.bmHeight * scale + 0.5)); // round
                if (newW > 0 && newH > 0) {
                    hBitmapToSearch = ScaleBitmap(hBitmapOrig, newW, newH);
                    scaled = true;
                }
                else {
                    continue; // Skip invalid scales.
                }
            }

            PixelBuffer source_buffer;
            if (GetBitmapPixels(hBitmapToSearch, source_buffer)) {
                std::vector<MatchResult> matches = SearchForBitmap(screen_buffer, source_buffer, iLeft, iTop, iTolerance, RgbToBgr(iTransparent), iFindAllOccurrences != 0);
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
    if (iMultiResults > 0 && match_count > static_cast<size_t>(iMultiResults)) {
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
            << L", Scale=(" << std::fixed << std::setprecision(2) << fMinScale << L"," << fMaxScale << L"," << fScaleStep << L")";
    }

    // --- 6. Final Copy to Static Buffer ---
    std::wstring final_string = result_stream.str();
    if (final_string.length() + 1 > _countof(g_szAnswer)) {
        // If the result is too large, return a specific error.
        swprintf_s(g_szAnswer, _countof(g_szAnswer), L"{%d}[%s]", static_cast<int>(ResultBufferTooSmall), GetErrorMessage(ResultBufferTooSmall));
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
        //Gdiplus::GdiplusShutdown(g_gdiplusToken);
        break;
    }
    return TRUE;
}

#pragma managed(pop)