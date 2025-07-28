#RequireAdmin
#Region ;**** Directives created by AutoIt3Wrapper_GUI ****
#AutoIt3Wrapper_UseX64=y
#EndRegion ;**** Directives created by AutoIt3Wrapper_GUI ****
#pragma compile(x64, true)
#cs ----------------------------------------------------------------------------
;
;    Title .........: ImageSearch Automation Suite (Refactored)
;    AutoIt Version : 3.3.16.1
;    Author ........: Dao Van Trong (TRONG.PRO)
;    Date ..........: 2025-07-28
;    Note ..........: This script is a graphical user interface (GUI) front-end for the
;                     ImageSearch_UDF.au3 and its underlying ImageSearch.dll.
;
; -------------------------------------------------------------------------------------------------------------------------------
; #SECTION# SCRIPT OVERVIEW
; -------------------------------------------------------------------------------------------------------------------------------
;
; This script provides a powerful and user-friendly interface for performing complex image search and automation tasks.
; It acts as a control panel for the high-performance ImageSearch UDF, allowing you to visually configure, execute,
; and log search operations without writing complex code. It is designed for tasks ranging from simple automation
; to advanced botting and UI testing.
;
; -------------------------------------------------------------------------------------------------------------------------------
; #SECTION# FIRST-TIME SETUP
; -------------------------------------------------------------------------------------------------------------------------------
;
; Before you can start a search, you need to provide the images you want to find.
;
; 1. RUN THE SCRIPT: The main window will appear. On the right side, you will see 12 empty "Image Target" slots.
;
; 2. CREATE AN IMAGE: Click the "Create" button next to slot #1.
;
; 3. CAPTURE THE REGION: The script window will hide. Your mouse cursor will turn into a crosshair.
;    Click and drag a rectangle around the object on the screen you want to find. When you release the mouse button,
;    a bitmap image named "Search_1.bmp" will be saved in the same directory as the script.
;
; 4. PREVIEW UPDATES: The image you just captured will now appear in the preview panel for slot #1.
;
; 5. REPEAT: Repeat this process for any other images you need to find (up to 12).
;
; -------------------------------------------------------------------------------------------------------------------------------
; #SECTION# GUI ELEMENT GUIDE
; -------------------------------------------------------------------------------------------------------------------------------
;
; === Image Targets (Right Panel) ===
;   - Checkbox (1-12): Tick the box next to an image to include it in the next search operation.
;   - Create Button: Click to capture a screen region and save it as the image for that slot.
;   - Image Preview: Shows the image that will be searched for. It displays a placeholder if the .bmp file doesn't exist.
;
; === Configuration -> Search Mode (Top-Left) ===
;   - [ ] Multi Search (All at once):
;       - If UNCHECKED (Single Mode - Default): The script searches for selected images one by one, in order.
;       - If CHECKED (Multi Mode): The script searches for ALL selected images in a single, highly efficient operation.
;         It will find the FIRST available match from the list of selected images.
;
;   - [ ] Find All Occurrences:
;       - If UNCHECKED (Default): The search stops as soon as the first match is found.
;       - If CHECKED: The search will find EVERY instance of the selected image(s) on the screen.
;
;   - [ ] Wait for Image Found:
;       - If CHECKED: The script will repeatedly search for the image until it is found or the "Timeout" value is reached.
;
;   - [ ] Use Tolerance:
;       - If CHECKED: Allows for inexact matches. The "Tolerance" value (0-255) determines how much color variation is allowed.
;
;   - [ ] Use Custom Area:
;       - If CHECKED: The search will be restricted to the coordinates defined in the "Search Area" group box.
;       - If UNCHECKED: The search will be performed on the entire screen.
;
;   - [ ] Enable DLL Debug:
;       - If CHECKED: The raw output from the DLL, including detailed debug info, will be printed in the Activity Log.
;         Useful for advanced troubleshooting.
;
; === Configuration -> Parameters ===
;   - Timeout (ms): The maximum time (in milliseconds) to wait when "Wait for Image Found" is enabled.
;   - Tolerance: A number from 0 (exact match) to 255 (very loose match). A good starting value is 10-20.
;   - Delay (ms): The time (in milliseconds) to pause after performing an action (like a click) on a found image.
;
; === Configuration -> Search Area ===
;   - Left, Top, Right, Bottom: The pixel coordinates of the rectangular search area.
;   - Select Area Button: A convenient tool to draw a rectangle on the screen with your mouse to automatically fill in these coordinates.
;
; === Configuration -> Actions on Found ===
;   - [ ] Move Mouse: If checked, the mouse cursor will move to the location of the found image.
;   - Click (None / Single / Double): Choose the mouse action to perform after the image is found. The click will happen at the
;     coordinates of the found image (center or top-left, depending on UDF settings).
;
; === Main Action Buttons ===
;   - Start Search: Begins the search operation using all the currently selected settings.
;   - Select All: Checks all 12 image target boxes.
;   - Deselect All: Unchecks all 12 image target boxes.
;
; === Bottom Panels ===
;   - Activity Log: Displays a timestamped log of all actions, search results, and errors.
;   - System Information: Shows details about your OS, AutoIt version, and the specific ImageSearch DLL being used.
;   - Status Bar: Provides real-time feedback on the script's current state (e.g., "Ready", "Searching...", "Search complete").
;
; -------------------------------------------------------------------------------------------------------------------------------
; #SECTION# WORKFLOW EXAMPLES
; -------------------------------------------------------------------------------------------------------------------------------
;
;   Scenario 1: Click a "Login" button that might be in one of two different styles.
;   --------------------------------------------------------------------------------
;   1. Create "Search_1.bmp" of the first login button style.
;   2. Create "Search_2.bmp" of the second login button style.
;   3. Check the boxes for images 1 and 2.
;   4. Check "Multi Search" (to find whichever appears first).
;   5. Set "Actions on Found" to "Single" click.
;   6. Click "Start Search". The script will find the first available login button and click it.
;
;   Scenario 2: Count how many gold coin icons are visible inside a game window.
;   --------------------------------------------------------------------------------
;   1. Create "Search_1.bmp" of a single gold coin icon.
;   2. Check the box for image 1.
;   3. Uncheck "Multi Search".
;   4. Check "Find All Occurrences".
;   5. Check "Use Custom Area" and use the "Select Area" button to draw a box around the game window.
;   6. Set "Actions on Found" to "None" for the click action.
;   7. Click "Start Search". The Activity Log will show "Found X match(es)" where X is the number of coins.
;
#ce ----------------------------------------------------------------------------

