// =================================================================================================
//
// Name ............: ImageSearchDLL.cpp
// Description .....: A highly optimized, stable, and thread-safe DLL for finding images.
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
// KEY FEATURES & OPTIMIZATIONS:
//
//  - Thread Pool for Concurrency: Uses a fixed-size thread pool (based on the number of CPU cores)
//    to process multi-image searches. This prevents thread exhaustion and ensures stable
//    performance even with a large number of images.
//
//  - Fully Thread-Safe: The exported ImageSearch function is now fully thread-safe. Multiple
//    threads can call it concurrently without data corruption, thanks to thread-local storage
//    for result buffers.
//
//  - Runtime CPU Dispatching: Automatically detects if the host CPU supports AVX2. If it does,
//    it uses a highly optimized SIMD code path. If not, it falls back to a safe, standard
//    code path to prevent crashes on older CPUs.
//
//  - Single Screen Capture: For multi-image searches, the screen is captured only ONCE.
//
//  - SIMD Acceleration (AVX2): Pixel comparison logic is accelerated using AVX2 intrinsics.
//
// =================================================================================================

#pragma managed(push, off)

// Define NOMINMAX to prevent windows.h from defining min() and max() macros,
// which conflict with the C++ standard library's std::min and std::max.
#define NOMINMAX

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

// C++ Standard Library Headers for threading and modern C++
#include <string>
#include <vector>
#include <cstring>
#include <cstdint>
#include <memory>
#include <algorithm>
#include <thread>
#include <future>
#include <mutex>
#include <stdexcept>
#include <queue>
#include <functional>
#include <condition_variable>

// Intrinsics Header for CPUID and SIMD
#include <intrin.h>

// Link GDI+ library
#pragma comment(lib, "gdiplus.lib")

// =================================================================================================
// THREAD POOL IMPLEMENTATION
// =================================================================================================

/**
 * @class ThreadPool
 * @brief A simple, fixed-size thread pool for executing tasks concurrently.
 * This class creates a number of worker threads and allows submitting tasks
 * which will be executed by the available threads.
 */
class ThreadPool {
public:
    /**
     * @brief Constructs a ThreadPool.
     * @param threads The number of worker threads to create. Defaults to the number of hardware threads.
     */
    ThreadPool(size_t threads = std::thread::hardware_concurrency()) : stop(false) {
        for (size_t i = 0; i < threads; ++i)
            workers.emplace_back([this] {
            for (;;) {
                std::function<void()> task;
                {
                    std::unique_lock<std::mutex> lock(this->queue_mutex);
                    this->condition.wait(lock, [this] { return this->stop || !this->tasks.empty(); });
                    if (this->stop && this->tasks.empty())
                        return;
                    task = std::move(this->tasks.front());
                    this->tasks.pop();
                }
                task();
            }
                });
    }

    /**
     * @brief Enqueues a new task to be executed by the thread pool.
     * @tparam F The type of the function to execute.
     * @tparam Args The types of the arguments to the function.
     * @param f The function to execute.
     * @param args The arguments to pass to the function.
     * @return A std::future representing the result of the task.
     */
    template<class F, class... Args>
    auto enqueue(F&& f, Args&&... args)
        -> std::future<typename std::invoke_result<F, Args...>::type>
    {
        using return_type = typename std::invoke_result<F, Args...>::type;

        auto task = std::make_shared<std::packaged_task<return_type()>>(
            std::bind(std::forward<F>(f), std::forward<Args>(args)...)
        );

        std::future<return_type> res = task->get_future();
        {
            std::unique_lock<std::mutex> lock(queue_mutex);
            if (stop)
                throw std::runtime_error("enqueue on stopped ThreadPool");
            tasks.emplace([task]() { (*task)(); });
        }
        condition.notify_one();
        return res;
    }

    /**
     * @brief Destroys the ThreadPool, waiting for all tasks to complete.
     */
    ~ThreadPool() {
        {
            std::unique_lock<std::mutex> lock(queue_mutex);
            stop = true;
        }
        condition.notify_all();
        for (std::thread& worker : workers)
            worker.join();
    }

private:
    std::vector<std::thread> workers;
    std::queue<std::function<void()>> tasks;
    std::mutex queue_mutex;
    std::condition_variable condition;
    bool stop;
};


