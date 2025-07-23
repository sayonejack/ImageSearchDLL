# **ImageSearch UDF for AutoIt**

## **Overview**

This is a powerful, high-performance User Defined Function (UDF) for AutoIt designed to find images on the screen. It leverages a custom DLL for processing, making it significantly faster than native AutoIt pixel/image search functions.

The UDF is designed to be robust, flexible, and easy to integrate. A key feature is its hybrid DLL loading mechanism, which makes the script self-contained and simple to distribute.

**Author:** Dao Van Trong \- TRONG.PRO

**Version:** 2025.07.22

## **Features**

* **High-Speed Searching**: Utilizes a pre-compiled DLL (x86 and x64) for rapid image recognition, making it ideal for automation tasks that require speed.  
* **Hybrid DLL Loading**: The UDF intelligently prioritizes a local DLL in the script's directory but will fall back to a self-contained, embedded version if the local file is not found. This means you only need to include the UDF file in your project.  
* **Region Searching**: Search the entire screen or specify a precise rectangular area to improve performance and accuracy.  
* **Color Tolerance**: Find images that are not a perfect match by specifying a tolerance value for color variations.  
* **Image Scaling**: Detect images that have been resized on the screen by specifying a range of scaling factors to test (e.g., find an icon at 80% to 120% of its original size).  
* **Multiple Image Search**: Search for multiple images in a single command. The function can return the location of the first image found or all occurrences of all specified images.  
* **Detailed Return Values**: Returns a structured array with the count and coordinates of found images. Supports both single (1D array) and multiple (2D array) result formats.  
* **Robust Error Handling**: Sets AutoIt's @error macro with specific codes to easily diagnose failed searches.  
* **Automatic Cleanup**: When using the embedded DLL, the temporary file is automatically deleted when the script exits.

## **How It Works: Hybrid DLL Loading**

The UDF uses a smart "hybrid" approach to manage its core DLL:

1. **Local DLL Priority**: It first checks for ImageSearch\_x64.dll or ImageSearch\_x86.dll in the same directory as your script (@ScriptDir). This allows you to easily update the DLL without modifying the UDF code.  
2. **Embedded Fallback**: If no local DLL is found, the UDF automatically extracts an embedded, hex-encoded version of the DLL into the user's temporary directory (@TempDir) and loads it from there.  
3. **Cleanup**: The temporary DLL is automatically removed upon script exit, ensuring no unnecessary files are left on the system.

## **Functions Reference**

### **\_ImageSearch()**

Searches for an image on the entire screen. This is a simplified wrapper for \_ImageSearch\_Area.

Syntax:  
\_ImageSearch($sImagePath\[, $iTolerance \= 0\[, $iCenterPos \= 1\[, $iTransparent \= \-1\[, $bReturn2D \= False\]\]\]\])

* $sImagePath: The full path to the image file to search for.  
* $iTolerance (Optional): The allowed tolerance for color variation (0-255). 0 is an exact match. Default is 0\.  
* $iCenterPos (Optional): If 1, returns the center coordinates of the found image. If 0, returns the top-left coordinates. Default is 1\.  
* $iTransparent (Optional): A color to treat as transparent (e.g., 0xFF00FF). Default is \-1 (none).  
* $bReturn2D (Optional): If True, returns a 2D array with all matches. If False, returns a 1D array with the first match. Default is False.

**Return Value:**

* **Success**:  
  * If $bReturn2D is False: A 1D array \[match\_count, x, y\].  
  * If $bReturn2D is True: A 2D array where \[0\]\[0\] is the match count. Each subsequent row is \[index, x, y, width, height\].  
* **Failure**: An array where the first element is an error code (\<= 0).

### **\_ImageSearch\_Area()**

Searches for an image within a specified rectangular area of the screen. This is the core function with all available options.

Syntax:  
\_ImageSearch\_Area($sImageFile\[, $iLeft \= 0\[, $iTop \= 0\[, $iRight \= @DesktopWidth\[, $iBottom \= @DesktopHeight\[, ...\]\]\]\]\])

* $sImageFile: The full path to the image file. Multiple paths can be provided, separated by |.  
* $iLeft, $iTop, $iRight, $iBottom (Optional): The coordinates of the search area.  
* $iTolerance (Optional): Color variation tolerance (0-255).  
* $iTransparent (Optional): Transparent color value.  
* $iMultiResults (Optional): The maximum number of results to find. Default is 1\.  
* $iCenterPos (Optional): Return center (1) or top-left (0) coordinates.  
* $fMinScale, $fMaxScale (Optional): The minimum and maximum scaling factors to test (e.g., 0.8 for 80%, 1.2 for 120%). Default is 1.0.  
* $fScaleStep (Optional): The step to increment the scale from min to max. Default is 0.1.  
* $bReturn2D (Optional): Return a 2D array with all matches (True) or a 1D array with the first match (False).

**Return Value:**

* Same as \_ImageSearch().

### **\_ImageSearch\_Wait() & \_ImageSearch\_WaitArea()**

These functions repeatedly perform an image search until the image is found or a timeout occurs.

