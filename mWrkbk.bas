Attribute VB_Name = "mWrkbk"
Option Explicit
Option Private Module
Option Compare Text
' -----------------------------------------------------------------------------------
' Standard Module mWrkbk
'          Basis methods and function for Workbook objects.
'
' Methods: OpenWb     Returns a Workbook object identified by its name (sName)
'                     regardless in which application instance it is opened.
'                     Returns Nothing when a Workbook named is not open.
'                     The name may be a Workbook's full or short name
'          Opened     Returns a Distionary of all open Workbooks in any application
'                     instance with the Workbook's name as the key and the Workbook
'                     object a item.
'          GetOpen    Opens a provided Workbook if possible, returns the Workbook
'                     object of the openend or an already open Workbook
'          IsName     Returns TRUE when a provided string is the name of a Workbook
'          IsFullName Returns TRUE when a provided string is the full name of a
'                     Workbook
'          IsObject   Returns TRUE when the provided variant is a Workbook (not
'                      necessarily also open!)
'
' Uses:
' - Common Components:
'   - mBasic and mErrHndlr, both regarded available through the CompMan Addin. When this
'                           Addin is not used, both need to be imported
'   - mFile
'
' Requires: Reference to "Microsoft Scripting Runtine"
'           Reference to "Microsoft Visual Basic for Applications Extensibility ..."
'
' W. Rauschenberger, Berlin August 2019
' -----------------------------------------------------------------------------------
#Const VBE = 1              ' Requires a Reference to "Microsoft Visual Basis Extensibility ..."
' --- Begin of declarations to get all Workbooks of all running Excel instances
Private Declare PtrSafe Function FindWindowEx Lib "user32" Alias "FindWindowExA" (ByVal hWnd1 As LongPtr, ByVal hWnd2 As LongPtr, ByVal lpsz1 As String, ByVal lpsz2 As String) As LongPtr
Private Declare PtrSafe Function GetClassName Lib "user32" Alias "GetClassNameA" (ByVal hwnd As LongPtr, ByVal lpClassName As String, ByVal nMaxCount As LongPtr) As LongPtr
Private Declare PtrSafe Function IIDFromString Lib "ole32" (ByVal lpsz As LongPtr, ByRef lpiid As UUID) As LongPtr
Private Declare PtrSafe Function AccessibleObjectFromWindow Lib "oleacc" (ByVal hwnd As LongPtr, ByVal dwId As LongPtr, ByRef riid As UUID, ByRef ppvObject As Object) As LongPtr

Type UUID 'GUID
    Data1 As Long
    Data2 As Integer
    Data3 As Integer
    Data4(7) As Byte
End Type

Const IID_IDispatch As String = "{00020400-0000-0000-C000-000000000046}"
Const OBJID_NATIVEOM As LongPtr = &HFFFFFFF0
' --- End of declarations to get all Workbooks of all running Excel instances
' --- Error declarations
Const ERR_OWB01 = "A Workbook named '<>' is not open in any application instance!"
Const ERR_GOW01 = "A Workbook with the provided name (parameter vWb) is open. However it's location is '<>1' and not '<>2'!"
Const ERR_GOW02 = "A Workbook named '<>' (parameter vWb) is not open. A full name must be provided to get it opened!"
Const ERR_GOW03 = "A Workbook file named '<>' (parameter vWb) does not exist!"