// =================================================================================================
// DATA STRUCTURES & CPU DETECTION
// =================================================================================================

struct ScreenCapture {
    std::vector<COLORREF> pixels;
    LONG width = 0;
    LONG height = 0;
    int error_code = 0;
};

struct ImageToSearch {
    std::vector<COLORREF> pixels;
    LONG width = 0;
    LONG height = 0;
};

bool check_avx2_support() {
    int cpuInfo[4];
    __cpuidex(cpuInfo, 7, 0);
    return (cpuInfo[1] & (1 << 5)) != 0;
}

static bool g_is_avx2_supported = false;
static std::once_flag g_cpu_check_flag;

void initialize_cpu_features() {
    g_is_avx2_supported = check_avx2_support();
}

// =================================================================================================
// MACROS AND HELPER FUNCTIONS
// =================================================================================================

#define CLR_DEFAULT 0x808080
#define CLR_NONE    0xFFFFFFFF

inline COLORREF rgb_to_bgr(DWORD aRGB) {
    return ((aRGB & 0xFF0000) >> 16) | (aRGB & 0x00FF00) | ((aRGB & 0x0000FF) << 16);
}

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

// Forward declarations
static HBITMAP IconToBitmap(HICON ahIcon, bool aDestroyIcon);
static HBITMAP ScaleBitmap(HBITMAP hBitmap, int newW, int newH);
static std::vector<COLORREF> getbits(HBITMAP ahImage, HDC hdc, LONG& iWidth, LONG& iHeight);

