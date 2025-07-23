// =================================================================================================
//
// Name ............: ImageSearchDLL.cpp
// Description .....: A DLL for finding an image on the screen.  
// Author(s) .......: Dao Van Trong - TRONG.PRO
//
// -------------------------------------------------------------------------------------------------
//
// FUNCTIONAL OVERVIEW:
//
// This DLL provides a single exported function, ImageSearch, designed to locate one or more
// sub-images within the main screen display or a specified portion of it. It is built to be
// robust and flexible, supporting a wide range of use cases for screen automation and analysis.
//
// KEY FEATURES:
//
//  - Multi-Image Search: Can search for multiple images in a single call by providing a
//    pipe-separated ('|') list of file paths.
//
//  - Scalability Matching: Allows searching for images that have been resized. You can specify
//    a minimum scale, maximum scale, and step interval (e.g., search from 80% to 120% size
//    in 10% increments).
//
//  - Color Tolerance: Supports approximate matching by allowing a tolerance value (0-255) for
//    color channel variations, making it resilient to minor anti-aliasing or compression
//    artifacts. A tolerance of 0 enforces an exact match.
//
//  - Transparency: A specific color can be designated as transparent, causing pixels of that
//    color in the source image to match any pixel on the screen.
//
//  - Region of Interest (ROI): The search can be confined to a specific rectangular area of
//    the screen for improved performance and accuracy.
//
//  - Multiple Results: The function can be configured to find all occurrences of an image or
//    to stop after finding a specified number of matches.
//
//  - Coordinate Customization: Can return either the top-left corner or the center point of
//    each found image.
//
//  - Broad Format Support: Utilizes GDI+, OLE, and standard WinAPI to load a wide variety of
//    image formats, including PNG, JPG, GIF, BMP, ICO, and icons from EXE/DLL files.
//
//  - Debug Output: An optional parameter enables a detailed debug string to be appended to the
//    result, showing the exact parameters used for the search.
//
// =================================================================================================

#pragma managed(push, off)

// Standard and Windows Headers
#include <windows.h>
#include <stdio.h>
#include <stdlib.h>
#include <olectl.h>
#include <gdiplus.h>
#include <winuser.h>
#include <malloc.h>
#include <shellapi.h>
#include <ctype.h>
#include <tchar.h>
#include <math.h>

// C++ Standard Library Headers
#include <string>
#include <vector>
#include <cstring>
#include <cstdint>
#include <memory>

// Link GDI+ library
#pragma comment(lib, "gdiplus.lib")
//#pragma comment(linker, "/EXPORT:ImageSearch=_ImageSearch@56,ImageSearch,1")
//#pragma comment(linker, "/EXPORT:ImageSearch=_ImageSearch@56,@1")


// =================================================================================================
// MACROS AND INLINE FUNCTIONS
// =================================================================================================

#define CLR_DEFAULT 0x808080 // A default color, often used for backgrounds. (Gray)
#define CLR_NONE    0xFFFFFFFF // Represents no color, used for transparency key.

/**
 * @brief Converts a standard RGB COLORREF to a BGR COLORREF by swapping the red and blue components.
 * @param aRGB The input COLORREF in 0x00RRGGBB format.
 * @return The converted COLORREF in 0x00BBGGRR format.
 */
inline COLORREF rgb_to_bgr(DWORD aRGB) {
    return ((aRGB & 0xFF0000) >> 16) | (aRGB & 0x00FF00) | ((aRGB & 0x0000FF) << 16);
}

/**
 * @brief A wrapper for the MultiByteToWideChar Windows API function.
 * @param source The source narrow-character string (ANSI).
 * @param dest Pointer to the destination wide-character buffer.
 * @param dest_size_in_wchars The size of the destination buffer in wide characters.
 * @return The number of wide characters written to the destination buffer.
 */
inline int ToWideCharFunc(const char* source, wchar_t* dest, int dest_size_in_wchars) {
    return MultiByteToWideChar(CP_ACP, 0, source, -1, dest, dest_size_in_wchars);
}


// =================================================================================================
// HELPER FUNCTIONS (STATIC)
// =================================================================================================

/**
 * @brief Retrieves a descriptive error message for a given error code.
 * @param iErrorCode The integer error code.
 * @return A constant C-style string with the error description.
 */
