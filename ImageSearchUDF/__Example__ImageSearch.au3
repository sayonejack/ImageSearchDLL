#RequireAdmin
#cs ----------------------------------------------------------------------------
;
;    Title .........: ImageSearch UDF - Example Script
;    AutoIt Version : 3.3.16.1
;    Author ........: Dao Van Trong - TRONG.PRO
;    Date ..........: 2025-07-28
;    Requires ......: ImageSearch_UDF.au3 must be in the same directory.
;
; -------------------------------------------------------------------------------------------------------------------------------
; #SECTION# SCRIPT OVERVIEW
; -------------------------------------------------------------------------------------------------------------------------------
;
; This script serves as a practical demonstration and testing ground for the functions within the
; ImageSearch_UDF.au3 library. It is designed to walk you through various common use cases, from a simple
; full-screen search to more complex scenarios involving search areas, multiple images, and finding all occurrences.
;
; By running this script, you can visually see how each function works and use it as a template to build your
; own automation scripts.
;
; -------------------------------------------------------------------------------------------------------------------------------
; #SECTION# HOW TO USE THIS EXAMPLE SCRIPT
; -------------------------------------------------------------------------------------------------------------------------------
;
; 1. PREREQUISITES:
;    - Ensure the latest version of `ImageSearch_UDF.au3` is in the same folder as this script.
;    - Ensure the `ImageSearch_x64.dll` or `ImageSearch_x86.dll` is also in the same folder, OR
;      that the UDF has the DLL's hex code embedded within it.
;
; 2. FIRST-TIME RUN (IMAGE CREATION):
;    - The first time you run this script, it will detect that the sample images (`Search_1.bmp` and `Search_2.bmp`)
;      do not exist.
;    - A message box will appear, instructing you to create them. Click "OK".
;    - Your mouse cursor will turn into a crosshair. Click and drag a rectangle around any object on your screen
;      (like a desktop icon) to create `Search_1.bmp`.
;    - The process will repeat. Select a DIFFERENT object to create `Search_2.bmp`.
;    - Once both images are created, the script will automatically proceed with the test cases.
;
; 3. WATCH THE TESTS:
;    - The script will execute five different test cases. For each test, a notification will appear in the top-left
;      corner of the screen.
;    - When an image is found, the mouse will move to its location, and a ToolTip will display the coordinates.
;
; 4. EXIT THE SCRIPT:
;    - Press the 'Esc' key at any time to terminate the script.
;
; -------------------------------------------------------------------------------------------------------------------------------
; #SECTION# TEST CASE DESCRIPTIONS
; -------------------------------------------------------------------------------------------------------------------------------
;
;   - _TestCase_1_SimpleSearch:
;     Demonstrates the most basic usage: searching for a single image across the entire screen using the `_ImageSearch()` function.
;
;   - _TestCase_2_AreaSearch:
;     Shows how to limit the search to a specific rectangular region (the top-left 800x600 pixels of the screen)
;     using `_ImageSearch_Area()`. This is much faster than a full-screen search.
;
;   - _TestCase_3_MultiImageSearch:
;     Illustrates how to search for multiple different images at once by providing a list of paths separated by a pipe `|`.
;     The script will find all occurrences of *any* of the specified images.
;
;   - _TestCase_4_ToleranceSearch:
;     Shows the effect of the `$iTolerance` parameter. This allows the function to find images that are not a
;     pixel-perfect match, which is useful for dealing with slight variations in color or anti-aliasing.
;
;   - _TestCase_5_FindAllOccurrences:
;     Highlights the "Find All" feature. A temporary window is created with multiple copies of the same image,
;     and the script uses the `$bReturnAll = True` parameter to find and highlight every single one of them.
;
#ce ----------------------------------------------------------------------------

#include <GDIPlus.au3>
#include <ScreenCapture.au3>
#include <WinAPI.au3>
#include <Array.au3>
#include <Misc.au3>
#include <Math.au3>
#include <GuiConstantsEx.au3>
#include <WindowsStylesConstants.au3>

Opt("MustDeclareVars", 1)

; Main UDF for the ImageSearch functionality
#include "ImageSearch_UDF.au3"

