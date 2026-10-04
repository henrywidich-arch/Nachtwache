# Starts a program on a second, invisible Windows desktop and waits for it.
# Used for Godot runs that need a real window to draw pictures (the screenshot checks):
# the window is created on a desktop nobody sees, so nothing appears on the screen, no
# other window loses the keyboard, and a game running in full screen is not interrupted.
#
#   powershell -ExecutionPolicy Bypass -File tools\run_hidden.ps1 -Program <exe> -Arguments '<arguments>' [-Folder <working folder>] [-Seconds 200]
#
# The exit code is the program's own; 124 if it had to be stopped after -Seconds.
# For Godot, add --log-file <file> to the arguments to get its output.
param(
    [Parameter(Mandatory = $true)][string]$Program,
    [string]$Arguments = "",
    [string]$Folder = (Get-Location).Path,
    [int]$Seconds = 200,
    [string]$Desktop = "NachtwachePruefung"
)
$source = @"
using System;
using System.ComponentModel;
using System.Runtime.InteropServices;
using System.Text;
public static class HiddenDesktop {
    [DllImport("user32.dll", SetLastError = true, CharSet = CharSet.Unicode)]
    static extern IntPtr CreateDesktop(string name, IntPtr device, IntPtr devmode, int flags, uint access, IntPtr security);
    [DllImport("user32.dll", SetLastError = true)]
    static extern bool CloseDesktop(IntPtr desktop);
    [StructLayout(LayoutKind.Sequential, CharSet = CharSet.Unicode)]
    struct STARTUPINFO {
        public int cb; public string lpReserved; public string lpDesktop; public string lpTitle;
        public int dwX, dwY, dwXSize, dwYSize, dwXCountChars, dwYCountChars, dwFillAttribute, dwFlags;
        public short wShowWindow, cbReserved2; public IntPtr lpReserved2, hStdInput, hStdOutput, hStdError;
    }
    [StructLayout(LayoutKind.Sequential)]
    struct PROCESS_INFORMATION { public IntPtr hProcess, hThread; public int dwProcessId, dwThreadId; }
    [DllImport("kernel32.dll", SetLastError = true, CharSet = CharSet.Unicode)]
    static extern bool CreateProcess(string application, StringBuilder commandLine, IntPtr processAttributes, IntPtr threadAttributes, bool inherit, uint flags, IntPtr environment, string folder, ref STARTUPINFO startup, out PROCESS_INFORMATION information);
    [DllImport("kernel32.dll")] static extern uint WaitForSingleObject(IntPtr handle, uint milliseconds);
    [DllImport("kernel32.dll")] static extern bool GetExitCodeProcess(IntPtr handle, out uint code);
    [DllImport("kernel32.dll")] static extern bool TerminateProcess(IntPtr handle, uint code);
    [DllImport("kernel32.dll")] static extern bool CloseHandle(IntPtr handle);

    public static int Run(string commandLine, string folder, string desktop, int milliseconds) {
        const uint GENERIC_ALL = 0x10000000;
        IntPtr place = CreateDesktop(desktop, IntPtr.Zero, IntPtr.Zero, 0, GENERIC_ALL, IntPtr.Zero);
        if (place == IntPtr.Zero) throw new Win32Exception(Marshal.GetLastWin32Error());
        try {
            STARTUPINFO startup = new STARTUPINFO();
            startup.cb = Marshal.SizeOf(typeof(STARTUPINFO));
            startup.lpDesktop = desktop;
            PROCESS_INFORMATION information;
            if (!CreateProcess(null, new StringBuilder(commandLine), IntPtr.Zero, IntPtr.Zero, false, 0, IntPtr.Zero, folder, ref startup, out information))
                throw new Win32Exception(Marshal.GetLastWin32Error());
            uint code = 0;
            if (WaitForSingleObject(information.hProcess, (uint)milliseconds) != 0) {
                TerminateProcess(information.hProcess, 124);
                code = 124;
            } else {
                GetExitCodeProcess(information.hProcess, out code);
            }
            CloseHandle(information.hThread);
            CloseHandle(information.hProcess);
            return (int)code;
        } finally {
            CloseDesktop(place);
        }
    }
}
"@
Add-Type -TypeDefinition $source
$line = '"' + $Program + '" ' + $Arguments
$code = [HiddenDesktop]::Run($line, $Folder, $Desktop, $Seconds * 1000)
exit $code