#include <Array.au3>
#include <GDIPlus.au3>
#include <ScreenCapture.au3>
#include <WinAPI.au3>
#include <WindowsConstants.au3>
#include <GUIConstantsEx.au3>
#include <EditConstants.au3>
#include <StaticConstants.au3>
#include <ButtonConstants.au3>
#include <Date.au3>
#include <Misc.au3>
#include <Math.au3>
#include <GuiEdit.au3>
#include <GuiStatusBar.au3>
#include "ImageSearch_UDF.au3"


;Opt("MustDeclareVars", 1)

; === GLOBAL CONSTANTS AND VARIABLES ===
Global Const $MAX_IMAGES = 12
Global Const $g_sPlaceholderPath = @WindowsDir & "\Web\Wallpaper\Windows\img0.jpg"
Global $g_asImagePaths[$MAX_IMAGES], $g_nMsg, $g_hMainGUI, $g_hLog, $g_hStatusBar
; --- GUI Control IDs ---
Global $g_idBtnStart, $g_idBtnSelectAll, $g_idBtnDeselectAll, $g_idBtnSelectArea
Global $g_idInputDelay, $g_idChkMoveMouse
Global $g_idRadNoClick, $g_idRadSingleClick, $g_idRadDoubleClick
Global $g_idChkWait, $g_idInputWaitTime
Global $g_idChkUseArea, $g_idInputLeft, $g_idInputTop, $g_idInputRight, $g_idInputBottom
Global $g_idChkMultiSearch, $g_idChkFindAll, $g_idChkUseTolerance, $g_idInputTolerance, $g_idChkEnableDebug
Global $g_aidPic[$MAX_IMAGES], $g_aidChkSearch[$MAX_IMAGES], $g_aidBtnCreate[$MAX_IMAGES]

_Main()

; #FUNCTION# ====================================================================================================================
; Name...........: _Main
; Description....: Main program entry point. Initializes components and enters the GUI message loop.
; ===============================================================================================================================
Func _Main()
	; Explicitly initialize the ImageSearch library
	If Not _ImageSearch_Startup() Then
		MsgBox(16, "Fatal Error", "Failed to initialize the ImageSearch DLL. @error: " & @error & @CRLF & "The script will now exit.")
		Exit
	EndIf

	_GDIPlus_Startup()
	_InitializeImagePaths()
	_CreateGUI()
	_UpdateAllImagePreviews()

	; Main message loop to handle GUI events.
	While 1
		$g_nMsg = GUIGetMsg()
		Switch $g_nMsg
			Case $GUI_EVENT_CLOSE
				ExitLoop

			Case $g_idBtnStart
				_StartSearch()

			Case $g_idBtnSelectAll
				_SelectAll(True)

			Case $g_idBtnDeselectAll
				_SelectAll(False)

			Case $g_idBtnSelectArea
				_SelectAreaOnScreen()

			Case $g_aidBtnCreate[0] To $g_aidBtnCreate[$MAX_IMAGES - 1]
				_HandleImageCreation($g_nMsg)

		EndSwitch
	WEnd
	_Exit()
EndFunc   ;==>_Main

; === GUI AND INITIALIZATION FUNCTIONS ===

; #FUNCTION# ====================================================================================================================
; Name...........: _InitializeImagePaths
; Description....: Populates the global array with default paths for the search images.
; ===============================================================================================================================
Func _InitializeImagePaths()
	For $i = 0 To $MAX_IMAGES - 1
		$g_asImagePaths[$i] = @ScriptDir & "\Search_" & $i + 1 & ".bmp"
	Next
EndFunc   ;==>_InitializeImagePaths