static HBITMAP LoadPicture(const char* sFileImage, int iWidth, int iHeight, int& iTypeImage, int iIconNumber) {
    if (!sFileImage || !sFileImage[0]) return nullptr;
    HBITMAP hBitmap = nullptr;
    wchar_t wszPath[MAX_PATH] = { 0 };
    MultiByteToWideChar(CP_ACP, 0, sFileImage, -1, wszPath, MAX_PATH);
    std::string sFileLower = sFileImage;
    for (char& c : sFileLower) c = static_cast<char>(tolower(c));
    bool isIconFile = sFileLower.length() > 4 && sFileLower.substr(sFileLower.length() - 4) == ".ico";
    bool isCurFile = sFileLower.length() > 4 && sFileLower.substr(sFileLower.length() - 4) == ".cur";
    bool isExeFile = sFileLower.length() > 4 && sFileLower.substr(sFileLower.length() - 4) == ".exe";
    bool isDllFile = sFileLower.length() > 4 && sFileLower.substr(sFileLower.length() - 4) == ".dll";
    bool isBmpFile = sFileLower.length() > 4 && sFileLower.substr(sFileLower.length() - 4) == ".bmp";
    if (iIconNumber > 0 || isExeFile || isDllFile) {
        HICON hIcon = (HICON)ExtractIconW(nullptr, wszPath, iIconNumber);
        if (hIcon && hIcon != (HICON)1) { hBitmap = IconToBitmap(hIcon, true); iTypeImage = IMAGE_ICON; }
    }
    if (!hBitmap && (isIconFile || isCurFile || isBmpFile)) {
        int type = (isIconFile || isCurFile) ? IMAGE_ICON : IMAGE_BITMAP;
        hBitmap = (HBITMAP)LoadImageW(nullptr, wszPath, type, 0, 0, LR_LOADFROMFILE);
        if (hBitmap) { iTypeImage = type; if (type == IMAGE_ICON) { HBITMAP tempBitmap = IconToBitmap((HICON)hBitmap, true); hBitmap = tempBitmap; } }
    }
    if (!hBitmap) {
        Gdiplus::GdiplusStartupInput gdiplusStartupInput; ULONG_PTR gdiplusToken;
        if (Gdiplus::GdiplusStartup(&gdiplusToken, &gdiplusStartupInput, nullptr) == Gdiplus::Ok) {
            Gdiplus::Bitmap* image = new Gdiplus::Bitmap(wszPath);
            if (image && image->GetLastStatus() == Gdiplus::Ok) { image->GetHBITMAP(Gdiplus::Color(0, 0, 0, 0), &hBitmap); iTypeImage = IMAGE_BITMAP; }
            delete image; Gdiplus::GdiplusShutdown(gdiplusToken);
        }
    }
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
                                    OLE_HANDLE ole_h; pPicture->get_Handle(&ole_h);
                                    hBitmap = (HBITMAP)CopyImage((HANDLE)(LONG_PTR)ole_h, IMAGE_BITMAP, 0, 0, LR_COPYRETURNORG);
                                    pPicture->Release(); iTypeImage = IMAGE_BITMAP;
                                } pStream->Release();
                            }
                        } GlobalUnlock(hGlobal);
                    }
                }
            } CloseHandle(hFile);
        }
    }
    if (hBitmap && (iWidth != 0 || iHeight != 0)) {
        BITMAP bm; GetObject(hBitmap, sizeof(bm), &bm); int currentW = bm.bmWidth; int currentH = bm.bmHeight;
        int newW = iWidth; int newH = iHeight;
        if (iWidth == -1 && iHeight > 0) { newW = static_cast<int>(round(currentW * (static_cast<float>(iHeight) / currentH))); }
        else if (iHeight == -1 && iWidth > 0) { newH = static_cast<int>(round(currentH * (static_cast<float>(iWidth) / currentW))); }
        if ((newW > 0 && newH > 0) && (newW != currentW || newH != currentH)) {
            HBITMAP hScaledBitmap = ScaleBitmap(hBitmap, newW, newH);
            if (hScaledBitmap) { DeleteObject(hBitmap); hBitmap = hScaledBitmap; }
        }
    } return hBitmap;
}
static HBITMAP IconToBitmap(HICON ahIcon, bool aDestroyIcon) {
    if (!ahIcon) return nullptr; ICONINFO iconInfo = { 0 };
    if (!GetIconInfo(ahIcon, &iconInfo)) { if (aDestroyIcon) DestroyIcon(ahIcon); return nullptr; }
    HDC hdc = GetDC(nullptr); if (!hdc) { DeleteObject(iconInfo.hbmColor); DeleteObject(iconInfo.hbmMask); if (aDestroyIcon) DestroyIcon(ahIcon); return nullptr; }
    BITMAP bm = { 0 }; GetObject(iconInfo.hbmColor, sizeof(BITMAP), &bm); int width = bm.bmWidth; int height = bm.bmHeight;
    BITMAPINFO bmi = { 0 }; bmi.bmiHeader.biSize = sizeof(BITMAPINFOHEADER); bmi.bmiHeader.biWidth = width; bmi.bmiHeader.biHeight = -height;
    bmi.bmiHeader.biPlanes = 1; bmi.bmiHeader.biBitCount = 32; bmi.bmiHeader.biCompression = BI_RGB; void* pBits;
    HBITMAP hBitmap = CreateDIBSection(hdc, &bmi, DIB_RGB_COLORS, &pBits, nullptr, 0);
    if (hBitmap) {
        HDC hMemDC = CreateCompatibleDC(hdc); if (hMemDC) {
            HBITMAP hOldBitmap = (HBITMAP)SelectObject(hMemDC, hBitmap); RECT rc = { 0, 0, width, height };
            HBRUSH hBrush = CreateSolidBrush(CLR_DEFAULT); FillRect(hMemDC, &rc, hBrush); DeleteObject(hBrush);
            DrawIconEx(hMemDC, 0, 0, ahIcon, width, height, 0, nullptr, DI_NORMAL);
            SelectObject(hMemDC, hOldBitmap); DeleteDC(hMemDC);
        }
    } ReleaseDC(nullptr, hdc); DeleteObject(iconInfo.hbmColor); DeleteObject(iconInfo.hbmMask); if (aDestroyIcon) DestroyIcon(ahIcon); return hBitmap;
}
static HBITMAP ScaleBitmap(HBITMAP hBitmap, int newW, int newH) {
    if (!hBitmap || newW <= 0 || newH <= 0) return nullptr; HDC hdcScreen = GetDC(nullptr); if (!hdcScreen) return nullptr;
    HDC hdcSrc = CreateCompatibleDC(hdcScreen); if (!hdcSrc) { ReleaseDC(nullptr, hdcScreen); return nullptr; }
    HBITMAP hOldSrc = (HBITMAP)SelectObject(hdcSrc, hBitmap); BITMAP bm; GetObject(hBitmap, sizeof(bm), &bm);
    HDC hdcDest = CreateCompatibleDC(hdcScreen); if (!hdcDest) { SelectObject(hdcSrc, hOldSrc); DeleteDC(hdcSrc); ReleaseDC(nullptr, hdcScreen); return nullptr; }
    HBITMAP hBitmapDest = CreateCompatibleBitmap(hdcScreen, newW, newH);
    if (!hBitmapDest) { DeleteDC(hdcDest); SelectObject(hdcSrc, hOldSrc); DeleteDC(hdcSrc); ReleaseDC(nullptr, hdcScreen); return nullptr; }
    HBITMAP hOldDest = (HBITMAP)SelectObject(hdcDest, hBitmapDest); SetStretchBltMode(hdcDest, HALFTONE);
    StretchBlt(hdcDest, 0, 0, newW, newH, hdcSrc, 0, 0, bm.bmWidth, bm.bmHeight, SRCCOPY);
    SelectObject(hdcSrc, hOldSrc); SelectObject(hdcDest, hOldDest); DeleteDC(hdcSrc); DeleteDC(hdcDest); ReleaseDC(nullptr, hdcScreen); return hBitmapDest;
}
static std::vector<COLORREF> getbits(HBITMAP ahImage, HDC hdc, LONG& iWidth, LONG& iHeight) {
    BITMAP bm; if (!GetObject(ahImage, sizeof(BITMAP), &bm)) return {};
    iWidth = bm.bmWidth; iHeight = bm.bmHeight; std::vector<COLORREF> pixels(iWidth * iHeight);
    BITMAPINFO bmi = { 0 }; bmi.bmiHeader.biSize = sizeof(BITMAPINFOHEADER); bmi.bmiHeader.biWidth = iWidth; bmi.bmiHeader.biHeight = -iHeight;
    bmi.bmiHeader.biPlanes = 1; bmi.bmiHeader.biBitCount = 32; bmi.bmiHeader.biCompression = BI_RGB;
    if (GetDIBits(hdc, ahImage, 0, iHeight, pixels.data(), &bmi, DIB_RGB_COLORS) == 0) return {};
    return pixels;
}
static ScreenCapture CaptureScreenRegion(int iLeft, int iTop, int iRight, int iBottom) {
    ScreenCapture capture; int iSearchWidth = iRight - iLeft; int iSearchHeight = iBottom - iTop;
    if (iSearchWidth <= 0 || iSearchHeight <= 0) { capture.error_code = -9; return capture; }
    HDC hdcScreen = GetDC(nullptr); if (!hdcScreen) { capture.error_code = -3; return capture; }
    HDC hdcMem = CreateCompatibleDC(hdcScreen); if (!hdcMem) { ReleaseDC(nullptr, hdcScreen); capture.error_code = -4; return capture; }
    HBITMAP hBitmapScreen = CreateCompatibleBitmap(hdcScreen, iSearchWidth, iSearchHeight);
    if (!hBitmapScreen) { DeleteDC(hdcMem); ReleaseDC(nullptr, hdcScreen); capture.error_code = -5; return capture; }
    SelectObject(hdcMem, hBitmapScreen);
    if (!BitBlt(hdcMem, 0, 0, iSearchWidth, iSearchHeight, hdcScreen, iLeft, iTop, SRCCOPY)) {
        DeleteObject(hBitmapScreen); DeleteDC(hdcMem); ReleaseDC(nullptr, hdcScreen); capture.error_code = -7; return capture;
    }
    capture.pixels = getbits(hBitmapScreen, hdcMem, capture.width, capture.height);
    if (capture.pixels.empty()) { capture.error_code = -8; }
    DeleteObject(hBitmapScreen); DeleteDC(hdcMem); ReleaseDC(nullptr, hdcScreen);
    return capture;
}

