EnableExplicit

#INVALID_ATTR = $FFFFFFFF

Structure Entry
  Name.s
  Path.s
EndStructure

Structure CsvRow
  Name.s
  Path.s
EndStructure

Global Dim Items.Entry(0)
Global ItemCount.i = 0
Global Dim DisplayedIdx.i(0)
Global DisplayedCount.i = 0
Global gHook.i = 0
Global gLastCtrlMs.q = 0
Global gCtrlDown.i = 0
Global gShortcutsFile.s
Global gMaxResults.i = 200
Global gWantToggle.i = 0
Global gHaveLastCtrl.i = 0
Global gAuto.i = 0
Global gRefocus.i = 0
Global gPrevLen.i = 0

Enumeration
  #Gadget_Search
  #Gadget_List
EndEnumeration

Enumeration
  #Image_Tray
EndEnumeration

Enumeration
  #Menu_Show
  #Menu_Quit
  #Menu_KeyLaunch
  #Menu_KeyEscape
  #Menu_KeyUp
  #Menu_KeyDown
EndEnumeration

Declare AddItem(name.s, path.s)
Declare ParseCsvLine(line.s, *row.CsvRow)
Declare.s CsvQuote(s.s)
Declare.s ExpandPath(p.s)
Declare.s ResolvePath(p.s)
Declare TryAutocomplete()
Declare IsDirPath(path.s)
Declare IndexStartMenu(dir.s)
Declare IndexStartMenus()
Declare SaveDefaultShortcuts(file.s)
Declare LoadShortcuts(file.s)
Declare ApplyFilter(query.s)
Declare MoveSelection(delta.i)
Declare LaunchSelected()
Declare ShowLauncher()
Declare HideLauncher()
Declare ToggleLauncher()
Declare QuitApp()
Declare.i KeyboardHook(nCode, wParam, lParam)
Declare.i WinCallback(hwnd, msg, wParam, lParam)

Procedure.s ExpandPath(p.s)
  Protected home.s, buf.s, n.i
  If Left(p, 1) = "~"
    home = GetEnvironmentVariable("USERPROFILE")
    If home = ""
      home = GetEnvironmentVariable("HOMEDRIVE") + GetEnvironmentVariable("HOMEPATH")
    EndIf
    If Len(p) = 1
      p = home
    ElseIf Mid(p, 2, 1) = "\" Or Mid(p, 2, 1) = "/"
      p = home + Mid(p, 2)
    EndIf
  EndIf
  buf = Space(2048)
  n = ExpandEnvironmentStrings_(@p, @buf, 2048)
  If n > 0 And n <= 2048
    ProcedureReturn Left(buf, n - 1)
  EndIf
  ProcedureReturn p
EndProcedure