static const char* GetErrorMessage(int iErrorCode) {
    switch (iErrorCode) {
    case -1:  return "Invalid path or image format";
    case -2:  return "Failed to load image from file";
    case -3:  return "Failed to get screen device context";
    case -4:  return "Failed to create a compatible device context";
    case -5:  return "Failed to create a compatible bitmap";
    case -6:  return "Failed to select bitmap into device context";
    case -7:  return "BitBlt (screen capture) failed";
    case -8:  return "Failed to get bitmap bits (pixel data)";
    case -9:  return "Invalid search region specified";
    case -10: return "Scaling produced an invalid bitmap size";
    default:  return "Unknown error";
    }
}

/**
 * @brief Converts an HICON to a 32-bit HBITMAP.
 * @param ahIcon The handle to the icon.
 * @param aDestroyIcon If true, the original HICON handle will be destroyed.
 * @return A handle to the newly created 32-bit HBITMAP, or NULL on failure.
 */
static HBITMAP IconToBitmap(HICON ahIcon, bool aDestroyIcon) {
    if (!ahIcon) return nullptr;

    ICONINFO iconInfo = { 0 };
    if (!GetIconInfo(ahIcon, &iconInfo)) {
        if (aDestroyIcon) DestroyIcon(ahIcon);
        return nullptr;
    }

    // Get the screen DC
    HDC hdc = GetDC(nullptr);
    if (!hdc) {
        DeleteObject(iconInfo.hbmColor);
        DeleteObject(iconInfo.hbmMask);
        if (aDestroyIcon) DestroyIcon(ahIcon);
        return nullptr;
    }

    // Get bitmap dimensions
    BITMAP bm = { 0 };
    GetObject(iconInfo.hbmColor, sizeof(BITMAP), &bm);
    int width = bm.bmWidth;
    int height = bm.bmHeight;

    // Create a new 32-bit bitmap
    BITMAPINFO bmi = { 0 };
    bmi.bmiHeader.biSize = sizeof(BITMAPINFOHEADER);
    bmi.bmiHeader.biWidth = width;
    bmi.bmiHeader.biHeight = -height; // Top-down DIB
    bmi.bmiHeader.biPlanes = 1;
    bmi.bmiHeader.biBitCount = 32;
    bmi.bmiHeader.biCompression = BI_RGB;

    void* pBits;
    HBITMAP hBitmap = CreateDIBSection(hdc, &bmi, DIB_RGB_COLORS, &pBits, nullptr, 0);
    if (!hBitmap) {
        ReleaseDC(nullptr, hdc);
        DeleteObject(iconInfo.hbmColor);
        DeleteObject(iconInfo.hbmMask);
        if (aDestroyIcon) DestroyIcon(ahIcon);
        return nullptr;
    }

    // Create a compatible DC and draw the icon
    HDC hMemDC = CreateCompatibleDC(hdc);
    if (hMemDC) {
        HBITMAP hOldBitmap = (HBITMAP)SelectObject(hMemDC, hBitmap);

        // Fill background with a default color
        RECT rc = { 0, 0, width, height };
        HBRUSH hBrush = CreateSolidBrush(CLR_DEFAULT);
        FillRect(hMemDC, &rc, hBrush);
        DeleteObject(hBrush);

        // Draw the icon
        DrawIconEx(hMemDC, 0, 0, ahIcon, width, height, 0, nullptr, DI_NORMAL);

        SelectObject(hMemDC, hOldBitmap);
        DeleteDC(hMemDC);
    }

    // Cleanup
    ReleaseDC(nullptr, hdc);
    DeleteObject(iconInfo.hbmColor);
    DeleteObject(iconInfo.hbmMask);
    if (aDestroyIcon) DestroyIcon(ahIcon);

    return hBitmap;
}


/**
 * @brief Scales an HBITMAP to a new width and height.
 * @param hBitmap The source bitmap handle.
 * @param newW The target width.
 * @param newH The target height.
 * @return A handle to the new, scaled HBITMAP, or NULL on failure. The caller is responsible for deleting the returned object.
 */