; Global variables to store the paths to the sample images
Global $g_sImage1_Path, $g_sImage2_Path

; Set a hotkey: Pressing ESC will exit the script
HotKeySet("{Esc}", "_ExitScript")

; === MAIN SCRIPT START ===
_Main()
; =========================

Func _Main()
	; Initialize the ImageSearch DLL. This should be the first step.
	If Not _ImageSearch_Startup() Then
		MsgBox(16, "Fatal Error", "Failed to initialize the ImageSearch DLL. @error: " & @error & @CRLF & "The script will now exit.")
		Exit
	EndIf

	_SetupImages()

	_TestCase_1_SimpleSearch()
	_TestCase_2_AreaSearch()
	_TestCase_3_MultiImageSearch()
	_TestCase_4_ToleranceSearch()
	_TestCase_5_FindAllOccurrences() ; New test case for the "Find All" feature

	_ShowNotification("All test cases complete. Press ESC to exit.")
EndFunc   ;==>_Main

; --------------------------------------------------------------------------------------
; TEST CASES
; --------------------------------------------------------------------------------------

; [Test Case 1] Search for a single image on the entire screen.
Func _TestCase_1_SimpleSearch()
	_ShowNotification("Test Case 1: Simple full-screen search...")
	Sleep(250)

	Local $aResult = _ImageSearch($g_sImage1_Path)
	_Highlight_Result($aResult, "Test 1: Simple Search")
	Sleep(100)
EndFunc   ;==>_TestCase_1_SimpleSearch

; [Test Case 2] Search for an image only within a specific region (top-left of the screen).
Func _TestCase_2_AreaSearch()
	_ShowNotification("Test Case 2: Searching within 800x600 region...")
	Sleep(250)

	Local $iLeft = 0, $iTop = 0, $iRight = 800, $iBottom = 600
	Local $aResult = _ImageSearch_Area($g_sImage2_Path, $iLeft, $iTop, $iRight, $iBottom)
	_Highlight_Result($aResult, "Test 2: Area Search")
	Sleep(100)
EndFunc   ;==>_TestCase_2_AreaSearch

; [Test Case 3] Search for one of two possible images, finding all occurrences.
Func _TestCase_3_MultiImageSearch()
	_ShowNotification("Test Case 3: Searching for multiple images (image 1 or image 2)...")
	Sleep(250)

	Local $sImageList = $g_sImage2_Path & '|' & $g_sImage1_Path
	; The last parameter (iFindAllOccurrences) is set to 1 to find all matches
	Local $aResult = _ImageSearch_Area($sImageList, 0, 0, @DesktopWidth, @DesktopHeight, 10, -1, 99, 1, 1, 1.0, 1.0, 0.1, 1)
	_Highlight_Result($aResult, "Test 3: Multi-Image Search")
	Sleep(100)
EndFunc   ;==>_TestCase_3_MultiImageSearch

; [Test Case 4] Search with a tolerance to match slightly different images.
Func _TestCase_4_ToleranceSearch()
	_ShowNotification("Test Case 4: Searching with a tolerance of 20...")
	Sleep(250)

	; Assumes $g_sImage1_Path and $g_sImage2_Path are two similar icons
	Local $aResult = _ImageSearch($g_sImage1_Path, 20)
	_Highlight_Result($aResult, "Test 4: Tolerance Search")
	Sleep(100)
EndFunc   ;==>_TestCase_4_ToleranceSearch

; [Test Case 5] Find all occurrences of a single image.
Func _TestCase_5_FindAllOccurrences()
	_ShowNotification("Test Case 5: Finding all occurrences...")
;~ 	Sleep(250)

;~ 	; Create a temporary GUI with multiple instances of the same image for the test
;~ 	Local $hTestGUI = GUICreate("Test Case 5", 400, 200, -1, -1)
;~ 	GUICtrlCreatePic($g_sImage1_Path, 10, 10, -1, -1)
;~ 	GUICtrlCreatePic($g_sImage1_Path, 150, 20, -1, -1)
;~ 	GUICtrlCreatePic($g_sImage1_Path, 300, 100, -1, -1)
;~ 	GUICtrlCreatePic($g_sImage1_Path, 50, 120, -1, -1)
;~ 	GUISetState(@SW_SHOW, $hTestGUI)
;~ 	Sleep(500) ; Give the GUI time to appear

	; Search for the image, setting $bReturnAll parameter to True
	Local $aResult = _ImageSearch($g_sImage1_Path, 10, 1, -1, True)
	_Highlight_Result($aResult, "Test 5: Find All Occurrences")

