; =================================================================================================
; Title .........: AutoIt Embedded File Generator
; Author(s) .....: Dao Van Trong - TRONG.PRO
; Version .......: 2.5 (Fixed syntax and delimiter logic in generated code)
; Description ...: A professional tool to convert binary files into self-contained AutoIt hex functions.
;                  Features architecture detection, GUI and CLI modes, and robust code generation.
; =================================================================================================

#Region ; *** INCLUDES ***
;~ #include <GUIConstantsEx.au3>
;~ #include <StaticConstants.au3>
;~ #include <WindowsConstants.au3>
;~ #include <Clipboard.au3>
;~ #include <File.au3>
;~ #include <Array.au3>
;~ #include <ListViewConstants.au3>
#EndRegion ; *** INCLUDES ***

#Region ; *** GLOBAL VARIABLES ***
Global Const $GUI_EVENT_CLOSE = -3, $GUI_CHECKED = 1, $WS_HSCROLL = 0x00100000, $WS_VSCROLL = 0x00200000, $GMEM_MOVEABLE = 0x0002, $GMEM_ZEROINIT = 0x0040, $GHND = BitOR($GMEM_MOVEABLE, $GMEM_ZEROINIT), $STR_ENTIRESPLIT = 1, $STR_NOCOUNT = 2, $STR_REGEXPARRAYMATCH = 1, $CF_TEXT = 1, $CF_OEMTEXT = 7, $CF_UNICODETEXT = 13, $UBOUND_DIMENSIONS = 0, $UBOUND_ROWS = 1, $UBOUND_COLUMNS = 2, $FILE_BEGIN = 0, $PATH_ORIGINAL = 0, $PATH_DRIVE = 1, $PATH_DIRECTORY = 2, $PATH_FILENAME = 3, $PATH_EXTENSION = 4, $LVM_FIRST = 0x1000
Global Const $LVM_DELETEALLITEMS = ($LVM_FIRST + 9), $LVM_DELETEITEM = ($LVM_FIRST + 8), $LVM_GETNEXTITEM = ($LVM_FIRST + 12), $LVM_SETCOLUMNWIDTH = ($LVM_FIRST + 30), $LVNI_SELECTED = 0x0002
Global Enum $ARRAYFILL_FORCE_DEFAULT, $ARRAYFILL_FORCE_SINGLEITEM, $ARRAYFILL_FORCE_INT, $ARRAYFILL_FORCE_NUMBER, $ARRAYFILL_FORCE_PTR, $ARRAYFILL_FORCE_HWND, $ARRAYFILL_FORCE_STRING, $ARRAYFILL_FORCE_BOOLEAN

; Global variables for GUI controls
Global $g_hGUI, $g_hListView, $g_hEditOutput, $g_hInputChunkSize
Global $g_hBtnAddFiles, $g_hBtnRemoveSelected, $g_hBtnClearAll, $g_hCheckAddHelpers, $g_hBtnGenerate, $g_hBtnPreview, $g_hBtnCopy, $g_hBtnSaveAll, $g_hBtnSaveSeparate, $g_hBtnExit

; Global 2D array to store file information.
; Index [x][0]: Full Path
; Index [x][1]: File Name
; Index [x][2]: Formatted File Size
; Index [x][3]: Architecture
; Index [x][4]: Generated Function Name
Global $g_aSelectedFiles[0][5]
#EndRegion ; *** GLOBAL VARIABLES ***

#Region ; *** SCRIPT ENTRY POINT ***
; Check if command-line arguments were provided to determine execution mode.
If $CmdLine[0] > 0 Then
	_RunCommandLineMode()
Else
	_RunGuiMode()
EndIf
#EndRegion ; *** SCRIPT ENTRY POINT ***

#Region ; *** GUI MODE FUNCTIONS ***

; -------------------------------------------------------------------------------------------------
; Function:      _RunGuiMode()
; Purpose:       Creates and manages the main Graphical User Interface (GUI).
; -------------------------------------------------------------------------------------------------
Func _RunGuiMode()
	$g_hGUI = GUICreate("AutoIt Embedded File Generator by Dao Van Trong - TRONG.PRO", 800, 650)
	GUISetBkColor(0xF0F0F0)
	_CreateGUI_Controls()
	GUISetState(@SW_SHOW, $g_hGUI)

	Local $nMsg
	While 1
		$nMsg = GUIGetMsg()
		Switch $nMsg
			Case $GUI_EVENT_CLOSE, $g_hBtnExit
				ExitLoop
			Case $g_hBtnAddFiles
				_GUI_HandleAddFiles()
			Case $g_hBtnRemoveSelected
				_GUI_HandleRemoveSelected()
			Case $g_hBtnClearAll
				_GUI_HandleClearAll()
			Case $g_hBtnGenerate
				_GUI_HandleGenerateAll()
			Case $g_hBtnPreview
				_GUI_HandlePreviewSingle()
			Case $g_hBtnCopy
				_GUI_HandleCopyToClipboard()
			Case $g_hBtnSaveAll
				_GUI_HandleSaveAll()
			Case $g_hBtnSaveSeparate
				_GUI_HandleSaveSeparate()
		EndSwitch
	WEnd
	GUIDelete($g_hGUI)
EndFunc   ;==>_RunGuiMode

; -------------------------------------------------------------------------------------------------
; Function:      _CreateGUI_Controls()
; Purpose:       Creates all controls for the main GUI window.
; -------------------------------------------------------------------------------------------------
Func _CreateGUI_Controls()
	GUICtrlCreateLabel("1. File Selection:", 10, 15, 150, 20)
	GUICtrlSetFont(-1, 9, 600)
	$g_hBtnAddFiles = GUICtrlCreateButton("Add Files...", 10, 35, 100, 25)
	$g_hBtnRemoveSelected = GUICtrlCreateButton("Remove Selected", 120, 35, 120, 25)
	$g_hBtnClearAll = GUICtrlCreateButton("Clear All", 250, 35, 80, 25)
	$g_hListView = GUICtrlCreateListView("File Name|Size|Architecture|Function Name", 10, 70, 780, 150)
	GUICtrlSendMsg($g_hListView, $LVM_SETCOLUMNWIDTH, 0, 250)
	GUICtrlSendMsg($g_hListView, $LVM_SETCOLUMNWIDTH, 1, 100)
	GUICtrlSendMsg($g_hListView, $LVM_SETCOLUMNWIDTH, 2, 100)
	GUICtrlSendMsg($g_hListView, $LVM_SETCOLUMNWIDTH, 3, 320)
	GUICtrlCreateLabel("2. Generation Options:", 10, 235, 150, 20)
	GUICtrlSetFont(-1, 9, 600)
	GUICtrlCreateLabel("Line Length (chars):", 20, 260, 120, 20)
	$g_hInputChunkSize = GUICtrlCreateInput("4000", 150, 257, 100, 22)
	$g_hCheckAddHelpers = GUICtrlCreateCheckbox("Include helper functions", 270, 257, 150, 22)
	GUICtrlSetState($g_hCheckAddHelpers, $GUI_CHECKED)
	$g_hBtnGenerate = GUICtrlCreateButton("3. Generate All Functions", 10, 290, 200, 35)
	GUICtrlSetFont(-1, 10, 700)
	GUICtrlSetBkColor($g_hBtnGenerate, 0x90EE90)
	$g_hBtnPreview = GUICtrlCreateButton("Preview Single", 220, 290, 100, 35)
	GUICtrlCreateLabel("Generated Code:", 10, 340, 150, 20)
	GUICtrlSetFont(-1, 9, 600)
	$g_hEditOutput = GUICtrlCreateEdit("", 10, 360, 780, 220, $WS_VSCROLL + $WS_HSCROLL)
	GUICtrlSetFont(-1, 9, 400, 0, "Consolas")
	$g_hBtnCopy = GUICtrlCreateButton("Copy to Clipboard", 10, 590, 130, 30)
	$g_hBtnSaveAll = GUICtrlCreateButton("Save All to File", 150, 590, 130, 30)
	$g_hBtnSaveSeparate = GUICtrlCreateButton("Save Separate Files", 290, 590, 130, 30)
	$g_hBtnExit = GUICtrlCreateButton("Exit", 660, 590, 130, 30)
	GUICtrlSetBkColor($g_hBtnExit, 0xFFB6C1)