static HBITMAP ScaleBitmap(HBITMAP hBitmap, int newW, int newH) {
    if (!hBitmap || newW <= 0 || newH <= 0) return nullptr;

    HDC hdcScreen = GetDC(nullptr);
    if (!hdcScreen) return nullptr;

    // Create source DC
    HDC hdcSrc = CreateCompatibleDC(hdcScreen);
    if (!hdcSrc) {
        ReleaseDC(nullptr, hdcScreen);
        return nullptr;
    }
    HBITMAP hOldSrc = (HBITMAP)SelectObject(hdcSrc, hBitmap);

    BITMAP bm;
    GetObject(hBitmap, sizeof(bm), &bm);

    // Create destination DC and bitmap
    HDC hdcDest = CreateCompatibleDC(hdcScreen);
    if (!hdcDest) {
        SelectObject(hdcSrc, hOldSrc);
        DeleteDC(hdcSrc);
        ReleaseDC(nullptr, hdcScreen);
        return nullptr;
    }

    HBITMAP hBitmapDest = CreateCompatibleBitmap(hdcScreen, newW, newH);
    if (!hBitmapDest) {
        DeleteDC(hdcDest);
        SelectObject(hdcSrc, hOldSrc);
        DeleteDC(hdcSrc);
        ReleaseDC(nullptr, hdcScreen);
        return nullptr;
    }
    HBITMAP hOldDest = (HBITMAP)SelectObject(hdcDest, hBitmapDest);

    // Perform the scaling
    SetStretchBltMode(hdcDest, HALFTONE);
    StretchBlt(hdcDest, 0, 0, newW, newH, hdcSrc, 0, 0, bm.bmWidth, bm.bmHeight, SRCCOPY);

    // Cleanup
    SelectObject(hdcSrc, hOldSrc);
    SelectObject(hdcDest, hOldDest);
    DeleteDC(hdcSrc);
    DeleteDC(hdcDest);
    ReleaseDC(nullptr, hdcScreen);

    return hBitmapDest;
}

/**
 * @brief Loads an image from a file into an HBITMAP, trying various methods.
 * @param sFileImage Path to the image file. Can be an EXE/DLL for icon extraction.
 * @param iWidth Desired width. If -1, aspect ratio is preserved based on iHeight.
 * @param iHeight Desired height. If -1, aspect ratio is preserved based on iWidth.
 * @param iTypeImage Reference to an integer that will receive the image type (e.g., IMAGE_BITMAP).
 * @param iIconNumber The index of the icon to extract if sFileImage is an EXE/DLL.
 * @param bUseGDIPlusIfAvailable If true, attempts to use GDI+ for loading modern image formats.
 * @return A handle to the loaded HBITMAP, or NULL on failure.
 */