;~ 	GUIDelete($hTestGUI) ; Clean up the test GUI
	Sleep(100)
EndFunc   ;==>_TestCase_5_FindAllOccurrences


; --------------------------------------------------------------------------------------
; HELPER FUNCTIONS
; --------------------------------------------------------------------------------------

; Sets up the sample images, prompting the user to create them if they don't exist.
Func _SetupImages()
	Local $sScriptDir = @ScriptDir
	$g_sImage1_Path = $sScriptDir & "\Search_1.bmp"
	$g_sImage2_Path = $sScriptDir & "\Search_2.bmp"

	If Not FileExists($g_sImage1_Path) Or Not FileExists($g_sImage2_Path) Then
		MsgBox(48, "Initial Setup", "Please create 2 BMP image files for testing." & @CRLF & _
				"1. Rerun the script." & @CRLF & _
				"2. When the cursor changes, click and drag to select a desktop icon for Search_1.bmp." & @CRLF & _
				"3. Repeat for another icon to create Search_2.bmp.")
		_ImageSearch_Create_BMP($g_sImage1_Path)
		_ImageSearch_Create_BMP($g_sImage2_Path)
		If Not FileExists($g_sImage1_Path) Or Not FileExists($g_sImage2_Path) Then
			MsgBox(16, "Error", "Could not create image files. The script will now exit.")
			Exit
		EndIf
	EndIf
EndFunc   ;==>_SetupImages

; Displays and highlights the search result by moving the mouse and showing a tooltip.
; This function now always expects a 2D array.
Func _Highlight_Result($aResult, $sTestCase)
	If @error Then
		_ShowNotification($sTestCase & " - Failed! @error: " & @error)
		Return
	EndIf

	; The UDF always returns a 2D array. Check for success by looking at the count in [0][0].
	If IsArray($aResult) And UBound($aResult, 0) > 0 And $aResult[0][0] > 0 Then
		Local $iFoundCount = $aResult[0][0]
		_ShowNotification($sTestCase & " - Success! Found " & $iFoundCount & " result(s).")
		For $i = 1 To $iFoundCount
			Local $x = $aResult[$i][1]
			Local $y = $aResult[$i][2]
			MouseMove($x, $y, 10)
			_ShowNotification("Result " & $i & " of " & $iFoundCount & " found at: X=" & $x & ", Y=" & $y)
			Sleep(1000)
		Next
	Else
		_ShowNotification($sTestCase & " - Image not found.")
	EndIf

	Sleep(1500) ; Time to see the ToolTip
	ToolTip("") ; Clear the ToolTip
EndFunc   ;==>_Highlight_Result


; Displays a short notification message in the top-left corner.
Func _ShowNotification($sMessage)
	ToolTip($sMessage, 0, 0, "Notification", 1)
	Sleep(500)
EndFunc   ;==>_ShowNotification

; Exits the script. This will trigger the OnAutoItExitRegister function.
Func _ExitScript()
	Exit
EndFunc   ;==>_ExitScript

;===============================================================================
;
; Function:      _ImageSearch_Create_BMP($sFilePath)
;
; Description:   Creates a transparent GUI to allow the user to select a screen region by dragging the mouse.
;                This version creates a new GUI in a loop to draw the rectangle, which prevents flickering.
;
; Parameters:    $sFilePath - The path to save the captured image file.
;
; Return values: Success - Returns 1
;                Failure - Returns 0 and sets @error if user cancels (ESC) or capture fails.
;
;===============================================================================