; #FUNCTION# ====================================================================================================================
; Name...........: _CreateGUI
; Description....: Creates the entire graphical user interface, defining all controls and their positions.
; ===============================================================================================================================
Func _CreateGUI()
	$g_hMainGUI = GUICreate("ImageSearch Automation Suite (Refactored) by Dao Van Trong - TRONG.PRO", 904, 650)

	; --- TOP: CONFIGURATION ---
	GUICtrlCreateGroup("Configuration", 10, 10, 390, 300)
	; --- Search Mode ---
	GUICtrlCreateGroup("Search Mode", 20, 30, 180, 175)
	$g_idChkMultiSearch = GUICtrlCreateCheckbox("Multi Search (All at once)", 30, 50, 160, 20)
	GUICtrlSetTip(-1, "Searches for all selected images in a single operation." & @CRLF & "Finds the FIRST occurrence of ANY of the selected images.")
	$g_idChkFindAll = GUICtrlCreateCheckbox("Find All Occurrences", 30, 75, 160, 20)
	GUICtrlSetTip(-1, "Finds EVERY instance of the selected image(s), not just the first one.")
	$g_idChkWait = GUICtrlCreateCheckbox("Wait for Image Found", 30, 100, 160, 20)
	$g_idChkUseTolerance = GUICtrlCreateCheckbox("Use Tolerance", 30, 125, 160, 20)
	GUICtrlSetState(-1, $GUI_CHECKED)
	$g_idChkUseArea = GUICtrlCreateCheckbox("Use Custom Area", 30, 150, 160, 20)
	$g_idChkEnableDebug = GUICtrlCreateCheckbox("Enable DLL Debug", 30, 175, 160, 20)
	GUICtrlSetState(-1, $GUI_CHECKED)
	GUICtrlSetTip(-1, "Log detailed information from the DLL.")
	; --- Parameters ---
	GUICtrlCreateGroup("Parameters", 210, 30, 180, 94)
	GUICtrlCreateLabel("Timeout (ms)", 220, 50, 80, 20)
	$g_idInputWaitTime = GUICtrlCreateInput("5000", 300, 47, 80, 21)
	GUICtrlCreateLabel("Tolerance:", 220, 75, 80, 20)
	$g_idInputTolerance = GUICtrlCreateInput("10", 300, 72, 80, 21)
	GUICtrlCreateLabel("Delay (ms)", 220, 100, 80, 20)
	$g_idInputDelay = GUICtrlCreateInput("500", 300, 97, 80, 21)
	; --- Search Area ---
	GUICtrlCreateGroup("Search Area", 16, 210, 188, 98)
	GUICtrlCreateLabel("Left:", 26, 230, 30, 20)
	$g_idInputLeft = GUICtrlCreateInput("0", 61, 227, 50, 21)
	GUICtrlCreateLabel("Top:", 121, 230, 30, 20)
	$g_idInputTop = GUICtrlCreateInput("0", 156, 227, 30, 21)
	GUICtrlCreateLabel("Right:", 26, 255, 35, 20)
	$g_idInputRight = GUICtrlCreateInput(@DesktopWidth, 61, 252, 50, 21)
	GUICtrlCreateLabel("Bottom:", 121, 255, 40, 20)
	$g_idInputBottom = GUICtrlCreateInput(@DesktopHeight, 156, 252, 30, 21)
	$g_idBtnSelectArea = GUICtrlCreateButton("Select Area", 24, 276, 163, 25)
	; --- Actions on Found ---
	GUICtrlCreateGroup("Actions on Found", 214, 134, 174, 146)
	$g_idChkMoveMouse = GUICtrlCreateCheckbox("Move Mouse", 224, 154, 100, 20)
	GUICtrlSetState(-1, $GUI_CHECKED)
	GUICtrlCreateLabel("Click:", 224, 179, 40, 20)
	$g_idRadNoClick = GUICtrlCreateRadio("None", 264, 179, 55, 20)
	GUICtrlSetState(-1, $GUI_CHECKED)
	$g_idRadSingleClick = GUICtrlCreateRadio("Single", 224, 199, 60, 20)
	$g_idRadDoubleClick = GUICtrlCreateRadio("Double", 284, 199, 65, 20)

	; --- RIGHT COLUMN: IMAGES & INFO ---
	GUICtrlCreateGroup("Image Targets", 410, 6, 486, 464)
	Local $iPicWidth = 100, $iPicHeight = 100
	Local $iX_Start = 425, $iY_Start = 38
	Local $iX = $iX_Start, $iY = $iY_Start
	Local $iColWidth = 118
	For $i = 0 To $MAX_IMAGES - 1
		If $i > 0 And Mod($i, 4) = 0 Then ; New row
			$iX = $iX_Start
			$iY += 144
		EndIf
		$g_aidChkSearch[$i] = GUICtrlCreateCheckbox(String($i + 1), $iX, $iY, 34, 20)
		$g_aidBtnCreate[$i] = GUICtrlCreateButton("Create", $iX + 37, $iY, 59, 22)
		$g_aidPic[$i] = GUICtrlCreatePic("", $iX, $iY + 30, $iPicWidth, $iPicHeight, $SS_CENTERIMAGE)
		$iX += $iColWidth
	Next

	; --- BOTTOM: LOGS & SYSTEM INFO ---
	GUICtrlCreateGroup("Activity Log", 13, 472, 880, 142)
	$g_hLog = GUICtrlCreateEdit("", 18, 487, 862, 114, BitOR($ES_MULTILINE, $ES_READONLY, $WS_VSCROLL, $ES_AUTOVSCROLL))
	GUICtrlSetFont(-1, 9, 400, 0, "Consolas")

	GUICtrlCreateGroup("System Information", 12, 363, 392, 104)
	GUICtrlCreateLabel("OS: " & @OSVersion & " (" & @OSArch & ")" & "   |   AutoIt: " & @AutoItVersion & (@AutoItX64 ? " (x64)" : ""), 28, 385, 360, 20)
	GUICtrlCreateLabel("DLL In Use:" & " v" & $__IMAGESEARCH_UDF_VERSION, 28, 410, 360, 20)
	GUICtrlCreateInput($g_sImageSearchDLL_Path, 23, 437, 360, 21, $ES_READONLY)

	; --- MAIN ACTION BUTTONS ---
	$g_idBtnStart = GUICtrlCreateButton("Start Search", 9, 318, 264, 40, $BS_DEFPUSHBUTTON)
	GUICtrlSetFont(-1, 14, 700)
	$g_idBtnSelectAll = GUICtrlCreateButton("Select All", 295, 318, 105, 22)
	$g_idBtnDeselectAll = GUICtrlCreateButton("Deselect All", 295, 345, 105, 22)

	; --- STATUS BAR ---
	$g_hStatusBar = _GUICtrlStatusBar_Create($g_hMainGUI)
	_UpdateStatus("Ready")

	GUISetState(@SW_SHOW)
EndFunc   ;==>_CreateGUI


; === CORE LOGIC FUNCTIONS ===