static HBITMAP LoadPicture(const char* sFileImage, int iWidth, int iHeight, int& iTypeImage, int iIconNumber, bool bUseGDIPlusIfAvailable) {
    if (!sFileImage || !sFileImage[0]) return nullptr;

    HBITMAP hBitmap = nullptr;
    wchar_t wszPath[MAX_PATH];
    ToWideCharFunc(sFileImage, wszPath, MAX_PATH);

    std::string sFileLower = sFileImage;
    for (char& c : sFileLower) c = static_cast<char>(tolower(c));

    bool isIconFile = sFileLower.ends_with(".ico") || sFileLower.ends_with(".cur");
    bool isExeFile = sFileLower.ends_with(".exe") || sFileLower.ends_with(".dll");

    // 1. Icon Extraction from EXE/DLL
    if (iIconNumber > 0 || isExeFile) {
        HICON hIcon = (HICON)ExtractIcon(nullptr, wszPath, iIconNumber);
        if (hIcon && hIcon != (HICON)1) {
            hBitmap = IconToBitmap(hIcon, true);
            iTypeImage = IMAGE_ICON;
        }
    }

    // 2. Standard Image Loading (ICO, CUR, BMP)
    if (!hBitmap && (isIconFile || sFileLower.ends_with(".bmp"))) {
        int type = isIconFile ? IMAGE_ICON : IMAGE_BITMAP;
        hBitmap = (HBITMAP)LoadImageW(nullptr, wszPath, type, 0, 0, LR_LOADFROMFILE);
        if (hBitmap) {
            iTypeImage = type;
            if (type == IMAGE_ICON) {
                HBITMAP tempBitmap = IconToBitmap((HICON)hBitmap, true);
                hBitmap = tempBitmap; // hBitmap was an HICON, now it's a real HBITMAP
            }
        }
    }

    // 3. GDI+ Loading (JPG, GIF, PNG, etc.)
    if (!hBitmap && bUseGDIPlusIfAvailable) {
        Gdiplus::GdiplusStartupInput gdiplusStartupInput;
        ULONG_PTR gdiplusToken;
        if (Gdiplus::GdiplusStartup(&gdiplusToken, &gdiplusStartupInput, nullptr) == Gdiplus::Ok) {
            Gdiplus::Bitmap* image = new Gdiplus::Bitmap(wszPath);
            if (image && image->GetLastStatus() == Gdiplus::Ok) {
                image->GetHBITMAP(Gdiplus::Color(0, 0, 0, 0), &hBitmap);
                iTypeImage = IMAGE_BITMAP;
            }
            delete image;
            Gdiplus::GdiplusShutdown(gdiplusToken);
        }
    }

    // 4. OLE Automation Fallback
    if (!hBitmap) {
        HANDLE hFile = CreateFileA(sFileImage, GENERIC_READ, 0, nullptr, OPEN_EXISTING, 0, nullptr);
        if (hFile != INVALID_HANDLE_VALUE) {
            DWORD dwFileSize = GetFileSize(hFile, nullptr);
            if (dwFileSize != INVALID_FILE_SIZE) {
                HGLOBAL hGlobal = GlobalAlloc(GMEM_MOVEABLE, dwFileSize);
                if (hGlobal) {
                    void* pData = GlobalLock(hGlobal);
                    if (pData) {
                        DWORD dwBytesRead;
                        if (ReadFile(hFile, pData, dwFileSize, &dwBytesRead, nullptr) && dwBytesRead == dwFileSize) {
                            IStream* pStream = nullptr;
                            if (CreateStreamOnHGlobal(hGlobal, TRUE, &pStream) == S_OK) {
                                IPicture* pPicture = nullptr;
                                if (OleLoadPicture(pStream, 0, FALSE, IID_IPicture, (LPVOID*)&pPicture) == S_OK) {
                                    OLE_HANDLE ole_h;
                                    pPicture->get_Handle(&ole_h);
                                    // FIX: Use a LONG_PTR cast to avoid C4312 warning on x64 builds.
                                    hBitmap = (HBITMAP)CopyImage((HANDLE)(LONG_PTR)ole_h, IMAGE_BITMAP, 0, 0, LR_COPYRETURNORG);
                                    pPicture->Release();
                                    iTypeImage = IMAGE_BITMAP;
                                }
                                pStream->Release();
                            }
                        }
                        GlobalUnlock(hGlobal);
                    }
                    // Note: CreateStreamOnHGlobal takes ownership of hGlobal, so we don't free it if successful.
                }
            }
            CloseHandle(hFile);
        }
    }

    // Handle resizing
    if (hBitmap && (iWidth != 0 || iHeight != 0)) {
        BITMAP bm;
        GetObject(hBitmap, sizeof(bm), &bm);
        int currentW = bm.bmWidth;
        int currentH = bm.bmHeight;
        int newW = iWidth;
        int newH = iHeight;

        if (iWidth == -1 && iHeight > 0) { // Preserve aspect ratio based on height
            newH = iHeight;
            newW = static_cast<int>(round(currentW * (static_cast<float>(newH) / currentH)));
        }
        else if (iHeight == -1 && iWidth > 0) { // Preserve aspect ratio based on width
            newW = iWidth;
            newH = static_cast<int>(round(currentH * (static_cast<float>(newW) / currentW)));
        }

        if ((newW > 0 && newH > 0) && (newW != currentW || newH != currentH)) {
            HBITMAP hScaledBitmap = ScaleBitmap(hBitmap, newW, newH);
            if (hScaledBitmap) {
                DeleteObject(hBitmap);
                hBitmap = hScaledBitmap;
            }
        }
    }

    return hBitmap;
}

/**
 * @brief Extracts the pixel data from an HBITMAP into a vector of COLORREF values.
 * @param ahImage The handle to the source bitmap.
 * @param hdc A handle to a device context.
 * @param iWidth Reference to a LONG that will receive the bitmap's width.
 * @param iHeight Reference to a LONG that will receive the bitmap's height.
 * @param aIs16Bit Reference to a bool that is not used in this implementation but kept for signature compatibility.
 * @param aMinColorDepth Minimum color depth required (not used, always gets 32-bit).
 * @return A std::vector<COLORREF> containing the 32-bpp pixel data in top-down order. Returns an empty vector on failure.
 */