Public Function IsName(ByVal v As Variant) As Boolean
Dim sExt As String

    If VarType(v) = vbString Then
        If v = vbNullString Then Exit Function
        If InStr(v, "\") = 0 And InStr(v, "/") = 0 And InStr(v, ":") = 0 Then
            sExt = Split(v, ".")(UBound(Split(v, ".")))
            Select Case sExt
                '~~ Note: A BaseName (without extension) is also regarded a name
                Case "xls", "xlm", "xlsm", "xlsb", "xlst", "xlam", "": IsName = True
            End Select
        End If
    End If

End Function

Public Function IsFullName(ByVal v As Variant) As Boolean
' -------------------------------------------------------
' Returns TRUE when v is a Workbook's FulName.
' -------------------------------------------------------
Dim sExt As String
    
    If VarType(v) = vbString Then
        If InStr(v, "\") <> 0 Or InStr(v, "/") <> 0 Or InStr(v, ":") <> 0 Then
            sExt = Split(v, ".")(UBound(Split(v, ".")))
            Select Case sExt
                Case "xls", "xlm", "xlsm", "xlsb", "xlst", "xlam": IsFullName = True
            End Select
        End If
    End If
    
End Function

Public Function IsObject(ByVal v As Variant) As Boolean
' -----------------------------------------------------
' Returns TRUE when v is a Workbook object.
' -----------------------------------------------------
    If VarType(v) = vbObject Then
        If Not TypeName(v) = "Nothing" Then
            IsObject = TypeOf v Is Workbook
        End If
    End If
End Function

Public Function IsOpen(ByVal vWb As Variant, _
              Optional ByRef wbResult As Workbook) As Boolean
' -----------------------------------------------------------
' Returns TRUE when the Workbook (vWb) - which may be a Work-
' book object, a Workbook's name or fullname - is open in
' any Excel Application instance. If a fullname is provided
' and the file does not exist under this full name but a
' Workbook with the given name is open (but from another fol-
' der) the Workbook is regarded moved and thus is returned as
' open object(wbResult).
' -----------------------------------------------------------
Const PROC      As String = "IsOpen"    ' Procedure's name for error handling and execution tracing
Dim sWbBaseName As String
Dim wb          As Workbook
Dim dctOpen     As Dictionary
Dim wbOpen      As Workbook

    On Error GoTo on_error
    
    If Not mWrkbk.IsObject(vWb) And Not mWrkbk.IsFullName(vWb) And Not mWrkbk.IsName(vWb) And Not TypeName(vWb) = "String" _
    Then Err.Raise AppErr(1), ErrSrc(PROC), "The Workbook (parameter vWb) is neither a Workbook object nor a Workbook's name or fullname)!"
    sWbBaseName = mBasic.BaseName(vWb)
    
    Set dctOpen = Opened
    If mWrkbk.IsName(vWb) Then
        If dctOpen.Exists(sWbBaseName) Then
            '~~ The Workbook is regarded open even if the path is not identical !
            IsOpen = True
            Set wbResult = dctOpen.Item(sWbBaseName)
        End If
    ElseIf mWrkbk.IsFullName(vWb) Then
        If dctOpen.Exists(sWbBaseName) Then
            Set wb = dctOpen.Item(sWbBaseName)
            If wb.FullName = vWb Then
                '~~ The already open Workbook is the Workbook requestedr
                IsOpen = True
                Set wbResult = dctOpen.Item(sWbBaseName)
            Else
                '~~ The open Workbook has the requested name but the path/location is different
                If Not mFile.Exists(vWb) Then
                    '~~ The requested Workbook does not or no longer exist at the given but at the other location
                    IsOpen = True
                    Set wbResult = dctOpen.Item(sWbBaseName)
                Else
                    '~~ Since the Workbook still exists at the requested location the one already open
                    '~~ is regarded not the one requested
                End If
            End If
        End If
    ElseIf mWrkbk.IsObject(vWb) Then
        If Opened.Exists(sWbBaseName) Then
            IsOpen = True
            Set wbResult = dctOpen.Item(sWbBaseName)
        End If
    End If
    
exit_proc:
    Exit Function
    
on_error:
#If Debugging = 1 Then
    Debug.Print Err.Description: Stop: Resume
#End If
    ErrHndlr Err.Number, ErrSrc(PROC), Err.Description, Erl
End Function

Public Function Opened() As Dictionary
' -------------------------------------
' Returns a Dictionary of all currently
' open Workbooks in any running excel
' application instance with the
' Workbook's name (without extension!)
' as the key and the Workbook as item.
' -------------------------------------
Const PROC  As String = "Opened"               ' This procedure's name for the error handling and execution tracking
#If Win64 Then
    Dim hWndMain As LongPtr
#Else
    Dim hWndMain As Long
#End If
Dim lApps   As Long
Dim wbk     As Workbook
Dim aApps() As Application ' Array of currently active Excel applications
Dim app     As Variant
Dim dct     As Dictionary
Dim i       As Long

    On Error GoTo on_error
    
    hWndMain = FindWindowEx(0&, 0&, "XLMAIN", vbNullString)
    lApps = 0

    '~~ Collect all runing Excel instances in the array aApps
    Do While hWndMain <> 0
        Set app = GetExcelObjectFromHwnd(hWndMain)
        If Not (app Is Nothing) Then
            If lApps = 0 Then
                lApps = 1
                ReDim aApps(1 To 1)
                Set aApps(lApps) = app
            ElseIf checkHwnds(aApps, app.hwnd) Then
                lApps = lApps + 1
                ReDim Preserve aApps(1 To lApps)
                Set aApps(lApps) = app
            End If
        End If
        hWndMain = FindWindowEx(0&, hWndMain, "XLMAIN", vbNullString)
    Loop

    '~~ Collect all open Workbooks in a Dictionary and return it
    If dct Is Nothing Then Set dct = New Dictionary
    With dct
        .CompareMode = TextCompare
        For Each app In aApps
            For Each wbk In app.Workbooks
                dct.Add mBasic.BaseName(wbk), wbk
            Next wbk
        Next app
    End With
    Set Opened = dct

exit_proc:
    Exit Function
    
on_error:
#If Debugging = 1 Then
    Stop: Resume
#End If
    ErrHndlr Err.Number, ErrSrc(PROC), Err.Description, Erl
End Function

#If Win64 Then
    Private Function GetExcelObjectFromHwnd(ByVal hWndMain As LongPtr) As Application
#Else
    Private Function GetExcelObjectFromHwnd(ByVal hWndMain As Long) As Application
#End If

#If Win64 Then
    Dim hWndDesk As LongPtr
    Dim hwnd As LongPtr
#Else
    Dim hWndDesk As Long
    Dim hwnd As Long
#End If
' -----------------------------------------------------------------------------------
'
' -----------------------------------------------------------------------------------
Dim sText   As String
Dim lRet    As Long
Dim iid     As UUID
Dim ob      As Object
    
    hWndDesk = FindWindowEx(hWndMain, 0&, "XLDESK", vbNullString)

    If hWndDesk <> 0 Then
        hwnd = FindWindowEx(hWndDesk, 0, vbNullString, vbNullString)

        Do While hwnd <> 0
            sText = String$(100, Chr$(0))
            lRet = CLng(GetClassName(hwnd, sText, 100))
            If Left$(sText, lRet) = "EXCEL7" Then
                Call IIDFromString(StrPtr(IID_IDispatch), iid)
                If AccessibleObjectFromWindow(hwnd, OBJID_NATIVEOM, iid, ob) = 0 Then 'S_OK
                    Set GetExcelObjectFromHwnd = ob.Application
                    GoTo exit_proc
                End If
            End If
            hwnd = FindWindowEx(hWndDesk, hwnd, vbNullString, vbNullString)
        Loop
        
    End If
    
exit_proc:
End Function

#If Win64 Then
    Private Function checkHwnds(ByRef xlApps() As Application, hwnd As LongPtr) As Boolean
#Else
    Private Function checkHwnds(ByRef xlApps() As Application, hwnd As Long) As Boolean
#End If
' -----------------------------------------------------------------------------------------
'
' -----------------------------------------------------------------------------------------
Const PROC  As String = "checkHwnds"            ' This procedure's name for the error handling and execution tracking
Dim i       As Long

    On Error GoTo on_error
    BoP ErrSrc(PROC)
    
    If UBound(xlApps) = 0 Then GoTo exit_proc

    For i = LBound(xlApps) To UBound(xlApps)
        If xlApps(i).hwnd = hwnd Then
            checkHwnds = False
            GoTo exit_proc
        End If
    Next i

    checkHwnds = True
    
exit_proc:
    EoP ErrSrc(PROC)
    Exit Function
    
on_error:
#If Debugging = 1 Then
    Stop: Resume
#End If
    ErrHndlr Err.Number, ErrSrc(PROC), Err.Description, Erl
End Function

Public Function GetOpen(ByVal vWb As Variant) As Workbook
' -------------------------------------------------------
' Returns an open Workbook object or raises an error.
' If vWb is a full path-file name, the file exists but
' is not open it is opened.
' Note: A ReadOnly mode has to be set by the caller.
' -------------------------------------------------------
Const PROC      As String = "GetOpen"   ' This procedure's name for the error handling and execution tracking
Dim sTest       As String
Dim sWbBaseName As String
Dim sPath       As String
Dim wb          As Workbook

    On Error GoTo on_error
    Set GetOpen = Nothing
    
    If Not mWrkbk.IsName(vWb) And Not mWrkbk.IsFullName(vWb) And Not mWrkbk.IsObject(vWb) _
    Then Err.Raise AppErr(1), ErrSrc(PROC), "The Workbook (parameter vWb) is neither a Workbook object nor a string (name or fullname)!"
    sWbBaseName = mBasic.BaseName(vWb)

    If mWrkbk.IsObject(vWb) Then
        Set GetOpen = vWb
    ElseIf mWrkbk.IsFullName(vWb) Then
        With Opened
            If .Exists(sWbBaseName) Then
                '~~ A Workbook with the same name is open
                Set wb = .Item(sWbBaseName)
                If wb.FullName <> vWb Then
                    '~~ The open Workook with the same name is from a different location
                    If mFile.Exists(vWb) Then
                        '~~ The file still exists on the provided location
                        Err.Raise AppErr(3), ErrSrc(PROC), Replace(Replace$(ERR_GOW01, "<>1", wb.Path), "<>2", sPath)
                    Else
                        '~~ The Workbook file does not or no longer exist at the provivded location.
                        '~~ The open one is apparenty the ment Workbook just moved to the new location.
                        Set GetOpen = wb
                    End If
                Else
                    '~~ The open Workook is the one indicated by the provided full name
                    Set GetOpen = wb
                End If
            Else
                '~~ The Workbook is yet not open
                If mFile.Exists(vWb) Then
                    Set GetOpen = Workbooks.Open(vWb)
                Else
                    Err.Raise AppErr(4), ErrSrc(PROC), Replace(ERR_GOW03, "<>", CStr(vWb))
                End If
            End If
        End With
    ElseIf mWrkbk.IsName(vWb) Then
        With Opened
            If .Exists(sWbBaseName) Then
                Set GetOpen = .Item(sWbBaseName)
            Else
                Err.Raise AppErr(5), ErrSrc(PROC), "A Workbook named '" & sWbBaseName & "' is not open and it cannot be opened since only the name is provided (a full name would be required)!"
            End If
        End With
    End If
    
exit_proc:
    Exit Function
    
on_error:
#If Debugging Then
    Stop: Resume
#End If
    ErrHndlr Err.Number, ErrSrc(PROC), Err.Description, Erl
End Function

Private Function TestSheet(ByVal wb As Workbook, _
                           ByVal vWs As Variant) As Worksheet
' -----------------------------------------------------------
' Returns the Worksheet object (vWs) - which may be a Work-
' sheet object or a Worksheet's name - of the Workbook (wb).
' Precondition: The Worksheet exists.
' -----------------------------------------------------------
    If VarType(vWs) = vbString Then
        Set TestSheet = wb.Worksheets(vWs)
    ElseIf TypeOf vWs Is Worksheet Then
        Set TestSheet = vWs
    End If
End Function

Private Function ErrSrc(ByVal sProc As String) As String
    ErrSrc = "mWrkbk" & "." & sProc
End Function