; #FUNCTION# ====================================================================================================================
; Name...........: _StartSearch
; Description....: Gathers all settings from the GUI, validates them, and initiates the appropriate search function.
; ===============================================================================================================================
Func _StartSearch()
	GUICtrlSetData($g_hLog, "")
	_UpdateStatus("Starting search...")

	; --- Read and Validate GUI inputs ---
	Local $iDelay = Number(GUICtrlRead($g_idInputDelay))
	Local $bMoveMouse = (GUICtrlRead($g_idChkMoveMouse) = $GUI_CHECKED)
	Local $iClickType = 0 ; 0 = None, 1 = Single, 2 = Double
	If GUICtrlRead($g_idRadSingleClick) = $GUI_CHECKED Then $iClickType = 1
	If GUICtrlRead($g_idRadDoubleClick) = $GUI_CHECKED Then $iClickType = 2
	Local $bWaitSearch = (GUICtrlRead($g_idChkWait) = $GUI_CHECKED)
	Local $iWaitTime = Number(GUICtrlRead($g_idInputWaitTime))
	Local $bMultiSearch = (GUICtrlRead($g_idChkMultiSearch) = $GUI_CHECKED)
	Local $iFindAll = (GUICtrlRead($g_idChkFindAll) = $GUI_CHECKED ? 1 : 0)
	Local $iTolerance = Number(GUICtrlRead($g_idInputTolerance))
	Local $iDebugMode = (GUICtrlRead($g_idChkEnableDebug) = $GUI_CHECKED ? 1 : 0)


	; --- Determine Search Area ---
	Local $iLeft, $iTop, $iRight, $iBottom
	If GUICtrlRead($g_idChkUseArea) = $GUI_CHECKED Then
		$iLeft = GUICtrlRead($g_idInputLeft)
		$iTop = GUICtrlRead($g_idInputTop)
		$iRight = GUICtrlRead($g_idInputRight)
		$iBottom = GUICtrlRead($g_idInputBottom)
	Else
		$iLeft = 0
		$iTop = 0
		$iRight = @DesktopWidth
		$iBottom = @DesktopHeight
	EndIf

	; --- Get list of images to search for, validating existence ---
	Local $aSearchList[1] = [0]
	For $i = 0 To $MAX_IMAGES - 1
		If GUICtrlRead($g_aidChkSearch[$i]) = $GUI_CHECKED Then
			If Not FileExists($g_asImagePaths[$i]) Then
				_LogWrite("WARN: Image " & $i + 1 & " not found. Unchecking and skipping.")
				GUICtrlSetState($g_aidChkSearch[$i], $GUI_UNCHECKED)
				_UpdateSingleImagePreview($i)
				ContinueLoop
			EndIf
			_ArrayAdd($aSearchList, $g_asImagePaths[$i])
			$aSearchList[0] += 1
		EndIf
	Next

	If $aSearchList[0] = 0 Then
		_LogWrite("ERROR: No valid images selected for search.")
		_UpdateStatus("Error: No valid images selected. Ready.")
		Return
	EndIf

	_LogWrite("====================================")
	_LogWrite("Starting search for " & $aSearchList[0] & " image(s)...")

	If $bMultiSearch Then
		_SearchMultipleImages($aSearchList, $bWaitSearch, $iWaitTime, $iLeft, $iTop, $iRight, $iBottom, $iTolerance, $iDebugMode, $iFindAll, $bMoveMouse, $iClickType, $iDelay)
	Else
		_SearchSingleImages($aSearchList, $bWaitSearch, $iWaitTime, $iLeft, $iTop, $iRight, $iBottom, $iTolerance, $iDebugMode, $iFindAll, $bMoveMouse, $iClickType, $iDelay)
	EndIf

	_LogWrite("====================================" & @CRLF)
	_UpdateStatus("Search complete. Ready.")
EndFunc   ;==>_StartSearch

; #FUNCTION# ====================================================================================================================
; Name...........: __ExecuteSearch
; Description....: A centralized wrapper function to call the appropriate UDF search function.
; Parameters.....: $sImagePath - The path(s) to the image(s) to search for.
;                  ... All other search parameters.
; Return values..: The 2D array result from the UDF.
; ===============================================================================================================================
Func __ExecuteSearch($sImagePath, $bWait, $iWaitTime, $iLeft, $iTop, $iRight, $iBottom, $iTolerance, $iDebug, $iFindAll)
	Local $iMaxResults = ($iFindAll = 1 ? 99 : 1)
	If $bWait Then
		Return _ImageSearch_WaitArea($iWaitTime, $sImagePath, $iLeft, $iTop, $iRight, $iBottom, $iTolerance, -1, $iMaxResults, 1, $iDebug, 1.0, 1.0, 0.1, $iFindAll)
	Else
		Return _ImageSearch_Area($sImagePath, $iLeft, $iTop, $iRight, $iBottom, $iTolerance, -1, $iMaxResults, 1, $iDebug, 1.0, 1.0, 0.1, $iFindAll)
	EndIf
EndFunc   ;==>__ExecuteSearch

