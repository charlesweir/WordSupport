VERSION 1.0 CLASS
BEGIN
  MultiUse = -1  'True
END
Attribute VB_Name = "ColumnLayout"
Attribute VB_GlobalNameSpace = False
Attribute VB_Creatable = False
Attribute VB_PredeclaredId = False
Attribute VB_Exposed = False
    ' ColumnLayout: Represents the layout for the current column.
Option Explicit

Dim workingPage As Integer
' Dim workingColumn As Integer
' Dim workingPageStatus As PageFillStatus
' Dim workingColumnStatus As PageFillStatus
Dim workingPosition As Range
Dim clsAnchoredFrame As New anchoredFrame

Private Enum PossiblePosition
    ppTop = 1 ' Frame at the top
    ppBottom = 2 ' Frame at the top and the bottom
    ppElsewhere = 3 ' Definitely need to position on the next page.
End Enum

Dim spaceUsedInColumn(3) As Integer ' 0, 1, 2

Sub Initialise()
    workingPage = 0
    Set workingPosition = ActiveDocument.Content
    workingPosition.Collapse
End Sub

Sub CheckForNewPage()
    ' If we've moved to a new page, reset everything
    If CurrentPage <> workingPage Then
        workingPage = CurrentPage
        spaceUsedInColumn(1) = 0
        spaceUsedInColumn(2) = 0
    End If
End Sub


        
Sub PositionFrame(newFrame As anchoredFrame)
    With newFrame
        If workingPosition.Start < .ReferenceFieldStart.Start Then
            Set workingPosition = .PlaceNearReference
        Else
            workingPosition.Move wdCharacter ' Move past any previous paste.
        End If
        
        CheckForNewPage
        
        If desiredPosition(newFrame) <> ppElsewhere Then
            ' Try moving it to the working position, at the top or bottom of the page:
            .MoveAnchorTo workingPosition
    
            ' Todo: Add special case. Top of page is continued table, in which case we want to be bottom.
            .SetToFloatAt IIf(desiredPosition(newFrame) = ppTop, wdShapeTop, wdShapeBottom)
    
            ' Unless
            '   the anchor is now on a different page number, or Word has misbehaved and put both overlapping anyway.
            '   Word also seems to behave oddly when there's two frames and only one line of text (and it looks pretty odd too):
            '   Let's say we we want at least 10% of page for text when there are two frames on the page.
            ' we're done.
            If Not ((.FramePageNumber > workingPage) _
                    Or ((spaceUsedInColumn(CurrentColumn) > 0) And (spaceUsedInColumn(CurrentColumn) + .Height > (.UsableDocumentHeight * 0.9)))) Then
                ' We're done
                UpdateColumnSpace newFrame
                Exit Sub
            End If
        End If
        
        ' OK. There wasn't space enough on that page, put it on the next one:
        .Stash ' Get it out of the way.
        
        ' Find the first para (line?) on the next column
        Debug.Assert workingPage = CurrentPage
        Dim startColumn As Integer
        Dim nextPage As Range
        startColumn = CurrentColumn
        
        If .NumColumns = 2 Then
            While CurrentColumn = startColumn And CurrentPage = workingPage
                workingPosition.Move wdParagraph
            Wend
        Else ' Single column
            Set nextPage = workingPosition.GoTo(wdGoToPage, wdGoToNext)
            ' Kludge. The above sometimes goes wrong (but not when stepping through in the debugger):
            If nextPage.Information(wdActiveEndPageNumber) = workingPage + 1 Then
                Set workingPosition = nextPage
            Else
                ' Gone wrong. Use another approach to find the next page.
                While workingPosition.Information(wdActiveEndPageNumber) = workingPage
                    workingPosition.Move wdParagraph
                Wend
            End If
        End If
        CheckForNewPage
        
        ' Skip over any tables, as tables make a right mess.
        While workingPosition.Information(wdWithInTable) _
                 And (Not workingPosition.Next(Unit:=wdParagraph) Is Nothing)
            workingPosition.Move wdParagraph
        Wend

        ' N.B. There might not be enough paras to take all the images. Also we might end up in the middle of the bibliography.
        ' Both would be unusual in academic papers. Forget it.
        
        ' And move it there
        .MoveAnchorTo workingPosition
        .SetToFloatAt IIf(desiredPosition(newFrame) = ppTop, wdShapeTop, wdShapeBottom)
        UpdateColumnSpace newFrame
    End With
End Sub

Private Sub UpdateColumnSpace(oAnchoredFrame As anchoredFrame)
    With oAnchoredFrame
        If .FitsInColumn Then ' Single column, or small frame in double column.
            spaceUsedInColumn(CurrentColumn) = IIf(spaceUsedInColumn(CurrentColumn) = 0, .Height, .UsableDocumentHeight)
            Exit Sub
        End If
  
        spaceUsedInColumn(1) = .Height
        spaceUsedInColumn(2) = .Height
    End With
End Sub

Private Function desiredPosition(oAnchoredFrame As anchoredFrame) As PossiblePosition
    ' Answers where we'd like to place the image (ignoring that it might end up on the following page/column when we try),
    ' given the current workingPosition
    With oAnchoredFrame
        If .FitsInColumn Then
            If spaceUsedInColumn(CurrentColumn) = 0 Then
                desiredPosition = ppTop
            ElseIf spaceUsedInColumn(CurrentColumn) > 0 And spaceUsedInColumn(CurrentColumn) < .UsableDocumentHeight Then
                desiredPosition = ppBottom
            Else
                desiredPosition = ppElsewhere
            End If
        Else
            ' Use the Latex kludge. We don't have banner images at the bottom.
            If spaceUsedInColumn(1) = 0 And spaceUsedInColumn(2) = 0 Then
                desiredPosition = ppTop
            Else
                desiredPosition = ppElsewhere
            End If
        End If
    End With
End Function

Private Property Get CurrentColumn() As Integer
    CurrentColumn = clsAnchoredFrame.ColumnNumberFor(workingPosition)
End Property

Private Property Get CurrentPage() As Integer
    CurrentPage = workingPosition.Information(wdActiveEndPageNumber)
End Property