static std::vector<COLORREF> getbits(HBITMAP ahImage, HDC hdc, LONG& iWidth, LONG& iHeight, bool& aIs16Bit, int aMinColorDepth = 8) {
    BITMAP bm;
    if (!GetObject(ahImage, sizeof(BITMAP), &bm)) {
        return {};
    }

    iWidth = bm.bmWidth;
    iHeight = bm.bmHeight;
    aIs16Bit = false; // We always request 32-bit

    std::vector<COLORREF> pixels;
    pixels.resize(iWidth * iHeight);

    BITMAPINFO bmi = { 0 };
    bmi.bmiHeader.biSize = sizeof(BITMAPINFOHEADER);
    bmi.bmiHeader.biWidth = iWidth;
    bmi.bmiHeader.biHeight = -iHeight; // Request a top-down DIB
    bmi.bmiHeader.biPlanes = 1;
    bmi.bmiHeader.biBitCount = 32;
    bmi.bmiHeader.biCompression = BI_RGB;

    if (GetDIBits(hdc, ahImage, 0, iHeight, pixels.data(), &bmi, DIB_RGB_COLORS) == 0) {
        return {}; // Return empty vector on failure
    }

    return pixels;
}

/**
 * @brief Checks if a smaller image exists within a larger image at a specific location (exact match).
 * @param pScreenBits Pointer to the start of the larger image (screen) pixel data.
 * @param screenW Width of the screen image.
 * @param pSourceBits Pointer to the start of the smaller image (source) pixel data.
 * @param sourceW Width of the source image.
 * @param sourceH Height of the source image.
 * @param iX The X coordinate in the screen image to start the comparison.
 * @param iY The Y coordinate in the screen image to start the comparison.
 * @param iTransparentColor The COLORREF to treat as transparent (will match any pixel).
 * @return True if the source image is found at the given coordinates, false otherwise.
 */
static bool CheckExactMatch(const COLORREF* pScreenBits, int screenW, const COLORREF* pSourceBits, int sourceW, int sourceH, int iX, int iY, int iTransparentColor) {
    for (int y = 0; y < sourceH; ++y) {
        for (int x = 0; x < sourceW; ++x) {
            COLORREF sourcePixel = pSourceBits[y * sourceW + x];
            if (sourcePixel == static_cast<unsigned int>(iTransparentColor)) {
                continue; // Transparent pixel, skip check
            }
            COLORREF screenPixel = pScreenBits[(iY + y) * screenW + (iX + x)];
            if (sourcePixel != screenPixel) {
                return false;
            }
        }
    }
    return true;
}

/**
 * @brief Checks if a smaller image exists within a larger image at a specific location (approximate match).
 * @param pScreenBits Pointer to the start of the larger image (screen) pixel data.
 * @param screenW Width of the screen image.
 * @param pSourceBits Pointer to the start of the smaller image (source) pixel data.
 * @param sourceW Width of the source image.
 * @param sourceH Height of the source image.
 * @param iX The X coordinate in the screen image to start the comparison.
 * @param iY The Y coordinate in the screen image to start the comparison.
 * @param iTransparentColor The COLORREF to treat as transparent (will match any pixel).
 * @param iTolerance The allowed variance (0-255) for each color channel (R, G, B).
 * @return True if the source image is found at the given coordinates within the tolerance, false otherwise.
 */
static bool CheckApproxMatch(const COLORREF* pScreenBits, int screenW, const COLORREF* pSourceBits, int sourceW, int sourceH, int iX, int iY, int iTransparentColor, int iTolerance) {
    for (int y = 0; y < sourceH; ++y) {
        for (int x = 0; x < sourceW; ++x) {
            COLORREF sourcePixel = pSourceBits[y * sourceW + x];
            if (sourcePixel == static_cast<unsigned int>(iTransparentColor)) {
                continue; // Transparent pixel, skip check
            }
            COLORREF screenPixel = pScreenBits[(iY + y) * screenW + (iX + x)];

            int sourceR = GetRValue(sourcePixel);
            int sourceG = GetGValue(sourcePixel);
            int sourceB = GetBValue(sourcePixel);

            int screenR = GetRValue(screenPixel);
            int screenG = GetGValue(screenPixel);
            int screenB = GetBValue(screenPixel);

            if (abs(sourceR - screenR) > iTolerance ||
                abs(sourceG - screenG) > iTolerance ||
                abs(sourceB - screenB) > iTolerance) {
                return false;
            }
        }
    }
    return true;
}

/**
 * @brief The core search function. Captures a region of the screen and searches for a given bitmap within it.
 * @param hBitmapSource The HBITMAP of the image to search for.
 * @param iLeft The left coordinate of the search area on the screen.
 * @param iTop The top coordinate of the search area on the screen.
 * @param iRight The right coordinate of the search area on the screen.
 * @param iBottom The bottom coordinate of the search area on the screen.
 * @param iTolerance The color tolerance for an approximate match. If 0, an exact match is performed.
 * @param iTransparent The COLORREF to be treated as transparent.
 * @return A C-string containing "x|y|w|h" on success, an error code like "E<-3>" on failure, or an empty string if no match is found.
 */