; #FUNCTION# ====================================================================================================================
; Name...........: _SearchMultipleImages
; Description....: Performs a search for all selected images at once.
; Parameters.....: $aImageList - Array of image paths to search for.
;                  ... and other search and action parameters.
; ===============================================================================================================================
Func _SearchMultipleImages($aImageList, $bWait, $iWaitTime, $iLeft, $iTop, $iRight, $iBottom, $iTolerance, $iDebug, $iFindAll, $bMove, $iClickType, $iDelay)
	_UpdateStatus("Mode: Multi Search (All at once)...")
	_LogWrite("Mode: Multi Search (All at once)")
	_LogWrite("Find All Occurrences: " & ($iFindAll = 1 ? "Enabled" : "Disabled"))
	Local $sImageListStr = _ArrayToString($aImageList, "|", 1)

	Local $aResult = __ExecuteSearch($sImageListStr, $bWait, $iWaitTime, $iLeft, $iTop, $iRight, $iBottom, $iTolerance, $iDebug, $iFindAll)

	If $iDebug = 1 Then _LogWrite("DLL Return: " & $g_sLastDllReturn)
	If $g_bImageSearch_Debug Then _LogWrite("DEBUG: UDF returned an array. Checking aResult[0][0] = " & $aResult[0][0])

	If $aResult[0][0] > 0 Then
		_ProcessMultiResults($aResult, $bMove, $iClickType, $iDelay)
	Else
		_LogSearchError($aResult[0][0])
	EndIf
EndFunc   ;==>_SearchMultipleImages


; #FUNCTION# ====================================================================================================================
; Name...........: _SearchSingleImages
; Description....: Performs a search for each selected image individually, one by one.
; Parameters.....: $aImageList - Array of image paths to search for.
;                  ... and other search and action parameters.
; ===============================================================================================================================
Func _SearchSingleImages($aImageList, $bWait, $iWaitTime, $iLeft, $iTop, $iRight, $iBottom, $iTolerance, $iDebug, $iFindAll, $bMove, $iClickType, $iDelay)
	_LogWrite("Mode: Single Search (One by one)")
	_LogWrite("Find All Occurrences: " & ($iFindAll = 1 ? "Enabled" : "Disabled"))
	Local $iTotalFound = 0

	For $i = 1 To $aImageList[0]
		Local $sCurrentImage = $aImageList[$i]
		Local $sImageName = StringRegExpReplace($sCurrentImage, ".+\\(.+)", "$1")
		_UpdateStatus("Searching for: " & $sImageName & "...")
		_LogWrite(" -> Searching for: " & $sImageName)

		Local $aResult = __ExecuteSearch($sCurrentImage, $bWait, $iWaitTime, $iLeft, $iTop, $iRight, $iBottom, $iTolerance, $iDebug, $iFindAll)

		If $iDebug = 1 Then _LogWrite("DLL Return: " & $g_sLastDllReturn)
		If $g_bImageSearch_Debug Then _LogWrite("DEBUG: UDF returned an array. Checking aResult[0][0] = " & $aResult[0][0])

		If $aResult[0][0] > 0 Then
			$iTotalFound += $aResult[0][0]
			_ProcessMultiResults($aResult, $bMove, $iClickType, $iDelay)
		Else
			_LogSearchError($aResult[0][0])
		EndIf
	Next
	_LogWrite("Single search finished. Total matches found: " & $iTotalFound)
EndFunc   ;==>_SearchSingleImages

; #FUNCTION# ====================================================================================================================
; Name...........: _ProcessMultiResults
; Description....: Processes the 2D array result from a search and performs actions for each found item.
; Parameters.....: $aResult    - The 2D result array from the UDF.
;                  $bMove      - Boolean, whether to move the mouse.
;                  $iClickType - 0 for none, 1 for single, 2 for double click.
;                  $iDelay     - Delay in ms after actions.
; ===============================================================================================================================
Func _ProcessMultiResults($aResult, $bMove, $iClickType, $iDelay)
	Local $iFoundCount = $aResult[0][0]
	_LogWrite("Success: Found " & $iFoundCount & " match(es). Performing actions...")
	For $i = 1 To $iFoundCount
		Local $iX = $aResult[$i][1], $iY = $aResult[$i][2], $iW = $aResult[$i][3], $iH = $aResult[$i][4]
		_UpdateStatus("Performing action on match #" & $i & " at " & $iX & "," & $iY & "...")
		_LogWrite("  -> Found match #" & $i & " at X=" & $iX & ", Y=" & $iY)
		_HighlightFoundArea($iX, $iY, $iW, $iH, 0xFF00FF00)
		_PerformActions($iX, $iY, $bMove, $iClickType, $iDelay)
	Next
	_LogWrite("All actions complete for this search cycle.")
EndFunc   ;==>_ProcessMultiResults

; #FUNCTION# ====================================================================================================================
; Name...........: _PerformActions
; Description....: Executes the user-defined actions (move, click, delay) at a given coordinate.
; Parameters.....: $iX, $iY    - The coordinates to perform actions at.
;                  ... and other action parameters.
; ===============================================================================================================================
Func _PerformActions($iX, $iY, $bMove, $iClickType, $iDelay)
	If $bMove Then
		_LogWrite("     - Moving mouse...")
		MouseMove($iX, $iY, 10)
	EndIf
	If $iClickType > 0 Then
		_LogWrite("     - Performing " & ($iClickType = 1 ? "single" : "double") & " click...")
		MouseClick("left", $iX, $iY, $iClickType, 0)
	EndIf
	_LogWrite("     - Delaying for " & $iDelay & "ms...")
	Sleep($iDelay)
EndFunc   ;==>_PerformActions


; === HELPER AND UTILITY FUNCTIONS ===

; #FUNCTION# ====================================================================================================================
; Name...........: _HandleImageCreation
; Description....: Event handler that determines which "Create" button was pressed and calls the creation function.
; Parameters.....: $nMsg - The control ID of the pressed button.
; ===============================================================================================================================
Func _HandleImageCreation($nMsg)
	For $i = 0 To $MAX_IMAGES - 1
		If $nMsg = $g_aidBtnCreate[$i] Then
			_CreateImageFile($g_asImagePaths[$i], "Create/Update Image " & $i + 1, $i)
			Return
		EndIf
	Next
EndFunc   ;==>_HandleImageCreation

