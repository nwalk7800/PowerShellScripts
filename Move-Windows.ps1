﻿param (
    [ValidateSet('Single','Dual')]
    $Mode
)

Function AddWindowType {
    Try{
        [void][Window]
    } Catch {
    Add-Type @"
            using System;
            using System.Drawing;
            using System.Runtime.InteropServices;

            public class Window {
                [DllImport("user32.dll", SetLastError = true)]
                [return: MarshalAs(UnmanagedType.Bool)]
                internal static extern bool GetWindowPlacement(IntPtr hWnd, ref WINDOWPLACEMENT lpwndpl);
            
                [DllImport("user32.dll", SetLastError = true)]
                [return: MarshalAs(UnmanagedType.Bool)]
                internal static extern bool SetWindowPlacement(IntPtr hWnd, ref WINDOWPLACEMENT lpwndpl);

                [DllImport("user32.dll", SetLastError = true)]
                [return: MarshalAs(UnmanagedType.Bool)]
                static extern bool SetWindowPos(IntPtr hWnd, IntPtr hWndInsertAfter, int X, int Y, int cx, int cy, UInt32 uFlags);

                [DllImport("user32.dll", SetLastError = true)]
                private static extern IntPtr GetWindow(IntPtr hWnd, int uCmd);

                [DllImport("user32.dll")]
                static extern IntPtr GetTopWindow(IntPtr hWnd);

                [DllImport("user32.dll", SetLastError = false)]
                static extern IntPtr GetDesktopWindow();

                public const int SWP_NOSIZE = 0x0001;
                public const int SWP_NOACTIVATE = 0x0010;
                public const int SWP_NOZORDER = 0x0004;

                public const int GW_HWNDLAST = 1;
                public const int GW_HWNDNEXT = 2;
                public const int GW_HWNDPREV = 3;

                public static IntPtr GetTop() {
                    return GetTopWindow(GetDesktopWindow());
                }

                public static IntPtr GetBottom() {
                    IntPtr window = GetTopWindow(GetDesktopWindow());
                    return GetWindow(window, GW_HWNDLAST);
                }

                public static IntPtr GetPrev(IntPtr hWnd) {
                    return GetWindow(hWnd, GW_HWNDPREV);
                }

                public static IntPtr GetNext(IntPtr hWnd) {
                    return GetWindow(hWnd, GW_HWNDNEXT);
                }

                public static WINDOWPLACEMENT GetPlacement(IntPtr hwnd)
                {
                    WINDOWPLACEMENT placement = new WINDOWPLACEMENT();
                    placement.length = Marshal.SizeOf(placement);
                    GetWindowPlacement(hwnd, ref placement);
                    return placement;
                }

                public static int SetPlacement(IntPtr hWnd, ref WINDOWPLACEMENT lpwndpl, int x, int y, int width)
                {
                    int retval = 0;

                    ShowWindowCommands showCmd = lpwndpl.showCmd;

                    lpwndpl.rcNormalPosition.X = x;
                    lpwndpl.rcNormalPosition.Y = y;
                    lpwndpl.rcNormalPosition.Width = width;
                    lpwndpl.showCmd = ShowWindowCommands.Normal;
                        
                    if (SetWindowPlacement(hWnd, ref lpwndpl)) {retval |= 1;}

                    if (showCmd != lpwndpl.showCmd) {
                        lpwndpl.showCmd = showCmd;
                        if (SetWindowPlacement(hWnd, ref lpwndpl)) {retval |= 2;}
                    }

                    return retval;
                }

                public static int SetPos(IntPtr hWnd, IntPtr hWndInsertAfter, ref WINDOWPLACEMENT lpwndpl)
                {
                    int retval = 0;

                    SetWindowPos(hWnd, hWndInsertAfter, lpwndpl.rcNormalPosition.X, lpwndpl.rcNormalPosition.Y, 0, 0, SWP_NOSIZE | SWP_NOACTIVATE);

                    return retval;
                }
            }
            
            [Serializable]
            [StructLayout(LayoutKind.Sequential)]
            public struct WINDOWPLACEMENT
            {
                public int length;
                public int flags;
                public ShowWindowCommands showCmd;
                public System.Drawing.Point ptMinPosition;
                public System.Drawing.Point ptMaxPosition;
                public System.Drawing.Rectangle rcNormalPosition;
            }

            [StructLayout(LayoutKind.Sequential)]
            public struct RECT
            {
                    public int Left;        // x position of upper-left corner
                    public int Top;         // y position of upper-left corner
                    public int Right;       // x position of lower-right corner
                    public int Bottom;      // y position of lower-right corner
            }

            public enum ShowWindowCommands : int
            {
                Hide = 0,
                Normal = 1,
                Minimized = 2,
                Maximized = 3,
            }
"@ -ReferencedAssemblies "System.Drawing.dll"
    }
}

