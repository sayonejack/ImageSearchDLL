#RequireAdmin
#include <GDIPlus.au3>
#include <ScreenCapture.au3>
#include <WinAPI.au3>
#include <Array.au3>
#include <Misc.au3>
#include <Math.au3>

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
	_SetupImages()

	_TestCase_1_SimpleSearch()
	_TestCase_2_AreaSearch()
	_TestCase_3_MultiImageSearch()
	_TestCase_4_ToleranceSearch()

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
	MouseMove(1, 1)
	Sleep(100)
EndFunc   ;==>_TestCase_1_SimpleSearch

; [Test Case 2] Search for an image only within a specific region (top-left of the screen).
Func _TestCase_2_AreaSearch()
	_ShowNotification("Test Case 2: Searching within 800x600 region...")
	Sleep(250)

	Local $iLeft = 0, $iTop = 0, $iRight = 800, $iBottom = 600
	Local $aResult = _ImageSearch_Area($g_sImage2_Path, $iLeft, $iTop, $iRight, $iBottom)
	_Highlight_Result($aResult, "Test 2: Area Search")
	MouseMove(1, 1)
	Sleep(100)
EndFunc   ;==>_TestCase_2_AreaSearch

; [Test Case 3] Search for one of two possible images.
Func _TestCase_3_MultiImageSearch()
	_ShowNotification("Test Case 3: Searching for multiple images (image 1 or image 2)...")
	Sleep(250)

	Local $sImageList = $g_sImage2_Path & '|' & $g_sImage1_Path
	Local $aResult = _ImageSearch_Area($sImageList, 0, 0, @DesktopWidth, @DesktopHeight, 0, -1, 9, 1, 1, 0.8, 1.2, 0.1, 1)
	_Highlight_Result($aResult, "Test 3: Multi-Image", 1)
	MouseMove(1, 1)
	Sleep(100)
EndFunc   ;==>_TestCase_3_MultiImageSearch

; [Test Case 4] Search with a tolerance to match slightly different images.
Func _TestCase_4_ToleranceSearch()
	_ShowNotification("Test Case 4: Searching with a tolerance of 20...")
	Sleep(250)

	; Assumes $g_sImage1_Path and $g_sImage2_Path are two similar icons
	Local $aResult = _ImageSearch($g_sImage1_Path, 20)
	_Highlight_Result($aResult, "Test 4: Tolerance Search")
	MouseMove(1, 1)
	Sleep(100)
EndFunc   ;==>_TestCase_4_ToleranceSearch



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

; Displays and highlights the search result.
Func _Highlight_Result($aResult, $sTestCase, $bAllMatches = False)
	If @error Then
		_ShowNotification($sTestCase & " - Failed! @error: " & @error)
		Return
	EndIf

	If $bAllMatches Then ; Handle 2D array for multiple results
		If IsArray($aResult) And UBound($aResult, 1) > 1 And $aResult[0][0] > 0 Then
			_ShowNotification($sTestCase & " - Success! Found " & $aResult[0][0] & " results.")
			For $i = 1 To $aResult[0][0]
				Local $x = $aResult[$i][1], $y = $aResult[$i][2], $w = $aResult[$i][3], $h = $aResult[$i][4]
				MouseMove($x, $y)
				_ShowNotification("Result " & $i & " Found at: X=" & $x & ", Y=" & $y)
				Sleep(1000)
			Next
		Else
			_ShowNotification($sTestCase & " - Image not found.")
		EndIf
	Else ; Handle 1D array for a single result
		If IsArray($aResult) And $aResult[0] > 0 Then
			_ShowNotification($sTestCase & " - Success!")
			Local $x = $aResult[1], $y = $aResult[2]
			MouseMove($x, $y)
			_ShowNotification("Found at: X=" & $x & ", Y=" & $y)
		Else
			_ShowNotification($sTestCase & " - Image not found.")
		EndIf
	EndIf

	Sleep(1000) ; Time to see the ToolTip
	ToolTip("") ; Clear the ToolTip
EndFunc   ;==>_Highlight_Result

; Displays a short notification message in the top-left corner.
Func _ShowNotification($sMessage)
	ToolTip($sMessage, 0, 0, "Notification", 1)
	Sleep(500)
EndFunc   ;==>_ShowNotification

; Exits the script.
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
	Local $hCross_GUI = GUICreate("", @DesktopWidth, @DesktopHeight, 0, 0, 0x80000000, BitAND(0x00000080, 0x00000008))
	WinSetTrans($hCross_GUI, "", 8)
	GUISetState(@SW_SHOW, $hCross_GUI)
	GUISetCursor(3, 1, $hCross_GUI)

	Local $hRectangle_GUI = GUICreate("", @DesktopWidth, @DesktopHeight, 0, 0, 0x80000000, BitAND(0x00000080, 0x00000008))
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
	Local $aMouse_Pos = MouseGetPos()
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
;~ 	$hHBitmap = _ScreenCapture_Capture("test3.bmp", $iX1, $iY1, $iX2, $iY2)
EndFunc   ;==>_ImageSearch_Create_BMP