; #FUNCTION# ====================================================================================================================
; Name...........: _CreateImageFile
; Description....: Manages the process of calling the screen capture function and updating the log/GUI.
; Parameters.....: $sFilePath - The path to save the image file.
;                  $sTitle    - The title for the capture window.
;                  $iIndex    - The index of the image slot being updated.
; ===============================================================================================================================
Func _CreateImageFile($sFilePath, $sTitle, $iIndex)
	_UpdateStatus("Preparing to create image " & $iIndex + 1 & "...")
	Local $iResult = _CaptureRegion($sTitle, $sFilePath)
	If $iResult = -1 Then
		_LogWrite("ERROR: Could not capture screen.")
	ElseIf $iResult = -2 Then
		_LogWrite("CANCELLED: User cancelled image creation for " & $sFilePath)
	Else
		_LogWrite("Image saved successfully: " & $sFilePath)
		_UpdateSingleImagePreview($iIndex)
	EndIf
	_UpdateStatus("Ready")
EndFunc   ;==>_CreateImageFile

; #FUNCTION# ====================================================================================================================
; Name...........: _SelectAreaOnScreen
; Description....: Manages the process of selecting a screen area and updating the GUI input fields.
; ===============================================================================================================================
Func _SelectAreaOnScreen()
	_UpdateStatus("Preparing to select search area...")
	Local $aCoords = _CaptureRegion("Select an area and release the mouse", "")
	If Not IsArray($aCoords) Then
		_LogWrite("INFO: Area selection cancelled.")
	Else
		GUICtrlSetData($g_idInputLeft, $aCoords[0])
		GUICtrlSetData($g_idInputTop, $aCoords[1])
		GUICtrlSetData($g_idInputRight, $aCoords[2])
		GUICtrlSetData($g_idInputBottom, $aCoords[3])
		_LogWrite("INFO: Search area updated to L:" & $aCoords[0] & " T:" & $aCoords[1] & " R:" & $aCoords[2] & " B:" & $aCoords[3])
	EndIf
	_UpdateStatus("Ready")
EndFunc   ;==>_SelectAreaOnScreen


; #FUNCTION# ====================================================================================================================
; Name...........: _CaptureRegion
; Description....: Creates a transparent GUI to allow the user to select a screen region by dragging the mouse.
;                  MODIFIED: Selection area is now always a square.
; Parameters.....: $sTitle    - The title for the capture window.
;                  $sFilePath - If provided, captures and saves an image. If empty, returns coordinates.
; Return values..: If $sFilePath is provided: 0 on success, -1 on capture error, -2 on user cancel.
;                  If $sFilePath is empty: A 4-element array [Left, Top, Right, Bottom] on success, -2 on user cancel.
; ===============================================================================================================================
Func _CaptureRegion($sTitle, $sFilePath)
	Local $hUserDLL = DllOpen("user32.dll")
	If $hUserDLL = -1 Then Return -1
	Local $hCrossGUI = GUICreate($sTitle, @DesktopWidth, @DesktopHeight, 0, 0, $WS_POPUP, $WS_EX_TOPMOST)
	GUISetBkColor(0x000001)
	WinSetTrans($hCrossGUI, "", 1)
	GUISetState(@SW_SHOW, $hCrossGUI)
	GUISetCursor(3, 1, $hCrossGUI)
	_UpdateStatus("Drag the mouse to select a square area. Press ESC to cancel.")
	ToolTip("Drag the mouse to select a square area. Press ESC to cancel.", 0, 0)
	While Not _IsPressed("01", $hUserDLL)
		If _IsPressed("1B", $hUserDLL) Then
			ToolTip("")
			GUIDelete($hCrossGUI)
			DllClose($hUserDLL)
			Return -2
		EndIf
		Sleep(20)
	WEnd
	ToolTip("")
	Local $aStartPos = MouseGetPos()
	Local $iX1 = $aStartPos[0], $iY1 = $aStartPos[1]
	Local $hRectGUI
	While _IsPressed("01", $hUserDLL)
		Local $aCurrentPos = MouseGetPos()
		Local $iX2 = $aCurrentPos[0], $iY2 = $aCurrentPos[1]
		If IsHWnd($hRectGUI) Then GUIDelete($hRectGUI)

		; Calculate the absolute width and height of the drag area
		Local $iAbsWidth = Abs($iX1 - $iX2)
		Local $iAbsHeight = Abs($iY1 - $iY2)

		; Determine the side length of the square (the larger of width or height)
		Local $iSide = _Max($iAbsWidth, $iAbsHeight)

		; Determine the top-left corner of the square based on drag direction
		Local $iLeft_Temp = $iX1
		If $iX2 < $iX1 Then $iLeft_Temp = $iX1 - $iSide

		Local $iTop_Temp = $iY1
		If $iY2 < $iY1 Then $iTop_Temp = $iY1 - $iSide

		; Create the square feedback GUI
		$hRectGUI = GUICreate("", $iSide, $iSide, $iLeft_Temp, $iTop_Temp, $WS_POPUP, BitOR($WS_EX_LAYERED, $WS_EX_TOPMOST))
		GUISetBkColor(0xFF0000)
		_WinAPI_SetLayeredWindowAttributes($hRectGUI, 0, 100)
		GUISetState(@SW_SHOWNOACTIVATE, $hRectGUI)
		Sleep(10)
	WEnd
	Local $aEndPos = MouseGetPos()
	Local $iX2 = $aEndPos[0], $iY2 = $aEndPos[1]
	GUIDelete($hCrossGUI)
	If IsHWnd($hRectGUI) Then GUIDelete($hRectGUI)
	DllClose($hUserDLL)

	; Final coordinate calculation for the square
	Local $iAbsWidth = Abs($iX1 - $iX2)
	Local $iAbsHeight = Abs($iY1 - $iY2)
	Local $iSide = _Max($iAbsWidth, $iAbsHeight)
	If $iSide = 0 Then Return -2 ; If there was no drag, treat as cancel

	Local $iLeft = $iX1
	If $iX2 < $iX1 Then $iLeft = $iX1 - $iSide

	Local $iTop = $iY1
	If $iY2 < $iY1 Then $iTop = $iY1 - $iSide

	Local $iRight = $iLeft + $iSide
	Local $iBottom = $iTop + $iSide

	; If $sFilePath is empty, it's an area selection, not an image capture
	If $sFilePath = "" Then
		Local $aReturn[4] = [$iLeft, $iTop, $iRight, $iBottom]
		Return $aReturn
	EndIf

	Local $aMousePos = MouseGetPos()
	MouseMove(0, 0, 0)
	Sleep(250)
	Local $hBitmap = _ScreenCapture_Capture("", $iLeft, $iTop, $iRight, $iBottom, False)
	If @error Then
		MouseMove($aMousePos[0], $aMousePos[1], 0)
		Return -1
	EndIf
	Local $hImage = _GDIPlus_BitmapCreateFromHBITMAP($hBitmap)
	_GDIPlus_ImageSaveToFile($hImage, $sFilePath)
	_GDIPlus_BitmapDispose($hImage)
	_WinAPI_DeleteObject($hBitmap)
	MouseMove($aMousePos[0], $aMousePos[1], 0)
	Return 0
