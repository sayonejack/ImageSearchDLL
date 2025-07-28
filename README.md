# **High-Performance ImageSearch UDF & DLL for AutoIt**

This project provides a highly optimized UDF (User Defined Function) and two versions of a DLL (Dynamic-Link Library) for fast and flexible image searching on the screen using AutoIt.

It serves as a powerful replacement for standard image search functions, delivering superior speed, especially on modern CPUs, by leveraging advanced SIMD instructions.

## **✨ Key Features**

* **Superior Speed:** The modern version utilizes the **AVX2** instruction set to accelerate the search speed by several factors compared to traditional methods.  
* **Two DLL Versions:** Provides both a modern version (optimized for speed) and a legacy version (for Windows XP support).  
* **Multi-Image Search:** Search for multiple image files in a single function call by separating paths with a pipe (|).  
* **Multi-Scale Searching:** Automatically search for an image across a range of sizes (e.g., from 80% to 120% of its original size).  
* **Color Tolerance:** Find images even with slight color variations by setting a tolerance value (0-255).  
* **Transparent Color Support:** Specify a color in the source image to be ignored during the search.  
* **Flexible Result Handling:**  
  * Find and return the first match.  
  * Find and return all matches on the screen.  
  * Limit the maximum number of results.  
* **Smart (Hybrid) DLL Loading:** The UDF prioritizes an external DLL for maximum performance and automatically falls back to an embedded DLL to ensure the script always runs.  
* **Unicode Support:** Works flawlessly with file paths containing Unicode characters.  
* **Thread-Safe:** The DLL is designed to operate stably in multi-threaded scenarios.  
* **Debug Information:** Provides an option to return a detailed debug string for easy troubleshooting.

## **🚀 The Two DLL Versions**

The project offers two DLL versions to meet different needs:

### **1\. ImageSearch\_x86.dll ImageSearch\_x64.dll (Modern Version)**
(Attached in the same UDF folder - Because the DLL file with AVX2 support is large in size)
This is the recommended version for most users.

* **Strengths:**  
  * **AVX2 Support:** Leverages Advanced Vector Extensions 2 on modern CPUs to process multiple pixels in parallel, resulting in extremely fast search speeds.  
  * Built with modern C++, ensuring stability and efficiency.  
* **Limitations:**  
  * Not compatible with Windows XP.  
* **When to use:** When you need maximum performance on Windows 7, 8, 10, 11, and newer.

### **2\. ImageSearch\_XP.dll (Legacy Version)**
(Embedded in UDF code)
This version is created for backward compatibility.

* **Strengths:**  
  * **Windows XP Compatibility:** Works well on the Windows XP (SP3) operating system.  
* **Limitations:**  
  * **No AVX2 Support:** Search speed will be significantly slower than the modern version on AVX2-supported CPUs.  
* **When to use:** When your script must run in a Windows XP environment.

## **⚙️ How the UDF Works**

The ImageSearch\_UDF.au3 file uses a very smart "hybrid" DLL loading mechanism:

1. **Prioritize External DLL:** When the \_ImageSearch function is called, the UDF first looks for ImageSearch\_x86.dll and ImageSearch\_x64.dll in the same directory as the script (@ScriptDir). If found, it uses this file to achieve the best performance (with AVX2 if available).  
2. **Fallback to Embedded DLL:** If the external DLL is not found, the UDF will automatically extract and use a **legacy (non-AVX2) compatible** DLL version that is embedded within it as a hex string.

➡️ **This ensures that your script can always run**, even if you forget to copy the DLL file. However, for the highest speed, always place the modern ImageSearch\_x86.dll and ImageSearch\_x64.dll next to your script.

## **📦 Setup**

1. **Place the DLL file:** Copy ImageSearch\_x86.dll and ImageSearch\_x64.dll (the modern version) into the same directory as your AutoIt script file. 
2. **Include the UDF in your script:** Use the line \#include \<ImageSearch\_UDF.au3\> in your script.

## **📖 API Reference**

The main function for performing an image search.

### **\_ImageSearch($sImageFile, \[$iLeft \= 0\], \[$iTop \= 0\], \[$iRight \= 0\], \[$iBottom \= 0\], \[$iTolerance \= 10\], \[$iTransparent \= 0xFFFFFFFF\], \[$iMultiResults \= 0\], \[$iCenterPOS \= 1\], \[$iReturnDebug \= 0\], \[$fMinScale \= 1.0\], \[$fMaxScale \= 1.0\], \[$fScaleStep \= 0.1\], \[$iFindAllOccurrences \= 0\])**

**Parameters**