Procedure.s ResolvePath(p.s)
  Protected root.s, rest.s, current.s, comp.s, cand.s, match.s
  Protected i.i, n.i, sep.i, cnt.i, dh.i, nm.s
  If p = "" : ProcedureReturn "" : EndIf
  If Mid(p, 2, 1) = ":"
    root = Left(p, 2) + "\"
    rest = Mid(p, 3)
  ElseIf Left(p, 2) = "\\"
    i = 3
    While i <= Len(p) And Mid(p, i, 1) <> "\" : i + 1 : Wend
    If i <= Len(p)
      i + 1
      While i <= Len(p) And Mid(p, i, 1) <> "\" : i + 1 : Wend
    EndIf
    If i > Len(p) : ProcedureReturn p : EndIf
    root = Left(p, i)
    rest = Mid(p, i + 1)
  Else
    ProcedureReturn p
  EndIf
  rest = ReplaceString(rest, "/", "\")
  current = root
  n = Len(rest)
  i = 1
  While i <= n
    sep = i
    While sep <= n And Mid(rest, sep, 1) <> "\" : sep + 1 : Wend
    comp = Mid(rest, i, sep - i)
    If comp <> ""
      cand = current + comp
      If GetFileAttributes_(@cand) <> #INVALID_ATTR
        current = cand
      Else
        match = ""
        cnt = 0
        dh = ExamineDirectory(#PB_Any, current, "*")
        If dh
          While NextDirectoryEntry(dh)
            nm = DirectoryEntryName(dh)
            If nm <> "." And nm <> ".."
              If Len(nm) >= Len(comp)
                If LCase(Left(nm, Len(comp))) = LCase(comp)
                  cnt + 1
                  match = nm
                EndIf
              EndIf
            EndIf
          Wend
          FinishDirectory(dh)
        EndIf
        If cnt <> 1 : ProcedureReturn p : EndIf
        current = current + match
      EndIf
      If sep <= n
        current = current + "\"
      EndIf
    EndIf
    i = sep + 1
  Wend
  ProcedureReturn current
EndProcedure

Procedure.i IsDirPath(path.s)
  Protected attr.i
  If path = "" : ProcedureReturn #False : EndIf
  attr = GetFileAttributes_(@path)
  If attr = #INVALID_ATTR : ProcedureReturn #False : EndIf
  If attr & #FILE_ATTRIBUTE_DIRECTORY
    ProcedureReturn #True
  EndIf
  ProcedureReturn #False
EndProcedure

Procedure AddItem(name.s, path.s)
  Protected i.i, key.s
  If name = "" Or path = "" : ProcedureReturn : EndIf
  key = LCase(name)
  For i = 0 To ItemCount - 1
    If LCase(Items(i)\Name) = key
      ProcedureReturn
    EndIf
  Next
  ItemCount + 1
  ReDim Items(ItemCount)
  Items(ItemCount - 1)\Name = name
  Items(ItemCount - 1)\Path = path
EndProcedure

Procedure IndexStartMenu(dir.s)
  Protected dh.i, name.s, full.s, ext.s, base.s
  If Not IsDirPath(dir) : ProcedureReturn : EndIf
  dh = ExamineDirectory(#PB_Any, dir, "*")
  If dh = 0 : ProcedureReturn : EndIf
  While NextDirectoryEntry(dh)
    name = DirectoryEntryName(dh)
    If name = "." Or name = ".." : Continue : EndIf
    full = dir + "\" + name
    If DirectoryEntryType(dh) = #PB_DirectoryEntry_Directory
      IndexStartMenu(full)
    Else
      ext = LCase(GetExtensionPart(name))
      If ext = "lnk" Or ext = "url" Or ext = "exe" Or ext = "bat" Or ext = "cmd"
        base = Left(name, Len(name) - Len(GetExtensionPart(name)) - 1)
        AddItem(base, full)
      EndIf
    EndIf
  Wend
  FinishDirectory(dh)
EndProcedure

Procedure IndexStartMenus()
  Protected pd.s = GetEnvironmentVariable("ProgramData")
  Protected ad.s = GetEnvironmentVariable("APPDATA")
  Protected up.s = GetEnvironmentVariable("USERPROFILE")
  Protected pub.s = GetEnvironmentVariable("PUBLIC")
  If pd <> "" : IndexStartMenu(pd + "\Microsoft\Windows\Start Menu\Programs") : EndIf
  If ad <> "" : IndexStartMenu(ad + "\Microsoft\Windows\Start Menu\Programs") : EndIf
  If up <> "" : IndexStartMenu(up + "\Desktop") : EndIf
  If pub <> "" : IndexStartMenu(pub + "\Desktop") : EndIf
EndProcedure

Procedure ParseCsvLine(line.s, *row.CsvRow)
  Protected i.i, n.i, field.i, inQ.i
  Protected c.s, val.s
  n = Len(line)
  i = 1
  field = 0
  val = ""
  While i <= n
    c = Mid(line, i, 1)
    If inQ
      If c = Chr(34)
        If i < n And Mid(line, i + 1, 1) = Chr(34)
          val + Chr(34)
          i + 2
          Continue
        EndIf
        inQ = 0
        i + 1
      Else
        val + c
        i + 1
      EndIf
    Else
      If c = Chr(34)
        inQ = 1
        i + 1
      ElseIf c = ","
        If field = 0
          *row\Name = val
          val = ""
          field = 1
        Else
          val + c
        EndIf
        i + 1
      Else
        val + c
        i + 1
      EndIf
    EndIf
  Wend
  If field = 0
    *row\Name = val
  Else
    *row\Path = val
  EndIf
EndProcedure

Procedure.s CsvQuote(s.s)
  ProcedureReturn Chr(34) + ReplaceString(s, Chr(34), Chr(34) + Chr(34)) + Chr(34)
EndProcedure

Procedure SaveDefaultShortcuts(file.s)
  Protected f.i, nl.s = Chr(13) + Chr(10), out.s
  If FileSize(file) >= 0 : ProcedureReturn : EndIf
  f = CreateFile(#PB_Any, file)
  If f = 0 : ProcedureReturn : EndIf
  out + CsvQuote("name") + "," + CsvQuote("path") + nl
  out + CsvQuote("Notepad") + "," + CsvQuote("C:\Windows\notepad.exe") + nl
  out + CsvQuote("Calculator") + "," + CsvQuote("C:\Windows\System32\calc.exe") + nl
  out + CsvQuote("Command Prompt") + "," + CsvQuote("C:\Windows\System32\cmd.exe") + nl
  out + CsvQuote("Projects") + "," + CsvQuote("C:\Projects") + nl
  WriteString(f, out, #PB_UTF8)
  CloseFile(f)
EndProcedure

Procedure LoadShortcuts(file.s)
  Protected f.i, line.s
  Protected row.CsvRow
  If FileSize(file) <= 0 : ProcedureReturn : EndIf
  f = ReadFile(#PB_Any, file)
  If f = 0 : ProcedureReturn : EndIf
  While Not Eof(f)
    line = ReadString(f, #PB_UTF8)
    If Left(line, 1) = Chr(65279)
      line = Mid(line, 2)
    EndIf
    row\Name = ""
    row\Path = ""
    ParseCsvLine(line, @row)
    row\Name = Trim(row\Name)
    row\Path = Trim(row\Path)
    If LCase(row\Name) <> "name" And row\Name <> "" And row\Path <> ""
      AddItem(row\Name, row\Path)
    EndIf
  Wend
  CloseFile(f)
EndProcedure

Procedure ApplyFilter(query.s)
  Protected q.s = LCase(Trim(query))
  Protected i.i, shown.i = 0
  ClearGadgetItems(#Gadget_List)
  DisplayedCount = 0
  For i = 0 To ItemCount - 1
    If q = "" Or FindString(LCase(Items(i)\Name), q, 1) > 0
      AddGadgetItem(#Gadget_List, -1, Items(i)\Name)
      DisplayedIdx(shown) = i
      shown + 1
      If shown >= gMaxResults : Break : EndIf
    EndIf
  Next
  DisplayedCount = shown
  If shown > 0
    SetGadgetState(#Gadget_List, 0)
  EndIf
EndProcedure

Procedure TryAutocomplete()
  Protected t.s = GetGadgetText(#Gadget_Search)
  Protected r.s, extra.s, prefix.s, base.s, full.s
  If t = "" Or gAuto : ProcedureReturn : EndIf
  If Left(t, 1) = ">"
    prefix = ">"
    base = Mid(t, 2)
  Else
    base = t
  EndIf
  If Not (Mid(base, 2, 1) = ":" Or Left(base, 2) = "\\") : ProcedureReturn : EndIf
  r = ResolvePath(base)
  If r <> "" And Len(r) > Len(base) And LCase(Left(r, Len(base))) = LCase(base)
    extra = Mid(r, Len(base) + 1)
    If ReplaceString(ReplaceString(extra, "\", ""), "/", "") = "" : ProcedureReturn : EndIf
    full = prefix + r
    gAuto = 1
    SetGadgetText(#Gadget_Search, full)
    gAuto = 0
    SendMessage_(GadgetID(#Gadget_Search), $B1, Len(prefix) + Len(base), Len(full))
  EndIf
EndProcedure

Procedure MoveSelection(delta.i)
  Protected cnt.i = CountGadgetItems(#Gadget_List)
  Protected cur.i
  If cnt = 0 : ProcedureReturn : EndIf
  cur = GetGadgetState(#Gadget_List)
  If cur < 0 : cur = 0 : EndIf
  cur + delta
  If cur < 0 : cur = cnt - 1 : ElseIf cur >= cnt : cur = 0 : EndIf
  SetGadgetState(#Gadget_List, cur)
EndProcedure

Procedure LaunchSelected()
  Protected idx.i, it.i, path.s, q.s, attr.i, cmdMode.i, cwd.s
  q = Trim(GetGadgetText(#Gadget_Search))
  If Left(q, 1) = ">"
    cmdMode = 1
    q = Trim(Mid(q, 2))
  EndIf
  If cmdMode
    cwd = ""
    If q <> ""
      q = ResolvePath(ExpandPath(q))
      attr = GetFileAttributes_(@q)
      If attr <> #INVALID_ATTR
        If attr & #FILE_ATTRIBUTE_DIRECTORY
          cwd = q
        Else
          cwd = GetPathPart(q)
        EndIf
      EndIf
    EndIf
    If cwd = "" : cwd = GetEnvironmentVariable("USERPROFILE") : EndIf
    HideLauncher()
    RunProgram("cmd.exe", "", cwd)
    ProcedureReturn
  EndIf
  If q <> ""
    q = ResolvePath(ExpandPath(q))
    attr = GetFileAttributes_(@q)
    If attr <> #INVALID_ATTR
      HideLauncher()
      If attr & #FILE_ATTRIBUTE_DIRECTORY
        RunProgram("explorer.exe", #DQUOTE$ + q + #DQUOTE$, "")
      Else
        ShellExecute_(0, "open", @q, 0, 0, #SW_SHOWNORMAL)
      EndIf
      ProcedureReturn
    EndIf
  EndIf
  idx = GetGadgetState(#Gadget_List)
  If idx < 0 Or idx >= DisplayedCount : ProcedureReturn : EndIf
  it = DisplayedIdx(idx)
  path = Items(it)\Path
  If path = "" : ProcedureReturn : EndIf
  HideLauncher()
  If IsDirPath(path)
    RunProgram("explorer.exe", #DQUOTE$ + path + #DQUOTE$, "")
  Else
    ShellExecute_(0, "open", @path, 0, 0, #SW_SHOWNORMAL)
  EndIf
EndProcedure

Procedure ShowLauncher()
  Protected hwnd.i = WindowID(0)
  Protected fgThread.i, ourThread.i, attached.i = 0
  SetGadgetText(#Gadget_Search, "")
  gPrevLen = 0
  ApplyFilter("")
  HideWindow(0, #False)
  StickyWindow(0, #True)
  fgThread = GetWindowThreadProcessId_(GetForegroundWindow_(), 0)
  ourThread = GetCurrentThreadId_()
  If fgThread <> 0 And fgThread <> ourThread
    attached = AttachThreadInput_(ourThread, fgThread, #True)
  EndIf
  BringWindowToTop_(hwnd)
  SetForegroundWindow_(hwnd)
  SetActiveGadget(#Gadget_Search)
  SetFocus_(GadgetID(#Gadget_Search))
  If attached
    AttachThreadInput_(ourThread, fgThread, #False)
  EndIf
  gRefocus = 1
EndProcedure

Procedure HideLauncher()
  HideWindow(0, #True)
EndProcedure

Procedure ToggleLauncher()
  If IsWindowVisible_(WindowID(0))
    HideLauncher()
  Else
    ShowLauncher()
  EndIf
EndProcedure

Procedure QuitApp()
  If gHook <> 0
    UnhookWindowsHookEx_(gHook)
    gHook = 0
  EndIf
  RemoveSysTrayIcon(0)
  End
EndProcedure

Procedure.i KeyboardHook(nCode, wParam, lParam)
  Protected now.q
  Protected *kb.KBDLLHOOKSTRUCT
  If nCode = 0
    *kb = lParam
    If *kb\vkCode = #VK_LCONTROL Or *kb\vkCode = #VK_RCONTROL Or *kb\vkCode = #VK_CONTROL
      If wParam = #WM_KEYDOWN Or wParam = #WM_SYSKEYDOWN
        If gCtrlDown = 0
          gCtrlDown = 1
          now = GetTickCount_()
          If gHaveLastCtrl And (now - gLastCtrlMs) <= 450
            gHaveLastCtrl = 0
            gWantToggle = 1
          Else
            gLastCtrlMs = now
            gHaveLastCtrl = 1
          EndIf
        EndIf
      ElseIf wParam = #WM_KEYUP Or wParam = #WM_SYSKEYUP
        gCtrlDown = 0
      EndIf
    ElseIf wParam = #WM_KEYDOWN Or wParam = #WM_SYSKEYDOWN
      gHaveLastCtrl = 0
    EndIf
  EndIf
  ProcedureReturn CallNextHookEx_(0, nCode, wParam, lParam)
EndProcedure

Procedure.i WinCallback(hwnd, msg, wParam, lParam)
  Select msg
    Case #WM_KEYDOWN, #WM_SYSKEYDOWN
      Select wParam
        Case #VK_RETURN
          LaunchSelected()
          ProcedureReturn 0
        Case #VK_ESCAPE
          HideLauncher()
          ProcedureReturn 0
        Case #VK_UP
          MoveSelection(-1)
          ProcedureReturn 0
        Case #VK_DOWN
          MoveSelection(1)
          ProcedureReturn 0
      EndSelect
  EndSelect
  ProcedureReturn #PB_ProcessPureBasicEvents
EndProcedure

Define dW.i = 0, dH.i = 0, dX.i = 0, dY.i = 0
Define WW.i = 640, WH.i = 400, wx.i, wy.i
Define fnt.i, fnt2.i, ev.i, hMutex.i

hMutex = CreateMutex_(0, #True, "KeyLauncher_SingleInstance_9C4F1A")
If GetLastError_() = 183
  End
EndIf

If ExamineDesktops()
  dW = DesktopWidth(0)
  dH = DesktopHeight(0)
  dX = DesktopX(0)
  dY = DesktopY(0)
EndIf
wx = dX + (dW - WW) / 2
wy = dY + dH / 4

If OpenWindow(0, wx, wy, WW, WH, "KeyLauncher", #PB_Window_BorderLess | #PB_Window_Invisible)
  SetWindowCallback(@WinCallback())

  AddWindowTimer(0, 1, 100)
  AddKeyboardShortcut(0, #PB_Shortcut_Return, #Menu_KeyLaunch)
  AddKeyboardShortcut(0, #PB_Shortcut_Escape, #Menu_KeyEscape)
  AddKeyboardShortcut(0, #PB_Shortcut_Up, #Menu_KeyUp)
  AddKeyboardShortcut(0, #PB_Shortcut_Down, #Menu_KeyDown)

  StringGadget(#Gadget_Search, 12, 12, WW - 24, 40, "")
  ListViewGadget(#Gadget_List, 12, 64, WW - 24, WH - 76)
  fnt = LoadFont(#PB_Any, "Segoe UI", 18)
  If fnt <> 0 : SetGadgetFont(#Gadget_Search, FontID(fnt)) : EndIf
  fnt2 = LoadFont(#PB_Any, "Segoe UI", 14)
  If fnt2 <> 0 : SetGadgetFont(#Gadget_List, FontID(fnt2)) : EndIf

  CreatePopupMenu(0)
  MenuItem(#Menu_Show, "Show Launcher  (Ctrl x2)")
  MenuItem(#Menu_Quit, "Exit")

  CreateImage(#Image_Tray, 32, 32)
  If StartDrawing(ImageOutput(#Image_Tray))
    DrawingMode(#PB_2DDrawing_AllChannels)
    Box(0, 0, 32, 32, RGBA(0, 0, 0, 0))
    Circle(13, 12, 9, RGBA(31, 119, 203, 255))
    Circle(13, 12, 6, RGBA(0, 0, 0, 0))
    LineXY(19, 18, 27, 26, RGBA(31, 119, 203, 255))
    LineXY(20, 17, 28, 25, RGBA(31, 119, 203, 255))
    LineXY(21, 16, 28, 23, RGBA(31, 119, 203, 255))
    StopDrawing()
  EndIf
  AddSysTrayIcon(0, WindowID(0), ImageID(#Image_Tray))
  SysTrayIconToolTip(0, "KeyLauncher - press Ctrl twice")

  gShortcutsFile = GetPathPart(ProgramFilename()) + "shortcuts.cfg"
  SaveDefaultShortcuts(gShortcutsFile)
  IndexStartMenus()
  LoadShortcuts(gShortcutsFile)
  SortStructuredArray(Items(), #PB_Sort_Ascending, OffsetOf(Entry\Name), #PB_String)
  If ItemCount < gMaxResults
    ReDim DisplayedIdx(gMaxResults)
  Else
    ReDim DisplayedIdx(ItemCount + 1)
  EndIf
  ApplyFilter("")

  gHook = SetWindowsHookEx_(#WH_KEYBOARD_LL, @KeyboardHook(), GetModuleHandle_(0), 0)
  If gHook = 0
    MessageRequester("KeyLauncher", "Failed to install the global keyboard hook.")
  EndIf
Else
  MessageRequester("KeyLauncher", "Failed to create the launcher window.")
EndIf

Repeat
  ev = WaitWindowEvent()
  Select ev
    Case #PB_Event_Timer
      If EventTimer() = 1 And gWantToggle
        gWantToggle = 0
        ToggleLauncher()
      EndIf
      If EventTimer() = 1 And gRefocus
        gRefocus = 0
        SetActiveGadget(#Gadget_Search)
        SetFocus_(GadgetID(#Gadget_Search))
      EndIf
    Case #PB_Event_Gadget
      Select EventGadget()
        Case #Gadget_Search
          If EventType() = #PB_EventType_Change
            If gAuto = 0 And Len(GetGadgetText(#Gadget_Search)) > gPrevLen
              TryAutocomplete()
            EndIf
            ApplyFilter(GetGadgetText(#Gadget_Search))
            gPrevLen = Len(GetGadgetText(#Gadget_Search))
          EndIf
        Case #Gadget_List
          If EventType() = #PB_EventType_LeftClick Or EventType() = #PB_EventType_LeftDoubleClick
            LaunchSelected()
          EndIf
      EndSelect
    Case #PB_Event_Menu
      Select EventMenu()
        Case #Menu_Show : ShowLauncher()
        Case #Menu_Quit : QuitApp()
        Case #Menu_KeyLaunch : LaunchSelected()
        Case #Menu_KeyEscape : HideLauncher()
        Case #Menu_KeyUp : MoveSelection(-1)
        Case #Menu_KeyDown : MoveSelection(1)
      EndSelect
    Case #PB_Event_SysTray
      If EventType() = #PB_EventType_RightClick
        DisplayPopupMenu(0, WindowID(0))
      ElseIf EventType() = #PB_EventType_LeftClick
        ShowLauncher()
      EndIf
    Case #PB_Event_CloseWindow
      HideLauncher()
  EndSelect
ForEver