// =================================================================================================
// PIXEL COMPARISON FUNCTIONS (SCALAR AND SIMD)
// =================================================================================================

static bool CheckExactMatch(const COLORREF* pScreenBits, int screenW, const COLORREF* pSourceBits, int sourceW, int sourceH, int iX, int iY, int iTransparentColor) {
    for (int y = 0; y < sourceH; ++y) {
        const COLORREF* source_row = pSourceBits + y * sourceW;
        const COLORREF* screen_row = pScreenBits + (iY + y) * screenW + iX;
        for (int x = 0; x < sourceW; ++x) {
            if (source_row[x] != static_cast<unsigned int>(iTransparentColor)) {
                if (source_row[x] != screen_row[x]) return false;
            }
        }
    } return true;
}

static bool CheckApproxMatch_Scalar(const COLORREF* pScreenBits, int screenW, const COLORREF* pSourceBits, int sourceW, int sourceH, int iX, int iY, int iTransparentColor, int iTolerance) {
    for (int y = 0; y < sourceH; ++y) {
        const COLORREF* source_row_ptr = pSourceBits + y * sourceW;
        const COLORREF* screen_row_ptr = pScreenBits + (iY + y) * screenW + iX;
        for (int x = 0; x < sourceW; ++x) {
            COLORREF sourcePixel = source_row_ptr[x];
            if (sourcePixel == static_cast<unsigned int>(iTransparentColor)) continue;
            COLORREF screenPixel = screen_row_ptr[x];
            if (abs((int)GetRValue(sourcePixel) - (int)GetRValue(screenPixel)) > iTolerance ||
                abs((int)GetGValue(sourcePixel) - (int)GetGValue(screenPixel)) > iTolerance ||
                abs((int)GetBValue(sourcePixel) - (int)GetBValue(screenPixel)) > iTolerance) {
                return false;
            }
        }
    } return true;
}