static char* SearchImageWithBitmap(HBITMAP hBitmapSource, int iLeft, int iTop, int iRight, int iBottom, int iTolerance, int iTransparent) {
    static char szResult[64];
    strcpy_s(szResult, "");

    if (!hBitmapSource) return szResult;

    int iSearchWidth = iRight - iLeft;
    int iSearchHeight = iBottom - iTop;
    if (iSearchWidth <= 0 || iSearchHeight <= 0) {
        strcpy_s(szResult, "E<-9>");
        return szResult;
    }

    // 1. Get Screen DC and capture screen region
    HDC hdcScreen = GetDC(nullptr);
    if (!hdcScreen) { strcpy_s(szResult, "E<-3>"); return szResult; }

    HDC hdcMem = CreateCompatibleDC(hdcScreen);
    if (!hdcMem) { ReleaseDC(nullptr, hdcScreen); strcpy_s(szResult, "E<-4>"); return szResult; }

    HBITMAP hBitmapScreen = CreateCompatibleBitmap(hdcScreen, iSearchWidth, iSearchHeight);
    if (!hBitmapScreen) {
        DeleteDC(hdcMem);
        ReleaseDC(nullptr, hdcScreen);
        strcpy_s(szResult, "E<-5>");
        return szResult;
    }

    SelectObject(hdcMem, hBitmapScreen);
    if (!BitBlt(hdcMem, 0, 0, iSearchWidth, iSearchHeight, hdcScreen, iLeft, iTop, SRCCOPY)) {
        DeleteObject(hBitmapScreen);
        DeleteDC(hdcMem);
        ReleaseDC(nullptr, hdcScreen);
        strcpy_s(szResult, "E<-7>");
        return szResult;
    }

    // 2. Get pixel data for both screen capture and source image
    LONG screenW, screenH, sourceW, sourceH;
    bool is16bit_dummy;
    std::vector<COLORREF> screenBits = getbits(hBitmapScreen, hdcMem, screenW, screenH, is16bit_dummy);
    std::vector<COLORREF> sourceBits = getbits(hBitmapSource, hdcMem, sourceW, sourceH, is16bit_dummy);

    // Cleanup GDI objects as soon as they are not needed
    DeleteObject(hBitmapScreen);
    DeleteDC(hdcMem);
    ReleaseDC(nullptr, hdcScreen);

    if (screenBits.empty() || sourceBits.empty()) {
        strcpy_s(szResult, "E<-8>");
        return szResult;
    }

    if (sourceW > screenW || sourceH > screenH) {
        return szResult; // Source image is bigger than search area, no match possible
    }

    // 3. Perform the search
    int iMaxX = screenW - sourceW;
    int iMaxY = screenH - sourceH;

    for (int y = 0; y <= iMaxY; ++y) {
        for (int x = 0; x <= iMaxX; ++x) {
            bool found = false;
            if (iTolerance == 0) {
                found = CheckExactMatch(screenBits.data(), screenW, sourceBits.data(), sourceW, sourceH, x, y, iTransparent);
            }
            else {
                found = CheckApproxMatch(screenBits.data(), screenW, sourceBits.data(), sourceW, sourceH, x, y, iTransparent, iTolerance);
            }

            if (found) {
                sprintf_s(szResult, sizeof(szResult), "%d|%d|%ld|%ld", iLeft + x, iTop + y, sourceW, sourceH);
                return szResult;
            }
        }
    }

    return szResult; // Return empty string for "no match"
}


// =================================================================================================
// EXPORTED FUNCTION
// =================================================================================================

/**
 * @brief Searches for one or more images on the screen within a specified region.
 *
 * @param sImageFile A pipe-separated string of image file paths.
 * @param iLeft Left coordinate of the search rectangle. Defaults to 0.
 * @param iTop Top coordinate of the search rectangle. Defaults to 0.
 * @param iRight Right coordinate of the search rectangle. If 0, screen width is used.
 * @param iBottom Bottom coordinate of the search rectangle. If 0, screen height is used.
 * @param iTolerance Color tolerance (0-255). 0 means exact match.
 * @param iTransparent A COLORREF value to treat as transparent.
 * @param iMultiResults The maximum number of results to find. If 0, finds all.
 * @param iCenterPOS If 1, returns the center coordinates of the found image. Otherwise, returns top-left.
 * @param iReturnDebug If 1, appends a debug string with parameter info to the result.
 * @param fMinScale The minimum scaling factor to test (e.g., 0.8 for 80%).
 * @param fMaxScale The maximum scaling factor to test (e.g., 1.2 for 120%).
 * @param fScaleStep The step to increment scale from min to max (e.g., 0.1).
 *
 * @return A formatted string.
 * - Success: "{match_count}[x|y|w|h,x2|y2|w2|h2,...]"
 * - No Match: "{0}[No Match Found]"
 * - Error: "{error_code}[error_message]"
 */