function ConvertPosition {
    param (
        $Process,
        $Monitor
    )

    $X = $Process.Placement.rcNormalPosition.X
    $Y = $Process.Placement.rcNormalPosition.Y
    
    $Width = $Process.Placement.rcNormalPosition.Width - $X
    
    if ($Width -lt 50) {$Width = 50}

    if ($X -ge 0 -and $Monitor -eq 2) {
        $X -= 1680
        if ($Y -le (1080 - 1050)) {$Y = 1080 - 1050}
        if ($X -lt -1680) {$X = -1680}
    } elseif ($X -lt 0 -and $Monitor -eq 1) {
        $X += 1680
        if ($Y -le (1080 - 1050)) {$Y = 0}
        if ($X -gt 1920) {$X = 1920 - 50}
    }

    @{X = $X
      Y = $Y
      Width = $X + $Width
    }
}

Function Move-Windows {
    [CmdletBinding(SupportsShouldProcess)]
    param (
        $Monitor
    )

    AddWindowType
    $Windows = Get-Process | Where-Object {$_.MainWindowHandle -ne 0} | select Name,MainWindowTitle,MainWindowHandle,@{n="PLACEMENT";e={[window]::GetPlacement($_.MainWindowHandle)}}
    $NewPos = $Windows | ?{$_.MainWindowTitle -ne "Destiny 2"} | select Name,MainWindowTitle,MainWindowHandle,PLACEMENT,@{n="Position"; e={ConvertPosition -Process $_ -Monitor $Monitor}}
    $NewPos | %{
        if ($PSCmdlet.ShouldProcess($_.MainWindowTitle, "Move Window")) {
            $Result = [window]::SetPlacement($_.MainWindowHandle, [ref]$_.PLACEMENT, $_.Position.X, $_.Position.Y, $_.Position.Width)
            Write-Verbose "$Result $($_.Name) $($_.MainWindowTitle)"
        }
    }
}

function Set-WindowPosition {
    param (
        $Windows
    )

    $Previous = 0
    foreach ($Window in $Windows) {
        #$Result = [window]::SetPos($Window.MainWindowHandle, $Previous, [ref]$Window.PLACEMENT, $Window.PLACEMENT.rcNormalPosition.X, $Window.PLACEMENT.rcNormalPosition.Y, $Window.PLACEMENT.rcNormalPosition.Width)
        $Window
        $Result = [window]::SetPos($Window.MainWindowHandle, $Previous, [ref]$Window.PLACEMENT)
        if ($Result -ne 0) {
            Write-Host "$($Window.Name): $(([System.ComponentModel.Win32Exception][System.Runtime.InteropServices.Marshal]::GetLastWin32Error()).Message)"
        }
        $Previous = $Window.MainWindowHandle
    }
}

function Get-WindowPosition {
    $Processes = Get-Process | ?{$_.MainWindowHandle -ne 0}
    
    $Windows = @()
    $Handle = [window]::GetNext([window]::GetTop())
    do {
        $Process = $Processes | ? MainWindowHandle -eq $Handle
        if ($Process) {
            $Windows += $Process | select Name,MainWindowTitle,MainWindowHandle,@{n="PLACEMENT";e={[window]::GetPlacement($_.MainWindowHandle)}}
        }
        $Handle = [window]::GetNext($Handle)
    } while ($Handle -ne 0)

    $Windows
}

Function GetMonitorCount {
    [System.Windows.Forms.Screen]::AllScreens.Count
}

AddWindowType

if ($MyInvocation.InvocationName -ne ".") {
    $sysevent = [microsoft.win32.systemevents]
    Register-ObjectEvent -InputObject $sysevent -EventName "SessionSwitch" -Action {
        
        if (($args[1]).Reason -eq 'SessionLock') {
            Write-Host "Saving Window positions"
            $Windows = Get-WindowPosition
        }
        if (($args[1]).Reason -eq 'SessionUnlock') {
            Write-Host "Setting Window positions"
            Set-WindowPosition -Windows $Windows
        }
    }
}