EndFunc   ;==>_CaptureRegion
; #FUNCTION# ====================================================================================================================
; Name...........: _CaptureRegion
; Description....: Creates a transparent GUI to allow the user to select a screen region by dragging the mouse.
; Parameters.....: $sTitle    - The title for the capture window.
;                  $sFilePath - If provided, captures and saves an image. If empty, returns coordinates.
; Return values..: If $sFilePath is provided: 0 on success, -1 on capture error, -2 on user cancel.
;                  If $sFilePath is empty: A 4-element array [Left, Top, Right, Bottom] on success, -2 on user cancel.
; ===============================================================================================================================
Func _CaptureRegion_free($sTitle, $sFilePath)
	Local $hUserDLL = DllOpen("user32.dll")
	If $hUserDLL = -1 Then Return -1
	Local $hCrossGUI = GUICreate($sTitle, @DesktopWidth, @DesktopHeight, 0, 0, $WS_POPUP, $WS_EX_TOPMOST)
	GUISetBkColor(0x000001)
	WinSetTrans($hCrossGUI, "", 1)
	GUISetState(@SW_SHOW, $hCrossGUI)
	GUISetCursor(3, 1, $hCrossGUI)
	_UpdateStatus("Drag the mouse to select an area. Press ESC to cancel.")
	ToolTip("Drag the mouse to select an area. Press ESC to cancel.", 0, 0)
	While Not _IsPressed("01", $hUserDLL)
		If _IsPressed("1B", $hUserDLL) Then
			ToolTip("")
			GUIDelete($hCrossGUI)
			DllClose($hUserDLL)
			Return -2
		EndIf
		Sleep(20)
	WEnd
	ToolTip("")
	Local $aStartPos = MouseGetPos()
	Local $iX1 = $aStartPos[0], $iY1 = $aStartPos[1]
	Local $hRectGUI
	While _IsPressed("01", $hUserDLL)
		Local $aCurrentPos = MouseGetPos()
		Local $iX2 = $aCurrentPos[0], $iY2 = $aCurrentPos[1]
		If IsHWnd($hRectGUI) Then GUIDelete($hRectGUI)
		Local $iLeft = ($iX1 < $iX2 ? $iX1 : $iX2)
		Local $iTop = ($iY1 < $iY2 ? $iY1 : $iY2)
		Local $iWidth = Abs($iX1 - $iX2)
		Local $iHeight = Abs($iY1 - $iY2)
		$hRectGUI = GUICreate("", $iWidth, $iHeight, $iLeft, $iTop, $WS_POPUP, BitOR($WS_EX_LAYERED, $WS_EX_TOPMOST))
		GUISetBkColor(0xFF0000)
		_WinAPI_SetLayeredWindowAttributes($hRectGUI, 0, 100)
		GUISetState(@SW_SHOWNOACTIVATE, $hRectGUI)
		Sleep(10)
	WEnd
	Local $aEndPos = MouseGetPos()
	Local $iX2 = $aEndPos[0], $iY2 = $aEndPos[1]
	GUIDelete($hCrossGUI)
	If IsHWnd($hRectGUI) Then GUIDelete($hRectGUI)
	DllClose($hUserDLL)
	Local $iLeft = ($iX1 < $iX2 ? $iX1 : $iX2)
	Local $iTop = ($iY1 < $iY2 ? $iY1 : $iY2)
	Local $iRight = ($iX1 > $iX2 ? $iX1 : $iX2)
	Local $iBottom = ($iY1 > $iY2 ? $iY1 : $iY2)

	; If $sFilePath is empty, it's an area selection, not an image capture
	If $sFilePath = "" Then
		Local $aReturn[4] = [$iLeft, $iTop, $iRight, $iBottom]
		Return $aReturn
	EndIf

	Local $aMousePos = MouseGetPos()
	MouseMove(0, 0, 0)
	Sleep(250)
	Local $hBitmap = _ScreenCapture_Capture("", $iLeft, $iTop, $iRight, $iBottom, False)
	If @error Then
		MouseMove($aMousePos[0], $aMousePos[1], 0)
		Return -1
	EndIf
	Local $hImage = _GDIPlus_BitmapCreateFromHBITMAP($hBitmap)
	_GDIPlus_ImageSaveToFile($hImage, $sFilePath)
	_GDIPlus_BitmapDispose($hImage)
	_WinAPI_DeleteObject($hBitmap)
	MouseMove($aMousePos[0], $aMousePos[1], 0)
	Return 0