static bool CheckApproxMatch_AVX2(const COLORREF* pScreenBits, int screenW, const COLORREF* pSourceBits, int sourceW, int sourceH, int iX, int iY, int iTransparentColor, int iTolerance) {
    const __m256i v_tolerance = _mm256_set1_epi8(static_cast<char>(iTolerance));
    const __m256i v_trans_color = _mm256_set1_epi32(iTransparentColor);
    for (int y = 0; y < sourceH; ++y) {
        const COLORREF* source_row_ptr = pSourceBits + y * sourceW;
        const COLORREF* screen_row_ptr = pScreenBits + (iY + y) * screenW + iX;
        int x = 0;
        for (; x + 7 < sourceW; x += 8) {
            __m256i v_source = _mm256_loadu_si256((__m256i const*)(source_row_ptr + x));
            __m256i v_trans_mask = _mm256_cmpeq_epi32(v_source, v_trans_color);
            if (_mm256_testc_si256(v_trans_mask, _mm256_set1_epi32(-1))) continue;
            __m256i v_screen = _mm256_loadu_si256((__m256i const*)(screen_row_ptr + x));
            __m256i v_source_no_alpha = _mm256_and_si256(v_source, _mm256_set1_epi32(0x00FFFFFF));
            __m256i v_screen_no_alpha = _mm256_and_si256(v_screen, _mm256_set1_epi32(0x00FFFFFF));
            __m256i v_abs_diff = _mm256_sad_epu8(v_source_no_alpha, v_screen_no_alpha);
            __m256i v_diff_check = _mm256_subs_epu8(v_tolerance, v_abs_diff);
            __m256i v_mismatch = _mm256_cmpeq_epi8(v_diff_check, _mm256_setzero_si256());
            __m256i v_final_mask = _mm256_andnot_si256(v_trans_mask, v_mismatch);
            if (!_mm256_testz_si256(v_final_mask, v_final_mask)) return false;
        }
        for (; x < sourceW; ++x) {
            if (source_row_ptr[x] == static_cast<unsigned int>(iTransparentColor)) continue;
            if (abs((int)GetRValue(source_row_ptr[x]) - (int)GetRValue(screen_row_ptr[x])) > iTolerance ||
                abs((int)GetGValue(source_row_ptr[x]) - (int)GetGValue(screen_row_ptr[x])) > iTolerance ||
                abs((int)GetBValue(source_row_ptr[x]) - (int)GetBValue(screen_row_ptr[x])) > iTolerance) {
                return false;
            }
        }
    } return true;
}

// =================================================================================================
// CORE SEARCH LOGIC
// =================================================================================================

