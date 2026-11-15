; usb-kvm - make the monitors follow a USB keyboard switch
; https://github.com/0l0-app/usb-kvm
#Requires AutoHotkey v2.0
#SingleInstance Force
Persistent

HOME_PC := "HOME-PC-NAME"  ; A_ComputerName of the home PC; any other PC is treated as work

; Some keyboards enumerate under more than one PID depending on how the switch hands them over
KEYBOARD_IDS := ["USB\VID_04D9&PID_0207\", "USB\VID_04D9&PID_1207\"]

; Monitor serial numbers (identical on both PCs, since they are the same monitors)
BENQ_A := "BENQ-SERIAL-1"
BENQ_B := "BENQ-SERIAL-2"
DELL   := "DELL-SERIAL"

; VCP 60 input values; the Dell needs the 16-bit form
INPUTS := Map(
    "home", Map(BENQ_A, 17, BENQ_B, 17, DELL, 3855),  ; HDMI 1, HDMI 1, DisplayPort
    "work", Map(BENQ_A, 3,  BENQ_B, 3,  DELL, 4369)   ; DVI,    DVI,    HDMI
)

ThisPC  := (A_ComputerName = HOME_PC) ? "home" : "work"
OtherPC := (ThisPC = "home") ? "work" : "home"
CMM     := A_ScriptDir "\ControlMyMonitor.exe"
LogPath := A_ScriptDir "\usb-kvm.log"

KeyboardHere := KeyboardPresent()
Log("started as " ThisPC ", keyboard " (KeyboardHere ? "present" : "absent"))

OnMessage(0x0219, (*) => SetTimer(CheckKeyboard, -500))  ; WM_DEVICECHANGE
SetTimer(CheckKeyboard, 2000)  ; fallback in case a device-change broadcast is missed

; Manual overrides
^!F9::SwitchTo(OtherPC, "hotkey")
^!F10::SwitchTo(ThisPC, "hotkey")

CheckKeyboard() {
    global KeyboardHere
    if (KeyboardPresent() = KeyboardHere)
        return
    ; USB devices blink out briefly around sleep/resume; only act on a change that sticks
    Sleep(1000)
    now := KeyboardPresent()
    if (now = KeyboardHere)
        return
    KeyboardHere := now
    ; Many monitors only accept DDC/CI from the PC they are showing, so the PC
    ; being left does the real work; the arriving PC's attempt is best-effort.
    if now
        SwitchTo(ThisPC, "keyboard connected")
    else
        SwitchTo(OtherPC, "keyboard disconnected")
}

KeyboardPresent() {
    static wmi := ComObjGet("winmgmts:")
    for dev in wmi.ExecQuery("SELECT DeviceID FROM Win32_PnPEntity WHERE DeviceID LIKE 'USB\\VID_%'")
        for id in KEYBOARD_IDS
            if (InStr(dev.DeviceID, id) = 1)
                return true
    return false
}

SwitchTo(pc, reason) {
    args := ""
    for serial, value in INPUTS[pc]
        args .= ' /SetValue "' serial '" 60 ' value
    code := RunWait('"' CMM '"' args, , "Hide")
    Log(reason " -> " pc " inputs (exit " code ")")
}

Log(msg) {
    FileAppend(FormatTime(, "yyyy-MM-dd HH:mm:ss") "  " msg "`n", LogPath)
}