EndFunc   ;==>_CreateGUI_Controls

; -------------------------------------------------------------------------------------------------
; Function:      _GUI_HandleAddFiles()
; Purpose:       Opens a file dialog and adds selected files to the list.
; -------------------------------------------------------------------------------------------------
Func _GUI_HandleAddFiles()
	Local $sFiles = FileOpenDialog("Select Files", @ScriptDir, "All Files (*.*)", 4)
	If @error Then Return
	Local $aNewFiles = StringSplit($sFiles, "|")
	If $aNewFiles[0] = 1 Then
		_AddFileToList($aNewFiles[1])
	Else
		Local $sBasePath = $aNewFiles[1]
		For $i = 2 To $aNewFiles[0]
			_AddFileToList($sBasePath & "\" & $aNewFiles[$i])
		Next
	EndIf
EndFunc   ;==>_GUI_HandleAddFiles

; -------------------------------------------------------------------------------------------------
; Function:      _GUI_HandleRemoveSelected()
; Purpose:       Removes the selected file from the list.
; -------------------------------------------------------------------------------------------------
Func _GUI_HandleRemoveSelected()
	Local $iIndex = GUICtrlSendMsg($g_hListView, $LVM_GETNEXTITEM, -1, $LVNI_SELECTED)
	If $iIndex = -1 Then Return
	_ArrayDelete($g_aSelectedFiles, $iIndex)
	GUICtrlSendMsg($g_hListView, $LVM_DELETEITEM, $iIndex, 0)
EndFunc   ;==>_GUI_HandleRemoveSelected

; -------------------------------------------------------------------------------------------------
; Function:      _GUI_HandleClearAll()
; Purpose:       Clears all files from the list and resets the UI.
; -------------------------------------------------------------------------------------------------
Func _GUI_HandleClearAll()
	ReDim $g_aSelectedFiles[0][5]
	GUICtrlSendMsg($g_hListView, $LVM_DELETEALLITEMS, 0, 0)
	GUICtrlSetData($g_hEditOutput, "")
EndFunc   ;==>_GUI_HandleClearAll

; -------------------------------------------------------------------------------------------------
; Function:      _GUI_HandleGenerateAll()
; Purpose:       Generates the complete code for all files in the list.
; -------------------------------------------------------------------------------------------------
Func _GUI_HandleGenerateAll()
	If UBound($g_aSelectedFiles) = 0 Then Return MsgBox(48, "Warning", "Please add at least one file first.")
	GUICtrlSetData($g_hEditOutput, "Generating code, please wait...")
	Sleep(10)
	Local $bAddHelpers = (GUICtrlRead($g_hCheckAddHelpers) = $GUI_CHECKED)
	Local $iChunkSize = _ValidateChunkSize(GUICtrlRead($g_hInputChunkSize))
	Local $sCode = _GenerateCodeBundle($g_aSelectedFiles, $bAddHelpers, $iChunkSize)
	GUICtrlSetData($g_hEditOutput, $sCode)
EndFunc   ;==>_GUI_HandleGenerateAll

; -------------------------------------------------------------------------------------------------
; Function:      _GUI_HandlePreviewSingle()
; Purpose:       Generates code for only the selected file.
; -------------------------------------------------------------------------------------------------
Func _GUI_HandlePreviewSingle()
	Local $iIndex = GUICtrlSendMsg($g_hListView, $LVM_GETNEXTITEM, -1, $LVNI_SELECTED)
	If $iIndex = -1 Then Return MsgBox(48, "Warning", "Please select a file from the list first.")
	GUICtrlSetData($g_hEditOutput, "Generating preview...")
	Sleep(10)
	Local $iChunkSize = _ValidateChunkSize(GUICtrlRead($g_hInputChunkSize))
	Local $sOutput = "; Preview for: " & $g_aSelectedFiles[$iIndex][1] & @CRLF
	$sOutput &= "; Architecture: " & $g_aSelectedFiles[$iIndex][3] & @CRLF & @CRLF
	$sOutput &= _GenerateHexFunction($g_aSelectedFiles[$iIndex][0], $g_aSelectedFiles[$iIndex][4], $g_aSelectedFiles[$iIndex][1], $g_aSelectedFiles[$iIndex][3], "$sHexData", $iChunkSize)
	GUICtrlSetData($g_hEditOutput, $sOutput)
EndFunc   ;==>_GUI_HandlePreviewSingle

; -------------------------------------------------------------------------------------------------
; Function:      _GUI_HandleCopyToClipboard()
; Purpose:       Copies the output text to the clipboard.
; -------------------------------------------------------------------------------------------------
Func _GUI_HandleCopyToClipboard()
	Local $sCode = GUICtrlRead($g_hEditOutput)
	If StringStripWS($sCode, 8) = "" Then Return MsgBox(48, "Warning", "No code to copy. Please generate code first.")
	_ClipBoard_SetData($sCode)
	ToolTip("Code copied to clipboard!", @DesktopWidth / 2, @DesktopHeight / 2, "Success", 1, 1)
	Sleep(1500)
	ToolTip("")
EndFunc   ;==>_GUI_HandleCopyToClipboard

; -------------------------------------------------------------------------------------------------
; Function:      _GUI_HandleSaveAll()
; Purpose:       Saves the generated code for all files into a single .au3 file.
; -------------------------------------------------------------------------------------------------
Func _GUI_HandleSaveAll()
	Local $sCode = GUICtrlRead($g_hEditOutput)
	If StringStripWS($sCode, 8) = "" Then Return MsgBox(48, "Warning", "No code to save. Please generate code first.")
	Local $sSaveFile = FileSaveDialog("Save Combined Code", @ScriptDir, "AutoIt Scripts (*.au3)", 16, "All_Embedded.au3")
	If @error Then Return
	If Not _SaveStringToFile($sSaveFile, $sCode) Then
		MsgBox(16, "Error", "Could not create file: " & $sSaveFile)
	Else
		MsgBox(64, "Success", "All functions saved to: " & @CRLF & $sSaveFile)
	EndIf
EndFunc   ;==>_GUI_HandleSaveAll

; -------------------------------------------------------------------------------------------------
; Function:      _GUI_HandleSaveSeparate()
; Purpose:       Saves the generated code for each file into its own separate .au3 file.
; -------------------------------------------------------------------------------------------------
Func _GUI_HandleSaveSeparate()
	If UBound($g_aSelectedFiles) = 0 Then Return MsgBox(48, "Warning", "No files to process.")
	Local $sSaveDir = FileSelectFolder("Select folder to save separate files", @ScriptDir)
	If @error Then Return
	Local $iChunkSize = _ValidateChunkSize(GUICtrlRead($g_hInputChunkSize))
	Local $bAddHelpers = (GUICtrlRead($g_hCheckAddHelpers) = $GUI_CHECKED)
	Local $iSaved = 0
	For $i = 0 To UBound($g_aSelectedFiles) - 1
		Local $sFilePath = $g_aSelectedFiles[$i][0]
		Local $sFileName = $g_aSelectedFiles[$i][1]
		Local $sArch = $g_aSelectedFiles[$i][3]
		Local $sFuncName = $g_aSelectedFiles[$i][4]
		Local $sDrive, $sDir, $sNameOnly, $sExt
		_PathSplit($sFilePath, $sDrive, $sDir, $sNameOnly, $sExt)
		Local $sSaveFile = $sSaveDir & "\" & $sNameOnly & "_Embedded.au3"
		Local $sCode = "; Generated from: " & $sFileName & @CRLF
		$sCode &= "; Architecture: " & $sArch & @CRLF & @CRLF
		$sCode &= _GenerateHexFunction($sFilePath, $sFuncName, $sFileName, $sArch, "$sHexData", $iChunkSize)
		If $bAddHelpers Then
			$sCode &= _GenerateHelperFunction($sFuncName, $sFileName)
		EndIf
		If _SaveStringToFile($sSaveFile, $sCode) Then $iSaved += 1
	Next
	MsgBox(64, "Success", "Saved " & $iSaved & " of " & UBound($g_aSelectedFiles) & " files to:" & @CRLF & $sSaveDir)
EndFunc   ;==>_GUI_HandleSaveSeparate
#EndRegion ; *** GUI MODE FUNCTIONS ***

#Region ; *** COMMAND-LINE MODE FUNCTIONS ***

; -------------------------------------------------------------------------------------------------
; Function:      _RunCommandLineMode()
; Purpose:       Handles the script's execution when run from the command line.
; -------------------------------------------------------------------------------------------------
Func _RunCommandLineMode()
	Local $aFilePaths[0]
	For $i = 1 To $CmdLine[0]
		If FileExists($CmdLine[$i]) Then
			_ArrayAdd($aFilePaths, $CmdLine[$i])
		Else
			ConsoleWrite("! Warning: File not found - " & $CmdLine[$i] & @CRLF)
		EndIf
	Next
	If UBound($aFilePaths) = 0 Then
		ConsoleWrite("! Error: No valid files provided." & @CRLF & "  Usage: " & @ScriptName & " <file1> [file2] ..." & @CRLF)
		Exit 1
	EndIf
	Local $aFilesData[UBound($aFilePaths)][5]
	For $i = 0 To UBound($aFilePaths) - 1
		_PopulateFileInfo($aFilesData, $i, $aFilePaths[$i])
	Next
	ConsoleWrite("+ Generating code for " & UBound($aFilesData) & " file(s)..." & @CRLF)
	Local $sCode = _GenerateCodeBundle($aFilesData, True, 4000)
	Local $sOutputFile
	If UBound($aFilesData) = 1 Then
		Local $sDrive, $sDir, $sFileName, $sExtension
		_PathSplit($aFilePaths[0], $sDrive, $sDir, $sFileName, $sExtension)
		$sOutputFile = $sDrive & $sDir & $sFileName & "_Embedded.au3"
	Else
		$sOutputFile = @ScriptDir & "\All_Embedded.au3"
	EndIf
	If _SaveStringToFile($sOutputFile, $sCode) Then
		ConsoleWrite("+ Success: Output saved to - " & $sOutputFile & @CRLF)
	Else
		ConsoleWrite("! Error: Could not create output file - " & $sOutputFile & @CRLF)
		Exit 1
	EndIf
EndFunc   ;==>_RunCommandLineMode
#EndRegion ; *** COMMAND-LINE MODE FUNCTIONS ***

#Region ; *** FILE AND DATA HANDLING ***

; -------------------------------------------------------------------------------------------------
; Function:      _AddFileToList($sFilePath)
; Purpose:       Adds a file's information to the global array and updates the GUI list.
; -------------------------------------------------------------------------------------------------
Func _AddFileToList($sFilePath)
	If Not FileExists($sFilePath) Then Return
	For $i = 0 To UBound($g_aSelectedFiles) - 1
		If $g_aSelectedFiles[$i][0] = $sFilePath Then Return
	Next
	Local $iUBound = UBound($g_aSelectedFiles)
	ReDim $g_aSelectedFiles[$iUBound + 1][5]
	_PopulateFileInfo($g_aSelectedFiles, $iUBound, $sFilePath)
	Local $sListViewItem = $g_aSelectedFiles[$iUBound][1] & "|" & $g_aSelectedFiles[$iUBound][2] & "|" & $g_aSelectedFiles[$iUBound][3] & "|" & $g_aSelectedFiles[$iUBound][4]
	GUICtrlCreateListViewItem($sListViewItem, $g_hListView)
EndFunc   ;==>_AddFileToList

; -------------------------------------------------------------------------------------------------
; Function:      _PopulateFileInfo(ByRef $aArray, $iIndex, $sFilePath)
; Purpose:       Gathers file info and populates a row in the provided 2D array.
; -------------------------------------------------------------------------------------------------
Func _PopulateFileInfo(ByRef $aArray, $iIndex, $sFilePath)
	Local $sFileName = _GetFileName($sFilePath)
	Local $sArch = _DetectArchitecture($sFilePath)
	$aArray[$iIndex][0] = $sFilePath
	$aArray[$iIndex][1] = $sFileName
	$aArray[$iIndex][2] = _FormatFileSize(FileGetSize($sFilePath))
	$aArray[$iIndex][3] = $sArch
	$aArray[$iIndex][4] = "_GetBinData_" & _SanitizeName($sFileName) & "_" & $sArch
EndFunc   ;==>_PopulateFileInfo
#EndRegion ; *** FILE AND DATA HANDLING ***

#Region ; *** CORE CODE GENERATION ***

; -------------------------------------------------------------------------------------------------
; Function:      _GenerateCodeBundle(ByRef $aFiles, $bAddHelpers, $iChunkSize)
; Purpose:       The main code generation engine. Creates the full script content.
; -------------------------------------------------------------------------------------------------
Func _GenerateCodeBundle(ByRef $aFiles, $bAddHelpers, $iChunkSize)
	Local $sOutput = "; Generated by AutoIt Embedded File Generator - TRONG.PRO" & @CRLF
	$sOutput &= "; Total files: " & UBound($aFiles) & @CRLF
	$sOutput &= "; Generated on: " & @YEAR & "-" & @MON & "-" & @MDAY & " " & @HOUR & ":" & @MIN & ":" & @SEC & @CRLF & @CRLF
	For $i = 0 To UBound($aFiles) - 1
		$sOutput &= _GenerateHexFunction($aFiles[$i][0], $aFiles[$i][4], $aFiles[$i][1], $aFiles[$i][3], "$sHexData", $iChunkSize) & @CRLF & @CRLF
	Next
	If $bAddHelpers Then
		If UBound($aFiles) = 1 Then
			$sOutput &= _GenerateHelperFunction($aFiles[0][4], $aFiles[0][1])
		Else
			$sOutput &= _GenerateMasterHelperFunctionFromArray($aFiles)
		EndIf
	EndIf
	Return $sOutput
EndFunc   ;==>_GenerateCodeBundle

; -------------------------------------------------------------------------------------------------
; Function:      _GenerateHexFunction($sFilePath, $sFuncName, $sFileName, $sArch, $sVarName, $iChunkSize)
; Purpose:       Reads a binary file and wraps its hex content in an AutoIt function.
; -------------------------------------------------------------------------------------------------
Func _GenerateHexFunction($sFilePath, $sFuncName, $sFileName, $sArch, $sVarName = "$sHexData", $iChunkSize = 4000)
	Local $hFile = FileOpen($sFilePath, 16)
	If $hFile = -1 Then
		ConsoleWrite("! Error: Unable to open file in binary mode: " & $sFilePath & @CRLF)
		Return ""
	EndIf
	Local $bData = FileRead($hFile)
	FileClose($hFile)
	If @error Or $bData = "" Then
		ConsoleWrite("! Error reading binary data from file: " & $sFilePath & @CRLF)
		Return ""
	EndIf
	Local $sHexWithPrefix = StringToBinary($bData)
	If StringLeft($sVarName, 1) <> "$" Then $sVarName = "$" & $sVarName
	Local $sOutput = "Func " & $sFuncName & "()" & @CRLF
	$sOutput &= @TAB & '; This function holds the hex data for ' & $sFileName & @CRLF
	$sOutput &= @TAB & '; File size: ' & _FormatFileSize(FileGetSize($sFilePath)) & @CRLF
	$sOutput &= @TAB & '; Architecture: ' & $sArch & @CRLF
	$sOutput &= @TAB & '; Generated by AutoIt Embedded File Generator' & @CRLF
	Local $iHexLen = StringLen($sHexWithPrefix)
	$sOutput &= @TAB & "Local " & $sVarName & " = '" & StringMid($sHexWithPrefix, 1, $iChunkSize) & "'" & @CRLF
	For $i = $iChunkSize + 1 To $iHexLen Step $iChunkSize
		$sOutput &= @TAB & $sVarName & " &= '" & StringMid($sHexWithPrefix, $i, $iChunkSize) & "'" & @CRLF
	Next
	$sOutput &= @CRLF & @TAB & "Return " & $sVarName & @CRLF
	$sOutput &= "EndFunc   ;==>" & $sFuncName
	Return $sOutput
EndFunc   ;==>_GenerateHexFunction

; -------------------------------------------------------------------------------------------------
; Function:      _GenerateHelperFunction($sFuncName, $sOriginalFileName)
; Purpose:       Generates a helper function to deploy a single embedded file.
; -------------------------------------------------------------------------------------------------
Func _GenerateHelperFunction($sFuncName, $sOriginalFileName)
	Local $sHelperFunc = @CRLF & @CRLF
	$sHelperFunc &= '; =================================================================' & @CRLF
	$sHelperFunc &= '; Helper function to deploy the file from hex data.' & @CRLF
	$sHelperFunc &= '; =================================================================' & @CRLF
	$sHelperFunc &= 'Func _DeployFileFromHex()' & @CRLF
	$sHelperFunc &= @TAB & 'Local $sHexData = ' & $sFuncName & '()' & @CRLF
	$sHelperFunc &= @TAB & 'Local $Deploy_Dir = @TempDir' & @CRLF
	$sHelperFunc &= @TAB & 'If $sHexData = "" Then Return SetError(1, 0, MsgBox(16, "Error", "Hex data is empty."))' & @CRLF
	$sHelperFunc &= @CRLF
	$sHelperFunc &= @TAB & 'Local $sOutputFilename = "' & $sOriginalFileName & '"' & @CRLF
	$sHelperFunc &= @TAB & 'Local $sTempFilePath = $Deploy_Dir & "\" & $sOutputFilename' & @CRLF
	$sHelperFunc &= @TAB & 'Local $hFile = FileOpen($sTempFilePath, 18)' & @CRLF
	$sHelperFunc &= @TAB & 'If $hFile = -1 Then Return SetError(2, 0, MsgBox(16, "Error", "Failed to open file for writing at: " & $sTempFilePath))' & @CRLF
	$sHelperFunc &= @CRLF
	$sHelperFunc &= @TAB & 'FileWrite($hFile, BinaryToString($sHexData))' & @CRLF
	$sHelperFunc &= @TAB & 'FileClose($hFile)' & @CRLF
	$sHelperFunc &= @CRLF
	$sHelperFunc &= @TAB & 'If Not FileExists($sTempFilePath) Then Return SetError(3, 0, MsgBox(16, "Error", "Failed to write file to: " & $sTempFilePath))' & @CRLF
	$sHelperFunc &= @CRLF
	$sHelperFunc &= @TAB & 'MsgBox(64, "Success", "File deployed successfully to:" & @CRLF & $sTempFilePath)' & @CRLF
	$sHelperFunc &= @TAB & 'Return $sTempFilePath' & @CRLF
	$sHelperFunc &= 'EndFunc   ;==>_DeployFileFromHex' & @CRLF & @CRLF
	$sHelperFunc &= '; Example usage: _DeployFileFromHex()' & @CRLF
	Return $sHelperFunc
EndFunc   ;==>_GenerateHelperFunction

; -------------------------------------------------------------------------------------------------
; Function:      _GenerateMasterHelperFunctionFromArray(ByRef $aFiles)
; Purpose:       Generates a master helper function to deploy all embedded files.
; -------------------------------------------------------------------------------------------------
Func _GenerateMasterHelperFunctionFromArray(ByRef $aFiles)
	Local $sDelimiter = '"/"'
	Local $sHelperFunc = "#include <Array.au3>" & @CRLF & @CRLF
	$sHelperFunc &= '; =================================================================' & @CRLF
	$sHelperFunc &= '; Master helper function to deploy all embedded files.' & @CRLF
	$sHelperFunc &= '; =================================================================' & @CRLF
	$sHelperFunc &= 'Func _DeployAllFiles()' & @CRLF
	$sHelperFunc &= @TAB & 'Local $aResults[0]' & @CRLF
	$sHelperFunc &= @TAB & 'Local $Deploy_Dir = @TempDir' & @CRLF
	$sHelperFunc &= @CRLF
	For $i = 0 To UBound($aFiles) - 1
		Local $sFileName = $aFiles[$i][1]
		Local $sFuncName = $aFiles[$i][4]
		Local $sArch = $aFiles[$i][3]
		$sHelperFunc &= @TAB & '; Deploy ' & $sFileName & ' (' & $sArch & ')' & @CRLF
		$sHelperFunc &= @TAB & 'Local $sHexData' & $i & ' = ' & $sFuncName & '()' & @CRLF
		$sHelperFunc &= @TAB & 'If $sHexData' & $i & ' <> "" Then' & @CRLF
		$sHelperFunc &= @TAB & @TAB & 'Local $sOutputPath' & $i & ' = $Deploy_Dir & "\' & $sFileName & '"' & @CRLF
		$sHelperFunc &= @TAB & @TAB & 'Local $hFile' & $i & ' = FileOpen($sOutputPath' & $i & ', 18)' & @CRLF
		$sHelperFunc &= @TAB & @TAB & 'If $hFile' & $i & ' <> -1 Then' & @CRLF
		$sHelperFunc &= @TAB & @TAB & @TAB & 'FileWrite($hFile' & $i & ', BinaryToString($sHexData' & $i & '))' & @CRLF
		$sHelperFunc &= @TAB & @TAB & @TAB & 'FileClose($hFile' & $i & ')' & @CRLF
		$sHelperFunc &= @TAB & @TAB & @TAB & 'If FileExists($sOutputPath' & $i & ') Then' & @CRLF
		$sHelperFunc &= @TAB & @TAB & @TAB & @TAB & '_ArrayAdd($aResults, "' & $sFileName & '" & ' & $sDelimiter & ' & $sOutputPath' & $i & ' & ' & $sDelimiter & ' & "Success")' & @CRLF
		$sHelperFunc &= @TAB & @TAB & @TAB & 'Else' & @CRLF
		$sHelperFunc &= @TAB & @TAB & @TAB & @TAB & '_ArrayAdd($aResults, "' & $sFileName & '" & ' & $sDelimiter & ' & "' & $sArch & '" & ' & $sDelimiter & ' & "Write failed")' & @CRLF
		$sHelperFunc &= @TAB & @TAB & @TAB & 'EndIf' & @CRLF
		$sHelperFunc &= @TAB & @TAB & 'Else' & @CRLF
		$sHelperFunc &= @TAB & @TAB & @TAB & '_ArrayAdd($aResults, "' & $sFileName & '" & ' & $sDelimiter & ' & "' & $sArch & '" & ' & $sDelimiter & ' & "Cannot create file")' & @CRLF
		$sHelperFunc &= @TAB & @TAB & 'EndIf' & @CRLF
		$sHelperFunc &= @TAB & 'Else' & @CRLF
		$sHelperFunc &= @TAB & @TAB & '_ArrayAdd($aResults, "' & $sFileName & '" & ' & $sDelimiter & ' & "' & $sArch & '" & ' & $sDelimiter & ' & "No hex data")' & @CRLF
		$sHelperFunc &= @TAB & 'EndIf' & @CRLF
		$sHelperFunc &= @CRLF
	Next
	$sHelperFunc &= @TAB & '; Display results' & @CRLF
	$sHelperFunc &= @TAB & 'Local $sReport = "Deployment Results (" & UBound($aResults) & " files):" & @CRLF & @CRLF' & @CRLF
	$sHelperFunc &= @TAB & 'For $i = 0 To UBound($aResults) - 1' & @CRLF
	$sHelperFunc &= @TAB & @TAB & 'Local $aParts = StringSplit($aResults[$i], ' & $sDelimiter & ')' & @CRLF
	$sHelperFunc &= @TAB & @TAB & 'If $aParts[0] = 3 Then' & @CRLF
	$sHelperFunc &= @TAB & @TAB & @TAB & '$sReport &= "• " & $aParts[1] & ": " & $aParts[3]' & @CRLF
	$sHelperFunc &= @TAB & @TAB & @TAB & 'If $aParts[3] = "Success" Then' & @CRLF
	$sHelperFunc &= @TAB & @TAB & @TAB & @TAB & '$sReport &= " → " & $aParts[2]' & @CRLF
	$sHelperFunc &= @TAB & @TAB & @TAB & 'Else' & @CRLF
	$sHelperFunc &= @TAB & @TAB & @TAB & @TAB & '$sReport &= " (" & $aParts[2] & ")"' & @CRLF
	$sHelperFunc &= @TAB & @TAB & @TAB & 'EndIf' & @CRLF
	$sHelperFunc &= @TAB & @TAB & @TAB & '$sReport &= @CRLF' & @CRLF
	$sHelperFunc &= @TAB & @TAB & 'EndIf' & @CRLF
	$sHelperFunc &= @TAB & 'Next' & @CRLF
	$sHelperFunc &= @CRLF
	$sHelperFunc &= @TAB & 'MsgBox(64, "Deployment Complete", $sReport)' & @CRLF
	$sHelperFunc &= @TAB & 'Return $aResults' & @CRLF
	$sHelperFunc &= 'EndFunc   ;==>_DeployAllFiles' & @CRLF & @CRLF
	$sHelperFunc &= '; Example usage: _DeployAllFiles()' & @CRLF
	Return $sHelperFunc
EndFunc   ;==>_GenerateMasterHelperFunctionFromArray
#EndRegion ; *** CORE CODE GENERATION ***

#Region ; *** PE HEADER AND ARCHITECTURE DETECTION ***

; -------------------------------------------------------------------------------------------------
; Function:      _DetectArchitecture($sFilePath)
; Purpose:       A wrapper that returns the architecture string for a file.
; -------------------------------------------------------------------------------------------------
Func _DetectArchitecture($sFilePath)
	Local $sArch = _DetectArchitecture_File($sFilePath)
	If @error Then Return "N/A"
	Return $sArch
EndFunc   ;==>_DetectArchitecture

; -------------------------------------------------------------------------------------------------
; Function:      _DetectArchitecture_File($sFilePath)
; Purpose:       Reads a file's PE headers to identify the target CPU architecture.
; -------------------------------------------------------------------------------------------------
Func _DetectArchitecture_File($sFilePath)
	If Not FileExists($sFilePath) Then Return SetError(1, 0, "FILE_NOT_FOUND")
	Local $hFile = FileOpen($sFilePath, 16)
	If $hFile = -1 Then Return SetError(2, 0, "CANNOT_OPEN_FILE")
	Local $bDOSHeader = FileRead($hFile, 64)
	If @error Then
		FileClose($hFile)
		Return SetError(3, 0, "CANNOT_READ_DOS_HEADER")
	EndIf
	If BinaryMid($bDOSHeader, 1, 2) <> "0x4D5A" Then
		FileClose($hFile)
		Return "Not PE"
	EndIf
	Local $iPEOffset = _BinaryToInt(BinaryMid($bDOSHeader, 61, 4))
	FileSetPos($hFile, $iPEOffset, $FILE_BEGIN)
	Local $bPESig = FileRead($hFile, 4)
	If @error Or $bPESig <> "0x50450000" Then
		FileClose($hFile)
		Return SetError(5, 0, "INVALID_PE_SIGNATURE")
	EndIf
	Local $bCOFF = FileRead($hFile, 2)
	FileClose($hFile)
	If @error Then Return SetError(6, 0, "CANNOT_READ_COFF_HEADER")
	Local $iMachine = _BinaryToInt($bCOFF)
	Switch $iMachine
		Case 0x014c
			Return "x86"
		Case 0x8664
			Return "x64"
		Case 0x01c0, 0x01c4
			Return "ARM"
		Case 0xAA64
			Return "ARM64"
		Case 0x0200
			Return "IA64"
		Case Else
			Return "UNKNOWN_0x" & Hex($iMachine, 4)
	EndSwitch
EndFunc   ;==>_DetectArchitecture_File

; -------------------------------------------------------------------------------------------------
; Function:      _BinaryToInt($bData)
; Purpose:       Converts a little-endian binary string to an integer value.
; -------------------------------------------------------------------------------------------------
Func _BinaryToInt($bData)
	Local $iResult = 0
	For $i = 1 To BinaryLen($bData)
		$iResult += Number(BinaryMid($bData, $i, 1)) * (256 ^ ($i - 1))
	Next
	Return $iResult
EndFunc   ;==>_BinaryToInt
#EndRegion ; *** PE HEADER AND ARCHITECTURE DETECTION ***

#Region ; *** UTILITY FUNCTIONS ***

; -------------------------------------------------------------------------------------------------
; Function:      _SanitizeName($sInput)
; Purpose:       Removes illegal characters from a string to make it a valid function name.
; -------------------------------------------------------------------------------------------------
Func _SanitizeName($sInput)
	Local $sCleaned = StringRegExpReplace($sInput, "[^a-zA-Z0-9_]", "")
	If StringLeft($sCleaned, 1) = "$" Then $sCleaned = StringTrimLeft($sCleaned, 1)
	Return $sCleaned
EndFunc   ;==>_SanitizeName

; -------------------------------------------------------------------------------------------------
; Function:      _GetFileName($sFilePath)
; Purpose:       Extracts the filename and extension from a full path.
; -------------------------------------------------------------------------------------------------
Func _GetFileName($sFilePath)
	Return StringRegExpReplace($sFilePath, "^.*\\", "")
EndFunc   ;==>_GetFileName

; -------------------------------------------------------------------------------------------------
; Function:      _FormatFileSize($iBytes)
; Purpose:       Converts a file size in bytes into a human-readable string (KB, MB, GB).
; -------------------------------------------------------------------------------------------------
Func _FormatFileSize($iBytes)
	If $iBytes < 1024 Then
		Return $iBytes & " B"
	ElseIf $iBytes < 1048576 Then
		Return Round($iBytes / 1024, 1) & " KB"
	ElseIf $iBytes < 1073741824 Then
		Return Round($iBytes / 1048576, 2) & " MB"
	Else
		Return Round($iBytes / 1073741824, 2) & " GB"
	EndIf
EndFunc   ;==>_FormatFileSize

; -------------------------------------------------------------------------------------------------
; Function:      _ValidateChunkSize($iChunkSize)
; Purpose:       Ensures the chunk size is within a valid range.
; -------------------------------------------------------------------------------------------------
Func _ValidateChunkSize($iChunkSize)
	; First, check if the input from the GUI is a string containing only digits.
	If Not StringIsDigit($iChunkSize) Then
		Return 4000 ; If not, it's invalid, return the default value.
	EndIf
	; If it is a digit string, convert it to a real number.
	Local $nChunkSize = Number($iChunkSize)
	If ($iChunkSize < 100) Or ($iChunkSize > 4000) Then
		Return 4000
	EndIf
	Return Int($iChunkSize)
EndFunc   ;==>_ValidateChunkSize

; -------------------------------------------------------------------------------------------------
; Function:      _SaveStringToFile($sFilePath, $sContent)
; Purpose:       A robust function to save a string to a file.
; Returns:       True on success, False on failure.
; -------------------------------------------------------------------------------------------------
Func _SaveStringToFile($sFilePath, $sContent)
	Local $hFile = FileOpen($sFilePath, 2)
	If $hFile = -1 Then Return False
	Local $bSuccess = FileWrite($hFile, $sContent)
	FileClose($hFile)
	Return $bSuccess
EndFunc   ;==>_SaveStringToFile
#EndRegion ; *** UTILITY FUNCTIONS ***


#Region Include
Func _MemGlobalAlloc($iBytes, $iFlags = 0)
	Local $aCall = DllCall("kernel32.dll", "handle", "GlobalAlloc", "uint", $iFlags, "ulong_ptr", $iBytes)
	If @error Then Return SetError(@error, @extended, 0)
	Return $aCall[0]
EndFunc   ;==>_MemGlobalAlloc
Func _MemGlobalLock($hMemory)
	Local $aCall = DllCall("kernel32.dll", "ptr", "GlobalLock", "handle", $hMemory)
	If @error Then Return SetError(@error, @extended, 0)
	Return $aCall[0]
EndFunc   ;==>_MemGlobalLock
Func _MemGlobalUnlock($hMemory)
	Local $aCall = DllCall("kernel32.dll", "bool", "GlobalUnlock", "handle", $hMemory)
	If @error Then Return SetError(@error, @extended, 0)
	Return $aCall[0]
EndFunc   ;==>_MemGlobalUnlock
Func _ClipBoard_Close()
	Local $aCall = DllCall("user32.dll", "bool", "CloseClipboard")
	If @error Then Return SetError(@error, @extended, False)
	Return $aCall[0]
EndFunc   ;==>_ClipBoard_Close
Func _ClipBoard_Empty()
	Local $aCall = DllCall("user32.dll", "bool", "EmptyClipboard")
	If @error Then Return SetError(@error, @extended, False)
	Return $aCall[0]
EndFunc   ;==>_ClipBoard_Empty
Func _ClipBoard_Open($hOwner)
	Local $aCall = DllCall("user32.dll", "bool", "OpenClipboard", "hwnd", $hOwner)
	If @error Then Return SetError(@error, @extended, False)
	Return $aCall[0]
EndFunc   ;==>_ClipBoard_Open
Func _ClipBoard_SetData($vData, $iFormat = $CF_TEXT)
	Local $tData, $hLock, $hMemory, $iSize
	If IsNumber($vData) And $vData = 0 Then
		$hMemory = $vData
	Else
		If IsBinary($vData) Then
			$iSize = BinaryLen($vData)
		ElseIf IsString($vData) Then
			$iSize = StringLen($vData)
		Else
			Return SetError(2, 0, 0)
		EndIf
		$iSize += 1
		If $iFormat = $CF_UNICODETEXT Then
			$hMemory = _MemGlobalAlloc($iSize * 2, $GHND)
		Else
			$hMemory = _MemGlobalAlloc($iSize, $GHND)
		EndIf
		If $hMemory = 0 Then Return SetError(-1, 0, 0)
		$hLock = _MemGlobalLock($hMemory)
		If $hLock = 0 Then Return SetError(-2, 0, 0)
		Switch $iFormat
			Case $CF_TEXT, $CF_OEMTEXT
				$tData = DllStructCreate("char[" & $iSize & "]", $hLock)
			Case $CF_UNICODETEXT
				$tData = DllStructCreate("wchar[" & $iSize & "]", $hLock)
			Case Else
				$tData = DllStructCreate("byte[" & $iSize & "]", $hLock)
		EndSwitch
		DllStructSetData($tData, 1, $vData)
		_MemGlobalUnlock($hMemory)
	EndIf
	If Not _ClipBoard_Open(0) Then Return SetError(-5, 0, 0)
	If Not _ClipBoard_Empty() Then
		_ClipBoard_Close()
		Return SetError(-6, 0, 0)
	EndIf
	If Not _ClipBoard_SetDataEx($hMemory, $iFormat) Then
		_ClipBoard_Close()
		Return SetError(-7, 0, 0)
	EndIf
	_ClipBoard_Close()
	Return $hMemory
EndFunc   ;==>_ClipBoard_SetData
Func _ClipBoard_SetDataEx(ByRef $hMemory, $iFormat = $CF_TEXT)
	Local $aCall = DllCall("user32.dll", "handle", "SetClipboardData", "uint", $iFormat, "handle", $hMemory)
	If @error Then Return SetError(@error, @extended, 0)
	Return $aCall[0]
EndFunc   ;==>_ClipBoard_SetDataEx
Func _ArrayAdd(ByRef $aArray, $vValue, $iStart = 0, $sDelim_Item = "|", $sDelim_Row = @CRLF, $iForce = $ARRAYFILL_FORCE_DEFAULT)
	If $iStart = Default Then $iStart = 0
	If $sDelim_Item = Default Then $sDelim_Item = "|"
	If $sDelim_Row = Default Then $sDelim_Row = @CRLF
	If $iForce = Default Then $iForce = $ARRAYFILL_FORCE_DEFAULT
	If Not IsArray($aArray) Then Return SetError(1, 0, -1)
	Local $iDim_1 = UBound($aArray, $UBOUND_ROWS)
	Local $hDataType = 0
	Switch $iForce
		Case $ARRAYFILL_FORCE_INT
			$hDataType = Int
		Case $ARRAYFILL_FORCE_NUMBER
			$hDataType = Number
		Case $ARRAYFILL_FORCE_PTR
			$hDataType = Ptr
		Case $ARRAYFILL_FORCE_HWND
			$hDataType = Hwnd
		Case $ARRAYFILL_FORCE_STRING
			$hDataType = String
		Case $ARRAYFILL_FORCE_BOOLEAN
			$hDataType = "Boolean"
	EndSwitch
	Switch UBound($aArray, $UBOUND_DIMENSIONS)
		Case 1
			If $iForce = $ARRAYFILL_FORCE_SINGLEITEM Then
				ReDim $aArray[$iDim_1 + 1]
				$aArray[$iDim_1] = $vValue
				Return $iDim_1
			EndIf
			If IsArray($vValue) Then
				If UBound($vValue, $UBOUND_DIMENSIONS) <> 1 Then Return SetError(5, 0, -1)
				$hDataType = 0
			Else
				Local $aTmp = StringSplit($vValue, $sDelim_Item, $STR_NOCOUNT + $STR_ENTIRESPLIT)
				If UBound($aTmp, $UBOUND_ROWS) = 1 Then
					$aTmp[0] = $vValue
				EndIf
				$vValue = $aTmp
			EndIf
			Local $iAdd = UBound($vValue, $UBOUND_ROWS)
			ReDim $aArray[$iDim_1 + $iAdd]
			For $i = 0 To $iAdd - 1
				If String($hDataType) = "Boolean" Then
					Switch $vValue[$i]
						Case "True", "1"
							$aArray[$iDim_1 + $i] = True
						Case "False", "0", ""
							$aArray[$iDim_1 + $i] = False
					EndSwitch
				ElseIf IsFunc($hDataType) Then
					$aArray[$iDim_1 + $i] = $hDataType($vValue[$i])
				Else
					$aArray[$iDim_1 + $i] = $vValue[$i]
				EndIf
			Next
			Return $iDim_1 + $iAdd - 1
		Case 2
			Local $iDim_2 = UBound($aArray, $UBOUND_COLUMNS)
			If $iStart < 0 Or $iStart > $iDim_2 - 1 Then Return SetError(4, 0, -1)
			Local $iValDim_1, $iValDim_2 = 0, $iColCount
			If IsArray($vValue) Then
				If UBound($vValue, $UBOUND_DIMENSIONS) <> 2 Then Return SetError(5, 0, -1)
				$iValDim_1 = UBound($vValue, $UBOUND_ROWS)
				$iValDim_2 = UBound($vValue, $UBOUND_COLUMNS)
				$hDataType = 0
			Else
				Local $aSplit_1 = StringSplit($vValue, $sDelim_Row, $STR_NOCOUNT + $STR_ENTIRESPLIT)
				$iValDim_1 = UBound($aSplit_1, $UBOUND_ROWS)
				Local $aTmp[$iValDim_1][0], $aSplit_2
				For $i = 0 To $iValDim_1 - 1
					$aSplit_2 = StringSplit($aSplit_1[$i], $sDelim_Item, $STR_NOCOUNT + $STR_ENTIRESPLIT)
					$iColCount = UBound($aSplit_2)
					If $iColCount > $iValDim_2 Then
						$iValDim_2 = $iColCount
						ReDim $aTmp[$iValDim_1][$iValDim_2]
					EndIf
					For $j = 0 To $iColCount - 1
						$aTmp[$i][$j] = $aSplit_2[$j]
					Next
				Next
				$vValue = $aTmp
			EndIf
			If UBound($vValue, $UBOUND_COLUMNS) + $iStart > UBound($aArray, $UBOUND_COLUMNS) Then Return SetError(3, 0, -1)
			ReDim $aArray[$iDim_1 + $iValDim_1][$iDim_2]
			For $iWriteTo_Index = 0 To $iValDim_1 - 1
				For $j = 0 To $iDim_2 - 1
					If $j < $iStart Then
						$aArray[$iWriteTo_Index + $iDim_1][$j] = ""
					ElseIf $j - $iStart > $iValDim_2 - 1 Then
						$aArray[$iWriteTo_Index + $iDim_1][$j] = ""
					Else
						If String($hDataType) = "Boolean" Then
							Switch $vValue[$iWriteTo_Index][$j - $iStart]
								Case "True", "1"
									$aArray[$iWriteTo_Index + $iDim_1][$j] = True
								Case "False", "0", ""
									$aArray[$iWriteTo_Index + $iDim_1][$j] = False
							EndSwitch
						ElseIf IsFunc($hDataType) Then
							$aArray[$iWriteTo_Index + $iDim_1][$j] = $hDataType($vValue[$iWriteTo_Index][$j - $iStart])
						Else
							$aArray[$iWriteTo_Index + $iDim_1][$j] = $vValue[$iWriteTo_Index][$j - $iStart]
						EndIf
					EndIf
				Next
			Next
		Case Else
			Return SetError(2, 0, -1)
	EndSwitch
	Return UBound($aArray, $UBOUND_ROWS) - 1
EndFunc   ;==>_ArrayAdd
Func _ArrayDelete(ByRef $aArray, $vRange)
	If Not IsArray($aArray) Then Return SetError(1, 0, -1)
	Local $iDim_1 = UBound($aArray, $UBOUND_ROWS) - 1
	If IsArray($vRange) Then
		If UBound($vRange, $UBOUND_DIMENSIONS) <> 1 Or UBound($vRange, $UBOUND_ROWS) < 2 Then Return SetError(4, 0, -1)
	Else
		Local $iNumber, $aSplit_1, $aSplit_2
		$vRange = StringStripWS($vRange, 8)
		$aSplit_1 = StringSplit($vRange, ";")
		$vRange = ""
		For $i = 1 To $aSplit_1[0]
			If Not StringRegExp($aSplit_1[$i], "^\d+(-\d+)?$") Then Return SetError(3, 0, -1)
			$aSplit_2 = StringSplit($aSplit_1[$i], "-")
			Switch $aSplit_2[0]
				Case 1
					$vRange &= $aSplit_2[1] & ";"
				Case 2
					If Number($aSplit_2[2]) >= Number($aSplit_2[1]) Then
						$iNumber = $aSplit_2[1] - 1
						Do
							$iNumber += 1
							$vRange &= $iNumber & ";"
						Until $iNumber = $aSplit_2[2]
					EndIf
			EndSwitch
		Next
		$vRange = StringSplit(StringTrimRight($vRange, 1), ";")
	EndIf
	For $i = 1 To $vRange[0]
		$vRange[$i] = Number($vRange[$i])
	Next
	If $vRange[1] < 0 Or $vRange[$vRange[0]] > $iDim_1 Then Return SetError(5, 0, -1)
	Local $iCopyTo_Index = 0
	Switch UBound($aArray, $UBOUND_DIMENSIONS)
		Case 1
			For $i = 1 To $vRange[0]
				$aArray[$vRange[$i]] = ChrW(0xFAB1)
			Next
			For $iReadFrom_Index = 0 To $iDim_1
				If $aArray[$iReadFrom_Index] == ChrW(0xFAB1) Then
					ContinueLoop
				Else
					If $iReadFrom_Index <> $iCopyTo_Index Then
						$aArray[$iCopyTo_Index] = $aArray[$iReadFrom_Index]
					EndIf
					$iCopyTo_Index += 1
				EndIf
			Next
			ReDim $aArray[$iDim_1 - $vRange[0] + 1]
		Case 2
			Local $iDim_2 = UBound($aArray, $UBOUND_COLUMNS) - 1
			For $i = 1 To $vRange[0]
				$aArray[$vRange[$i]][0] = ChrW(0xFAB1)
			Next
			For $iReadFrom_Index = 0 To $iDim_1
				If $aArray[$iReadFrom_Index][0] == ChrW(0xFAB1) Then
					ContinueLoop
				Else
					If $iReadFrom_Index <> $iCopyTo_Index Then
						For $j = 0 To $iDim_2
							$aArray[$iCopyTo_Index][$j] = $aArray[$iReadFrom_Index][$j]
						Next
					EndIf
					$iCopyTo_Index += 1
				EndIf
			Next
			ReDim $aArray[$iDim_1 - $vRange[0] + 1][$iDim_2 + 1]
		Case Else
			Return SetError(2, 0, False)
	EndSwitch
	Return UBound($aArray, $UBOUND_ROWS)
EndFunc   ;==>_ArrayDelete
Func _PathSplit($sFilePath, ByRef $sDrive, ByRef $sDir, ByRef $sFileName, ByRef $sExtension)
	Local $aArray = StringRegExp($sFilePath, "^\h*((?:\\\\\?\\)*(\\\\[^\?\/\\]+|[A-Za-z]:)?(.*[\/\\]\h*)?((?:[^\.\/\\]|(?(?=\.[^\/\\]*\.)\.))*)?([^\/\\]*))$", $STR_REGEXPARRAYMATCH)
	If @error Then
		ReDim $aArray[5]
		$aArray[$PATH_ORIGINAL] = $sFilePath
	EndIf
	$sDrive = $aArray[$PATH_DRIVE]
	If StringLeft($aArray[$PATH_DIRECTORY], 1) == "/" Then
		$sDir = StringRegExpReplace($aArray[$PATH_DIRECTORY], "\h*[\/\\]+\h*", "\/")
	Else
		$sDir = StringRegExpReplace($aArray[$PATH_DIRECTORY], "\h*[\/\\]+\h*", "\\")
	EndIf
	$aArray[$PATH_DIRECTORY] = $sDir
	$sFileName = $aArray[$PATH_FILENAME]
	$sExtension = $aArray[$PATH_EXTENSION]
	Return $aArray
EndFunc   ;==>_PathSplit

#EndRegion Include