EndFunc   ;==>_CaptureRegion

; #FUNCTION# ====================================================================================================================
; Name...........: _HighlightFoundArea
; Description....: Creates a temporary, semi-transparent GUI to highlight a found image location.
; Parameters.....: $iX, $iY    - The center coordinates of the area to highlight.
;                  $iWidth     - The width of the highlight rectangle.
;                  $iHeight    - The height of the highlight rectangle.
;                  $iColor     - [optional] The color of the highlight rectangle.
; ===============================================================================================================================
Func _HighlightFoundArea($iX, $iY, $iWidth, $iHeight, $iColor = 0xFFFF0000)
	Local $hGUI = GUICreate("", $iWidth, $iHeight, $iX - $iWidth / 2, $iY - $iHeight / 2, $WS_POPUP, BitOR($WS_EX_LAYERED, $WS_EX_TOPMOST, $WS_EX_TOOLWINDOW))
	GUISetBkColor($iColor)
	_WinAPI_SetLayeredWindowAttributes($hGUI, 0, 128)
	GUISetState(@SW_SHOWNOACTIVATE)
	Sleep(500)
	GUIDelete($hGUI)
EndFunc   ;==>_HighlightFoundArea

; #FUNCTION# ====================================================================================================================
; Name...........: _LogWrite
; Description....: Writes a timestamped message to the activity log and ensures it scrolls to the bottom.
; Parameters.....: $sMessage - The string message to log.
; ===============================================================================================================================
Func _LogWrite($sMessage)
	GUICtrlSetData($g_hLog, _NowTime() & " " & $sMessage & @CRLF, 1)
	_GUICtrlEdit_SetSel(GUICtrlGetHandle($g_hLog), 0x7FFFFFFF, 0x7FFFFFFF)
EndFunc   ;==>_LogWrite

; #FUNCTION# ====================================================================================================================
; Name...........: _LogSearchError
; Description....: Translates an error code from the UDF into a human-readable message and logs it.
; Parameters.....: $iErrorCode - The status code returned by the _ImageSearch* function.
; ===============================================================================================================================
Func _LogSearchError($iErrorCode)
	Switch $iErrorCode
		Case 0
			_LogWrite("    - Not found.")
		Case -1
			_LogWrite("ERROR: DllCall failed. Check if the DLL is corrupted or blocked by antivirus.")
		Case -2
			_LogWrite("ERROR: Invalid format returned from DLL. The UDF could not parse the result.")
		Case -3
			_LogWrite("ERROR: Invalid content returned from DLL. The result string was malformed.")
		Case -11
			_LogWrite("ERROR: The source image file was not found on disk (checked by UDF).")
		Case -12
			_LogWrite("ERROR: Failed to deploy or load the ImageSearch DLL. Call _ImageSearch_Startup().")
		Case Else
			_LogWrite("ERROR: An internal DLL error occurred. Code: " & $iErrorCode)
	EndSwitch
EndFunc   ;==>_LogSearchError

; #FUNCTION# ====================================================================================================================
; Name...........: _UpdateAllImagePreviews
; Description....: Iterates through all image slots and updates their preview images.
; ===============================================================================================================================
Func _UpdateAllImagePreviews()
	For $i = 0 To $MAX_IMAGES - 1
		_UpdateSingleImagePreview($i)
	Next
EndFunc   ;==>_UpdateAllImagePreviews

; #FUNCTION# ====================================================================================================================
; Name...........: _UpdateSingleImagePreview
; Description....: Updates a single image preview slot. Shows the placeholder if the image doesn't exist.
; Parameters.....: $iIndex - The index of the image slot to update.
; ===============================================================================================================================
Func _UpdateSingleImagePreview($iIndex)
	If FileExists($g_asImagePaths[$iIndex]) Then
		GUICtrlSetImage($g_aidPic[$iIndex], $g_asImagePaths[$iIndex])
	Else
		If FileExists($g_sPlaceholderPath) Then
			GUICtrlSetImage($g_aidPic[$iIndex], $g_sPlaceholderPath)
		Else
			GUICtrlSetImage($g_aidPic[$iIndex], "shell32.dll", 22)
		EndIf
	EndIf
EndFunc   ;==>_UpdateSingleImagePreview

; #FUNCTION# ====================================================================================================================
; Name...........: _SelectAll
; Description....: Checks or unchecks all image target checkboxes.
; Parameters.....: $bState - True to check all, False to uncheck all.
; ===============================================================================================================================
Func _SelectAll($bState)
	Local $iCheckState = $GUI_UNCHECKED
	If $bState Then $iCheckState = $GUI_CHECKED

	For $i = 0 To $MAX_IMAGES - 1
		GUICtrlSetState($g_aidChkSearch[$i], $iCheckState)
	Next
EndFunc   ;==>_SelectAll

; #FUNCTION# ====================================================================================================================
; Name...........: _UpdateStatus
; Description....: Sets the text of the status bar.
; Parameters.....: $sMessage - The message to display.
; ===============================================================================================================================
Func _UpdateStatus($sMessage)
	_GUICtrlStatusBar_SetText($g_hStatusBar, $sMessage)
EndFunc   ;==>_UpdateStatus

; #FUNCTION# ====================================================================================================================
; Name...........: _Exit
; Description....: Exits the script cleanly. This will trigger the OnAutoItExitRegister function.
; ===============================================================================================================================
Func _Exit()
	_GDIPlus_Shutdown()
	Exit
EndFunc   ;==>_Exit

; Dao Van Trong - TRONG.PRO