static std::vector<std::string> SearchForBitmapInCapture(
    const ScreenCapture& screen_capture, const ImageToSearch& image_to_search,
    int iLeft, int iTop, int iTolerance, int iTransparent, int iFindAllOccurrences)
{
    std::vector<std::string> found_matches;
    if (image_to_search.width > screen_capture.width || image_to_search.height > screen_capture.height) return found_matches;
    const int sourceW = image_to_search.width; const int sourceH = image_to_search.height;
    const int screenW = screen_capture.width; const int iMaxX = screen_capture.width - sourceW;
    const int iMaxY = screen_capture.height - sourceH;
    for (int y = 0; y <= iMaxY; ++y) {
        for (int x = 0; x <= iMaxX; ++x) {
            bool found = false;
            if (iTolerance == 0) {
                found = CheckExactMatch(screen_capture.pixels.data(), screenW, image_to_search.pixels.data(), sourceW, sourceH, x, y, iTransparent);
            }
            else {
                if (g_is_avx2_supported) {
                    found = CheckApproxMatch_AVX2(screen_capture.pixels.data(), screenW, image_to_search.pixels.data(), sourceW, sourceH, x, y, iTransparent, iTolerance);
                }
                else {
                    found = CheckApproxMatch_Scalar(screen_capture.pixels.data(), screenW, image_to_search.pixels.data(), sourceW, sourceH, x, y, iTransparent, iTolerance);
                }
            }
            if (found) {
                char single_match[64];
                sprintf_s(single_match, sizeof(single_match), "%d|%d|%d|%d", iLeft + x, iTop + y, sourceW, sourceH);
                found_matches.push_back(single_match);
                if (iFindAllOccurrences == 0) return found_matches;
            }
        }
    } return found_matches;
}

// =================================================================================================
// EXPORTED FUNCTION
// =================================================================================================