; Thanks for Melba23 about rectangle example
Func _ImageSearch_Create_BMP($Filename)
	Local $aMouse_Pos, $hMask, $hMaster_Mask, $iTemp
	Local $UserDLL = DllOpen("user32.dll")

	; Create transparent GUI with Cross cursor
	Local $hCross_GUI = GUICreate("", @DesktopWidth, @DesktopHeight, 0, 0, $WS_POPUP, BitAND($WS_EX_LAYERED, $WS_EX_TOPMOST))
	WinSetTrans($hCross_GUI, "", 8)
	GUISetState(@SW_SHOW, $hCross_GUI)
	GUISetCursor(3, 1, $hCross_GUI)

	Local $hRectangle_GUI = GUICreate("", @DesktopWidth, @DesktopHeight, 0, 0, $WS_POPUP, BitAND($WS_EX_LAYERED, $WS_EX_TOPMOST))
	GUISetBkColor(0x000000)

	; Wait until mouse button pressed
	While Not _IsPressed("01", $UserDLL)
		If _IsPressed("1B", $UserDLL) Then
			GUIDelete($hRectangle_GUI)
			GUIDelete($hCross_GUI)
			DllClose($UserDLL)
			Return -2
		EndIf

		Sleep(10)
	WEnd

	; Get first mouse position
	$aMouse_Pos = MouseGetPos()
	Local $iX1 = $aMouse_Pos[0]
	Local $iY1 = $aMouse_Pos[1]
	; Draw rectangle while mouse button pressed
	While _IsPressed("01", $UserDLL)

		$aMouse_Pos = MouseGetPos()

		$hMaster_Mask = _WinAPI_CreateRectRgn(0, 0, 0, 0)
		$hMask = _WinAPI_CreateRectRgn($iX1, $aMouse_Pos[1], $aMouse_Pos[0], $aMouse_Pos[1] + 1) ; Bottom of rectangle
		_WinAPI_CombineRgn($hMaster_Mask, $hMask, $hMaster_Mask, 2)
		_WinAPI_DeleteObject($hMask)
		$hMask = _WinAPI_CreateRectRgn($iX1, $iY1, $iX1 + 1, $aMouse_Pos[1]) ; Left of rectangle
		_WinAPI_CombineRgn($hMaster_Mask, $hMask, $hMaster_Mask, 2)
		_WinAPI_DeleteObject($hMask)
		$hMask = _WinAPI_CreateRectRgn($iX1 + 1, $iY1 + 1, $aMouse_Pos[0], $iY1) ; Top of rectangle
		_WinAPI_CombineRgn($hMaster_Mask, $hMask, $hMaster_Mask, 2)
		_WinAPI_DeleteObject($hMask)
		$hMask = _WinAPI_CreateRectRgn($aMouse_Pos[0], $iY1, $aMouse_Pos[0] + 1, $aMouse_Pos[1]) ; Right of rectangle
		_WinAPI_CombineRgn($hMaster_Mask, $hMask, $hMaster_Mask, 2)
		_WinAPI_DeleteObject($hMask)
		; Set overall region
		_WinAPI_SetWindowRgn($hRectangle_GUI, $hMaster_Mask)

		If WinGetState($hRectangle_GUI) < 15 Then GUISetState()
		Sleep(10)

	WEnd

	; Get second mouse position
	Local $iX2 = $aMouse_Pos[0]
	Local $iY2 = $aMouse_Pos[1]

	; Set in correct order if required
	If $iX2 < $iX1 Then
		$iTemp = $iX1
		$iX1 = $iX2
		$iX2 = $iTemp
	EndIf
	If $iY2 < $iY1 Then
		$iTemp = $iY1
		$iY1 = $iY2
		$iY2 = $iTemp
	EndIf
	GUIDelete($hRectangle_GUI)
	GUIDelete($hCross_GUI)
	DllClose($UserDLL)
	Local $mouse = MouseGetPos() ; remove mouse to other
	MouseMove($mouse[0] + 10, $mouse[1] + 10)
	Sleep(1000)
	_GDIPlus_Startup()
	Local $hHBitmap = _ScreenCapture_Capture("", $iX1, $iY1, $iX2, $iY2)
	Local $hImage1 = _GDIPlus_BitmapCreateFromHBITMAP($hHBitmap)
	_GDIPlus_ImageSaveToFile($hImage1, $Filename)
	_GDIPlus_Shutdown()
EndFunc   ;==>_ImageSearch_Create_BMP
