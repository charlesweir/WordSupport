Attribute VB_Name = "ActionTests"
' Tests for LayoutFloatingImages.

'Option Explicit ' All variables must be defined.

Sub ActionTests()
    ' Reset the undo buffer, and fix the selection:
    ActiveDocument.UndoClear
    Set cursorLocation = Selection.Range

    For Each mySection In ActiveDocument.Sections
        Dim oRangeTested As Range
        Set oRangeTested = mySection.Range
        If Not oRangeTested.Text Like "*Resulting Name;*" Then GoTo nextMySection
        ' Does the repositioning, then checks everything's right.
        
        ' First, load the test specs from the first paragraph in the section:
        tests = Split(oRangeTested.Paragraphs(1).Range.Text, Chr(11))
    
        Dim myFrames As Collection
        Set myFrames = New Collection
        
        ' First, find all the frames and their hidden bookmarks generated by the Cross Reference to Figure or Table
        For Each shp In oRangeTested.ShapeRange
            If shp.Type = msoTextBox Then
                Set bookmarkSet = shp.TextFrame.TextRange.Bookmarks
                bookmarkSet.ShowHidden = True
                If bookmarkSet.count > 0 And bookmarkSet(1).name Like "_Ref##*" Then
                    myFrames.Add Item:=shp, key:=bookmarkSet(1).Range.Text ' Gives "Figure NN"
                End If
            End If
        Next
        
        LayoutFloatingImages.LayoutFloatingImagesFor oRangeTested
        
        For Each x In tests
            If Not (x Like "Figure *" Or x Like "Table *") Then GoTo NextX ' There's no continue in this version of VBA
     
            Dim expectedName As String
            expectedName = Split(x, ";")(0)             ' E.g. Figure 1
            expectedLocation = Split(x, ";")(1)         ' E.g. top of column
            expectedColumn = Split(x, ";")(2)           ' E.g. 2
            expectedFirstParaOnPage = Split(x, ";")(3)  ' E.g  12
            
            Debug.Assert ContainsKey(myFrames, expectedName)
            Set shp = myFrames(expectedName)
            
            actualColumn = "" & ColumnNumber(shp.Anchor)
            Debug.Assert actualColumn = expectedColumn
            
            actualLocation = IIf(shp.Top = wdShapeTop, "top", IIf(shp.Top = wdShapeBottom, "bottom", "other"))
            Debug.Assert expectedLocation Like actualLocation & "*"
            
            actualHLocation = IIf(shp.RelativeHorizontalPosition = wdRelativeHorizontalPositionColumn, "column", _
                                IIf(shp.RelativeHorizontalPosition = wdRelativeHorizontalPositionMargin, "page", "other"))
            Debug.Assert expectedLocation Like "*" & actualHLocation
            
            Set firstPara = shp.Anchor
            Set firstPara = firstPara.GoTo(What:=wdGoToPage, count:=shp.Anchor.Information(wdActiveEndPageNumber))
            actualFirstParaOnPage = firstPara.ListFormat.ListString
            Debug.Assert actualFirstParaOnPage = expectedFirstParaOnPage & "."
NextX:
        Next x
nextMySection:
    Next mySection
    
    ' And reset everything.
    ActiveDocument.Undo (1000)
    cursorLocation.Select
    MsgBox ("All tests completed")
End Sub

Private Function ColumnNumber(rng As Range) As Integer
    ColumnNumber = 1 ' default
    Set currentPageSetup = ActiveDocument.Sections(rng.Information(wdActiveEndSectionNumber)).PageSetup
    ' In the left hand column, the distance from the page edge is the distance from the page boundry plus the left margin.
    ' So if we're further away, we're in the right hand column
    If currentPageSetup.TextColumns.count > 1 And _
           rng.Information(wdHorizontalPositionRelativeToPage) > rng.Information(wdHorizontalPositionRelativeToTextBoundary) + currentPageSetup.LeftMargin + 1 Then
        ColumnNumber = 2
    End If
End Function
Private Function ContainsKey(col As Collection, key As String) As Boolean
    On Error Resume Next
    col (key) ' Just try it. If it fails, Err.Number will be nonzero.
    ContainsKey = (Err.Number = 0)
    Err.Clear
    On Error GoTo 0 ' Reset
End Function

Private Sub ShowStatusBarMessage(message As String)
    If message = "" Then
        Application.StatusBar = " "
    Else
        Application.StatusBar = message
    End If
    DoEvents
End Sub