Syntax:  
\_ImageSearch\_Wait($iTimeOut, $sImagePath, ...)  
\_ImageSearch\_WaitArea($iTimeOut, $sImageFile, ...)

* $iTimeOut: The maximum time to wait, in milliseconds.  
* The remaining parameters are identical to \_ImageSearch() and \_ImageSearch\_Area() respectively.

**Return Value:**

* Returns the result of the first successful find, or the last result (indicating failure) if the timeout is reached.

## **Usage Examples**

### **Quick Start**

To use the UDF, simply include it in your script.

\#include "ImageSearch\_UDF.au3"

; Path to the image you want to find  
Local $imagePath \= "path\\to\\your\\image.bmp"

; Search for the image on the entire screen  
Local $result \= \_ImageSearch($imagePath)

; Check if the image was found  
If $result\[0\] \> 0 Then  
    ; $result\[1\] \= X coordinate, $result\[2\] \= Y coordinate  
    ConsoleWrite("Image found at: " & $result\[1\] & ", " & $result\[2\] & @CRLF)  
    MouseMove($result\[1\], $result\[2\])  
Else  
    ConsoleWrite("Image not found. @error: " & @error & @CRLF)  
EndIf

### **Example 1: Searching in a Specific Area**

This example searches for an image only in the top-left 800x600 area of the screen.

\#include "ImageSearch\_UDF.au3"

Local $imagePath \= "path\\to\\image.bmp"  
Local $iLeft \= 0, $iTop \= 0, $iRight \= 800, $iBottom \= 600

Local $result \= \_ImageSearch\_Area($imagePath, $iLeft, $iTop, $iRight, $iBottom)

If $result\[0\] \> 0 Then  
    ConsoleWrite("Image found in the specified area at: " & $result\[1\] & ", " & $result\[2\] & @CRLF)  
EndIf

### **Example 2: Searching for Multiple Images with Scaling**

This example searches for either Search\_1.bmp or Search\_2.bmp. It also checks for scaled versions of the images between 80% and 120% of their original size and returns all found matches.

\#include "ImageSearch\_UDF.au3"

Local $image1 \= "Search\_1.bmp"  
Local $image2 \= "Search\_2.bmp"  
Local $imageList \= $image1 & '|' & $image2

; The last parameter (1) sets $bReturn2D to True  
Local $aResult \= \_ImageSearch\_Area($imageList, 0, 0, @DesktopWidth, @DesktopHeight, 0, \-1, 99, 1, 1, 0.8, 1.2, 0.1, 1\)

If $aResult\[0\]\[0\] \> 0 Then  
    ConsoleWrite("Found " & $aResult\[0\]\[0\] & " total matches." & @CRLF)  
    For $i \= 1 To $aResult\[0\]\[0\]  
        Local $x \= $aResult\[$i\]\[1\]  
        Local $y \= $aResult\[$i\]\[2\]  
        ConsoleWrite("Match " & $i & " found at: " & $x & ", " & $y & @CRLF)  
    Next  
Else  
    ConsoleWrite("No images found." & @CRLF)  
EndIf

### **Example 3: Using Color Tolerance**

This example searches for an image, allowing for a color variation of up to 20\. This is useful if the image on screen has slight compression artifacts or color differences.

\#include "ImageSearch\_UDF.au3"

Local $imagePath \= "path\\to\\image.bmp"

; Search with a tolerance of 20  
Local $result \= \_ImageSearch($imagePath, 20\)

If $result\[0\] \> 0 Then  
    ConsoleWrite("Image found with tolerance at: " & $result\[1\] & ", " & $result\[2\] & @CRLF)  
EndIf  



## **API Reference**

### **ImageSearch.DLL**

char\* WINAPI ImageSearch(  
    char\* sImageFile,  
    int iLeft, int iTop, int iRight, int iBottom,  
    int iTolerance, int iTransparent,  
    int iMultiResults, int iCenterPOS, int iReturnDebug,  
    float fMinScale, float fMaxScale, float fScaleStep  
);

**Parameters:**

* sImageFile (char\*): A pipe-separated (|) string of image file paths to search for.  
* iLeft, iTop, iRight, iBottom (int): The coordinates of the search rectangle. If iRight or iBottom is 0, the screen width/height is used.  
* iTolerance (int): The color tolerance (0-255). 0 means an exact match.  
* iTransparent (int): A COLORREF value (e.g., 0xRRGGBB) to be treated as transparent. Use CLR\_NONE if not needed.  
* iMultiResults (int): The maximum number of results to find. If 0, finds all.  
* iCenterPOS (int): If 1, returns the center coordinates of the found image. Otherwise, returns the top-left corner.  
* iReturnDebug (int): If 1, appends a debug string to the result.  
* fMinScale, fMaxScale, fScaleStep (float): The scaling factors to test (e.g., 0.8, 1.2, 0.1).

**Return Value:**

A static char\* pointer to a formatted string.

* **Success**: "{match\_count}\[x|y|w|h,x2|y2|w2|h2,...\]"  
* **No Match**: "{0}\[No Match Found\]"  
* **Error**: "{error\_code}\[error\_message\]"