| Parameter | Type | Default | Description |
| :---- | :---- | :---- | :---- |
| $sImageFile | String | \- | Path to the image file. To search for multiple images, separate paths with a pipe (\` |
| $iLeft | Int | 0 | The left coordinate of the search area. 0 defaults to the entire screen. |
| $iTop | Int | 0 | The top coordinate of the search area. 0 defaults to the entire screen. |
| $iRight | Int | 0 | The right coordinate of the search area. 0 defaults to the entire screen. |
| $iBottom | Int | 0 | The bottom coordinate of the search area. 0 defaults to the entire screen. |
| $iTolerance | Int | 10 | Color tolerance (0-255). A higher value allows for greater color variation. |
| $iTransparent | Int | 0xFFFFFFFF | The color (in 0xRRGGBB format) to be ignored in the source image. 0xFFFFFFFF means no transparency. |
| $iMultiResults | Int | 0 | The maximum number of results to return. 0 means no limit. |
| $iCenterPOS | Bool | 1 (True) | If True, the returned X/Y coordinates will be the center of the found image. If False, they will be the top-left corner. |
| $iReturnDebug | Bool | 0 (False) | If True, the function returns a debug string instead of the results array. |
| $fMinScale | Float | 1.0 | The minimum scaling factor for the search (e.g., 0.8 for 80%). Must be \>= 0.1. |
| $fMaxScale | Float | 1.0 | The maximum scaling factor for the search (e.g., 1.2 for 120%). |
| $fScaleStep | Float | 0.1 | The increment to use when searching between min and max scales. Must be \>= 0.01. |
| $iFindAllOccurrences | Bool | 0 (False) | If False, the search stops after the first match. If True, it finds all possible matches. |

**Return Value**

* **On Success:** Returns a 2D array containing the coordinates of the found images.  
  * $aResult\[0\]\[0\] \= The number of matches found.  
  * $aResult\[1\] to $aResult\[$aResult\[0\]\[0\]\] \= An array for each match.  
  * $aResult\[$i\]\[0\] \= X coordinate  
  * $aResult\[$i\]\[1\] \= Y coordinate  
  * $aResult\[$i\]\[2\] \= Width of the found image  
  * $aResult\[$i\]\[3\] \= Height of the found image  
* **On Failure / No Match:** Sets @error to 1 and returns 0\.  
* **In Debug Mode:** If $iReturnDebug is True, returns a string containing detailed information about the last search operation.

## **💻 Examples**

### **Example 1: Basic Search**

Find the first occurrence of button.png on the screen.
```
\#include \<ImageSearch\_UDF.au3\>

Local $aResult \= \_ImageSearch("C:\\images\\button.png")

If @error Then  
    MsgBox(48, "Error", "Image not found on screen.")  
Else  
    Local $iCount \= $aResult\[0\]\[0\]  
    Local $iX \= $aResult\[1\]\[0\]  
    Local $iY \= $aResult\[1\]\[1\]  
    MsgBox(64, "Success", "Found " & $iCount & " image(s). First match is at: " & $iX & ", " & $iY)  
    MouseMove($iX, $iY, 20\) ; Move mouse to the center of the found image  
EndIf
```
### **Example 2: Advanced Search (Multiple Images, Tolerance, Scaling)**

Search for icon1.png or icon2.png within a specific region, with a tolerance of 20 and scaling from 90% to 110%. Find all occurrences.
```
\#include \<ImageSearch\_UDF.au3\>

Local $sImages \= "icon1.png|icon2.png"  
Local $iTolerance \= 20  
Local $fMinScale \= 0.9  
Local $fMaxScale \= 1.1  
Local $fStep \= 0.05

Local $aResult \= \_ImageSearch($sImages, 500, 300, 1200, 800, $iTolerance, 0xFFFFFFFF, 0, True, False, $fMinScale, $fMaxScale, $fStep, True)

If @error Then  
    MsgBox(48, "Error", "No matching images found in the specified region.")  
Else  
    Local $iCount \= $aResult\[0\]\[0\]  
    ConsoleWrite("Found " & $iCount & " total matches." & @CRLF)

    For $i \= 1 To $iCount  
        ConsoleWrite("Match \#" & $i & ": X=" & $aResult\[$i\]\[0\] & ", Y=" & $aResult\[$i\]\[1\] & ", W=" & $aResult\[$i\]\[2\] & ", H=" & $aResult\[$i\]\[3\] & @CRLF)  
    Next  
EndIf
```
### **Example 3: Using Debug Mode**

To diagnose issues, use the $iReturnDebug parameter.
```
\#include \<ImageSearch\_UDF.au3\>

Local $sDebugInfo \= \_ImageSearch("image\_not\_exist.png", 0, 0, 0, 0, 10, 0xFFFFFFFF, 0, True, True)

; The return value is now a string  
ConsoleWrite($sDebugInfo & @CRLF)  
; Example output: {0}\[No Match Found\] | DEBUG: File=image\_not\_exist.png, Rect=(0,0,1920,1080), Tol=10, Trans=0xffffffff, Multi=0, Center=1, FindAll=0, AVX2=true, Scale=(1.00,1.00,0.10)
```

## **Credits**

* **Author:** Dao Van Trong \- TRONG.PRO  