extern "C" __declspec(dllexport) char* WINAPI ImageSearch(
    char* sImageFile,
    int iLeft = 0, int iTop = 0, int iRight = 0, int iBottom = 0,
    int iTolerance = 10,
    int iTransparent = CLR_NONE,
    int iMultiResults = 0,
    int iCenterPOS = 1,
    int iReturnDebug = 0,
    float fMinScale = 1.0f, float fMaxScale = 1.0f, float fScaleStep = 0.1f
) {
    // Convert user-provided RGB transparent color to BGR for GDI comparison.
    iTransparent = rgb_to_bgr(iTransparent);

    // Static buffers for results. Note: This makes the function not thread-safe.
    static char szAnswer[2048];
    static char szDebug[1024];

    // --- 1. Parameter Validation and Initialization ---
    int screenWidth = GetSystemMetrics(SM_CXSCREEN);
    int screenHeight = GetSystemMetrics(SM_CYSCREEN);

    iLeft = max(0, iLeft);
    iTop = max(0, iTop);
    iRight = (iRight <= 0 || iRight > screenWidth) ? screenWidth : iRight;
    iBottom = (iBottom <= 0 || iBottom > screenHeight) ? screenHeight : iBottom;
    if (iLeft >= iRight || iTop >= iBottom) {
        sprintf_s(szAnswer, sizeof(szAnswer), "{%d}[%s]", -9, GetErrorMessage(-9));
        return szAnswer;
    }

    iTolerance = max(0, min(255, iTolerance));
    if (fMinScale <= 0) fMinScale = 0.1f;
    if (fMaxScale < fMinScale) fMaxScale = fMinScale;
    if (fScaleStep <= 0) fScaleStep = 0.1f;

    std::string results_aggregator;
    int match_count = 0;

    // --- 2. Process Multiple Image Files ---
    std::string files(sImageFile);
    std::string delimiter = "|";
    size_t pos = 0;
    std::string token;
    while ((pos = files.find(delimiter)) != std::string::npos || !files.empty()) {
        if (pos != std::string::npos) {
            token = files.substr(0, pos);
            files.erase(0, pos + delimiter.length());
        }
        else {
            token = files;
            files.clear();
        }

        if (token.empty()) continue;

        // --- 3. Load Original Image ---
        int imageType = 0;
        HBITMAP hBitmapOrig = LoadPicture(token.c_str(), 0, 0, imageType, 0, true);
        if (!hBitmapOrig) {
            sprintf_s(szAnswer, sizeof(szAnswer), "{%d}[%s]", -2, GetErrorMessage(-2));
            return szAnswer;
        }

        // --- 4. Scaling Loop ---
        bool foundOnAnyScale = false;
        for (float scale = fMinScale; scale <= fMaxScale; scale += fScaleStep) {
            HBITMAP hBitmapToSearch = nullptr;
            bool deleteThisBitmap = false;

            if (scale == 1.0f) {
                hBitmapToSearch = hBitmapOrig;
            }
            else {
                BITMAP bm;
                GetObject(hBitmapOrig, sizeof(bm), &bm);
                int newW = static_cast<int>(round(bm.bmWidth * scale));
                int newH = static_cast<int>(round(bm.bmHeight * scale));

                if (newW < 1 || newH < 1) {
                    // Skip scales that result in a 0 or 1 pixel image
                    continue;
                }

                hBitmapToSearch = ScaleBitmap(hBitmapOrig, newW, newH);
                deleteThisBitmap = true; // We created this scaled bitmap, so we must delete it
            }

            if (!hBitmapToSearch) {
                // If scaling failed, just continue to the next scale factor
                continue;
            }

            // --- 5. Search with the (potentially scaled) bitmap ---
            char* pResult = SearchImageWithBitmap(hBitmapToSearch, iLeft, iTop, iRight, iBottom, iTolerance, iTransparent);

            if (pResult && pResult[0] == 'E') { // An error occurred
                int errCode = atoi(pResult + 2);
                sprintf_s(szAnswer, sizeof(szAnswer), "{%d}[%s]", errCode, GetErrorMessage(errCode));
                if (deleteThisBitmap) DeleteObject(hBitmapToSearch);
                DeleteObject(hBitmapOrig);
                return szAnswer;
            }

            if (pResult && pResult[0] != '\0') { // A match was found
                int x, y, w, h;
                sscanf_s(pResult, "%d|%d|%d|%d", &x, &y, &w, &h);

                if (iCenterPOS == 1) {
                    x += w / 2;
                    y += h / 2;
                }

                char single_result[128];
                sprintf_s(single_result, sizeof(single_result), "%d|%d|%d|%d", x, y, w, h);

                if (!results_aggregator.empty()) {
                    results_aggregator += ",";
                }
                results_aggregator += single_result;
                match_count++;
                foundOnAnyScale = true;
            }

            if (deleteThisBitmap) {
                DeleteObject(hBitmapToSearch);
            }

            // If we found a match for this image file, we can stop trying other scales for it.
            if (foundOnAnyScale) {
                break;
            }
        }

        DeleteObject(hBitmapOrig);

        // Check if we have found enough results overall
        if (iMultiResults > 0 && match_count >= iMultiResults) {
            break;
        }
    }

    // --- 6. Format Final Output ---
    if (match_count > 0) {
        sprintf_s(szAnswer, sizeof(szAnswer), "{%d}[%s]", match_count, results_aggregator.c_str());
    }
    else {
        sprintf_s(szAnswer, sizeof(szAnswer), "{0}[No Match Found]");
    }

    if (iReturnDebug == 1) {
        sprintf_s(szDebug, sizeof(szDebug),
            " | DEBUG: File=%s, Rect=(%d,%d,%d,%d), Tol=%d, Trans=0x%X, Multi=%d, Center=%d, Scale=(%.2f,%.2f,%.2f)",
            sImageFile, iLeft, iTop, iRight, iBottom, iTolerance, iTransparent, iMultiResults, iCenterPOS, fMinScale, fMaxScale, fScaleStep);
        strcat_s(szAnswer, sizeof(szAnswer), szDebug);
    }

    return szAnswer;
}