extern "C" __declspec(dllexport) char* WINAPI ImageSearch(
    char* sImageFile,
    int iLeft = 0, int iTop = 0, int iRight = 0, int iBottom = 0,
    int iTolerance = 10,
    int iTransparent = CLR_NONE,
    int iMultiResults = 0,
    int iCenterPOS = 1,
    int iReturnDebug = 0,
    float fMinScale = 1.0f, float fMaxScale = 1.0f, float fScaleStep = 0.1f,
    int iFindAllOccurrences = 0
) {
    std::call_once(g_cpu_check_flag, initialize_cpu_features);

    if (iTransparent != (int)CLR_NONE) {
        iTransparent = rgb_to_bgr(iTransparent);
    }

    // Use thread_local for static buffers to ensure thread-safety.
    thread_local char szAnswer[16384];
    thread_local char szDebug[1024];
    szAnswer[0] = '\0';
    szDebug[0] = '\0';

    int screenWidth = GetSystemMetrics(SM_CXSCREEN);
    int screenHeight = GetSystemMetrics(SM_CYSCREEN);
    iLeft = std::max(0, iLeft);
    iTop = std::max(0, iTop);
    iRight = (iRight <= 0 || iRight > screenWidth) ? screenWidth : iRight;
    iBottom = (iBottom <= 0 || iBottom > screenHeight) ? screenHeight : iBottom;
    if (iLeft >= iRight || iTop >= iBottom) {
        sprintf_s(szAnswer, sizeof(szAnswer), "{%d}[%s]", -9, GetErrorMessage(-9));
        return szAnswer;
    }
    iTolerance = std::max(0, std::min(255, iTolerance));
    if (fMinScale <= 0) fMinScale = 0.1f;
    if (fMaxScale < fMinScale) fMaxScale = fMinScale;
    if (fScaleStep <= 0) fScaleStep = 0.1f;

    ScreenCapture screen_capture = CaptureScreenRegion(iLeft, iTop, iRight, iBottom);
    if (screen_capture.error_code != 0) {
        sprintf_s(szAnswer, sizeof(szAnswer), "{%d}[%s]", screen_capture.error_code, GetErrorMessage(screen_capture.error_code));
        return szAnswer;
    }

    ThreadPool pool(std::thread::hardware_concurrency());
    std::vector<std::future<std::vector<std::string>>> futures;
    std::vector<char> file_buffer(sImageFile, sImageFile + strlen(sImageFile) + 1);
    char* next_token = nullptr;
    char* current_file = strtok_s(file_buffer.data(), "|", &next_token);
    while (current_file != nullptr) {
        if (strlen(current_file) > 0) {
            std::string file_path = current_file;
            futures.push_back(pool.enqueue([=] {
                int imageType = 0;
                // FIX: Pass 5 arguments to LoadPicture
                HBITMAP hBitmapOrig = LoadPicture(file_path.c_str(), 0, 0, imageType, 0);
                if (!hBitmapOrig) return std::vector<std::string>{};
                std::vector<std::string> thread_results;
                for (float scale = fMinScale; scale <= fMaxScale; scale += fScaleStep) {
                    HBITMAP hBitmapToSearch = nullptr;
                    bool deleteThisBitmap = false;
                    if (scale == 1.0f) {
                        hBitmapToSearch = hBitmapOrig;
                    }
                    else {
                        BITMAP bm; GetObject(hBitmapOrig, sizeof(bm), &bm);
                        int newW = static_cast<int>(round(bm.bmWidth * scale));
                        int newH = static_cast<int>(round(bm.bmHeight * scale));
                        if (newW < 1 || newH < 1) continue;
                        hBitmapToSearch = ScaleBitmap(hBitmapOrig, newW, newH);
                        deleteThisBitmap = true;
                    }
                    if (hBitmapToSearch) {
                        ImageToSearch image_to_search;
                        HDC hdcMem = CreateCompatibleDC(nullptr);
                        image_to_search.pixels = getbits(hBitmapToSearch, hdcMem, image_to_search.width, image_to_search.height);
                        DeleteDC(hdcMem);
                        if (!image_to_search.pixels.empty()) {
                            thread_results = SearchForBitmapInCapture(screen_capture, image_to_search, iLeft, iTop, iTolerance, iTransparent, iFindAllOccurrences);
                        }
                        if (deleteThisBitmap) DeleteObject(hBitmapToSearch);
                    }
                    if (!thread_results.empty()) break;
                }
                if (hBitmapOrig) { DeleteObject(hBitmapOrig); }
                return thread_results;
                }));
        }
        current_file = strtok_s(nullptr, "|", &next_token);
    }

    std::vector<std::string> all_matches;
    for (auto& fut : futures) {
        auto thread_results = fut.get();
        if (!thread_results.empty()) {
            all_matches.insert(all_matches.end(), thread_results.begin(), thread_results.end());
        }
    }

    size_t match_count = all_matches.size();
    if (match_count > 0) {
        std::string results_aggregator;
        for (size_t i = 0; i < all_matches.size(); ++i) {
            if (iMultiResults > 0 && i >= (size_t)iMultiResults) {
                match_count = i;
                break;
            }
            int x, y, w, h;
            sscanf_s(all_matches[i].c_str(), "%d|%d|%d|%d", &x, &y, &w, &h);
            if (iCenterPOS == 1) { x += w / 2; y += h / 2; }
            char single_result[128];
            sprintf_s(single_result, sizeof(single_result), "%d|%d|%d|%d", x, y, w, h);
            if (!results_aggregator.empty()) results_aggregator += ",";
            results_aggregator += single_result;
        }
        sprintf_s(szAnswer, sizeof(szAnswer), "{%zu}[%s]", match_count, results_aggregator.c_str());
    }
    else {
        sprintf_s(szAnswer, sizeof(szAnswer), "{0}[No Match Found]");
    }

    if (iReturnDebug == 1) {
        // FIX: Correct order and number of arguments for sprintf_s
        sprintf_s(szDebug, sizeof(szDebug),
            " | DEBUG: File=%s, Rect=(%d,%d,%d,%d), Tol=%d, Trans=0x%X, Multi=%d, Center=%d, FindAll=%d, AVX2=%d, Scale=(%.2f,%.2f,%.2f)",
            sImageFile, iLeft, iTop, iRight, iBottom, iTolerance, iTransparent, iMultiResults, iCenterPOS, iFindAllOccurrences, g_is_avx2_supported, fMinScale, fMaxScale, fScaleStep);
        // FIX: Correct strcat_s logic
        strcat_s(szAnswer, sizeof(szAnswer), szDebug);
    }

    return szAnswer;
}

#pragma managed(pop)
