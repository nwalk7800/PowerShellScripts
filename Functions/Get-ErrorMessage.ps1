function Get-ErrorMessage
{
    [OutputType('System.String')]
    [CmdletBinding()]
     param
     (
        [Parameter(Mandatory = $true)] 
        [int]$ErrorCode
     )
     
     $signature = @'
        [DllImport("kernel32.dll", SetLastError=true)]
        public static extern uint FormatMessage(
            uint dwFlags,
            IntPtr lpSource,
            int dwMessageId,
            uint dwLanguageId,
            ref IntPtr lpBuffer,
            uint nSize,
            IntPtr Arguments
        );
        
        [DllImport("kernel32.dll", SetLastError=true, CharSet=CharSet.Auto)]
        public static extern IntPtr LoadLibrary(
            string lpFileName
        );
        
        [DllImport("kernel32.dll", SetLastError=true, CharSet=CharSet.Auto)]
        public static extern bool FreeLibrary(
            IntPtr hModule
        );
        
        [DllImport("kernel32.dll", SetLastError=true, CharSet=CharSet.Auto)]
        public static extern IntPtr LocalFree(
            IntPtr hMem
        );
'@

    try
    {
        Add-Type -MemberDefinition $signature -Name Kernel32 -Namespace PKI
    }
    catch
    {
        Write-Warning $Error[0].Exception.Message
        return
    }
    
    $StartBase = 12000
    $EndBase = 12176
    $ErrorHex = "{0:x8}" -f $ErrorCode
    $HighBytes = iex 0x$($ErrorHex.Substring(0,4))
    $LowBytes = iex 0x$($ErrorHex.Substring(4,4))
    $lpMsgBuf = [IntPtr]::Zero
    if ($LowBytes -gt $StartBase -and $LowBytes -lt $EndBase)
    {
        $hModule = [PKI.Kernel32]::LoadLibrary("wininet.dll")
        $dwChars = [PKI.Kernel32]::FormatMessage(0xb00,$hModule,$LowBytes,0,[ref]$lpMsgBuf,0,[IntPtr]::Zero)
        [void][PKI.Kernel32]::FreeLibrary($hModule)
    }
    else
    {
        $dwChars = [PKI.Kernel32]::FormatMessage(0x1300,[IntPtr]::Zero,$ErrorCode,0,[ref]$lpMsgBuf,0,[IntPtr]::Zero)
    }
    
    if ($dwChars -ne 0)
    {
        ([Runtime.InteropServices.Marshal]::PtrToStringAnsi($lpMsgBuf)).Trim()
        [void][PKI.Kernel32]::LocalFree($lpMsgBuf)
    }
    else
    {
        Write-Error -Category ObjectNotFound -ErrorId "ElementNotFoundException" -Message "No error messages are assoicated with error code: 0x$ErrorHex ($ErrorCode). Operation failed."
    }
}