#pragma managed(pop)


// =================================================================================================
// DEBUG TEST CASE
// =================================================================================================
#ifdef _DEBUG

#include <iostream>

// This _tmain function serves as a test harness for the DLL functionality when built in Debug mode.
// It will not be included in the Release build of the DLL.
int _tmain(int argc, _TCHAR* argv[]) {
    _tprintf(_T("--- ImageSearchDLL Debug Test ---\n"));

    // IMPORTANT: For this test to work, you must create a file named "C:\\test_image.png"
    // or change the path below to an image file that exists on your system.
    // Also, open that image on your screen so the search can find it.
    char test_image_path[] = "C:\\test_image.png";

    _tprintf(_T("Searching for image: %s\n"), test_image_path);
    _tprintf(_T("Please ensure the image is visible on screen for the test to succeed.\n"));

    // Test Case 1: Simple search for a visible image
    char* result1 = ImageSearch(test_image_path, 0, 0, 0, 0, 10, CLR_NONE, 1, 1, 1);
    _tprintf(_T("Test 1 (Simple Search): %s\n\n"), result1);

    // Test Case 2: Search for a non-existent file (should return error)
    char non_existent_file[] = "C:\\path\\to\\non_existent_image.bmp";
    char* result2 = ImageSearch(non_existent_file);
    _tprintf(_T("Test 2 (Non-existent file): %s\n\n"), result2);

    // Test Case 3: Search for an image that is not on screen (should return no match)
    // For this, use a valid image path but make sure the image is NOT visible.
    char* result3 = ImageSearch(test_image_path, 0, 0, 100, 100); // Search in a small top-left area
    _tprintf(_T("Test 3 (No Match Expected): %s\n\n"), result3);

    // Test Case 4: Search with scaling
    _tprintf(_T("Searching for image with scaling (0.8x to 1.2x)...\n"));
    char* result4 = ImageSearch(test_image_path, 0, 0, 0, 0, 10, CLR_NONE, 1, 1, 0, 0.8f, 1.2f, 0.1f);
    _tprintf(_T("Test 4 (Scaling Search): %s\n\n"), result4);

    system("pause");
    return 0;
}

#endif // _DEBUG
