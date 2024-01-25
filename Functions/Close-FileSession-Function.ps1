$signature = @'
using System;
using System.Collections.Generic;
using System.Management.Automation;
using System.Runtime.InteropServices;

public class Win32Api
{
    [DllImport("Netapi32.dll", CharSet = CharSet.Unicode, SetLastError = true)]
    public static extern int NetFileClose([MarshalAs(UnmanagedType.LPWStr)] string ServerName, int id);
    
    [DllImport("Netapi32.dll", SetLastError = true)]
    private static extern int NetApiBufferFree(IntPtr buffer);

    [DllImport("Netapi32.dll", CharSet = CharSet.Unicode, SetLastError = true)]
    private static extern int NetDfsGetClientInfo
    (
    [MarshalAs(UnmanagedType.LPWStr)] string EntryPath,
    [MarshalAs(UnmanagedType.LPWStr)] string ServerName,
    [MarshalAs(UnmanagedType.LPWStr)] string ShareName,
    int Level,
    ref IntPtr Buffer
    );

    public struct DFS_INFO_3
    {
        [MarshalAs(UnmanagedType.LPWStr)]
        public string EntryPath;
        [MarshalAs(UnmanagedType.LPWStr)]
        public string Comment;
        public UInt32 State;
        public UInt32 NumberOfStorages;
        public IntPtr Storages;
    }
    public struct DFS_STORAGE_INFO
    {
        public Int32 State;
        [MarshalAs(UnmanagedType.LPWStr)]
        public string ServerName;
        [MarshalAs(UnmanagedType.LPWStr)]
        public string ShareName;
    }

    public static List<PSObject> NetDfsGetClientInfo(string DfsPath)
    {
        IntPtr buffer = new IntPtr();
        List<PSObject> returnList = new List<PSObject>();

        try
        {
            int result = NetDfsGetClientInfo(DfsPath, null, null, 3, ref buffer);

            if (result != 0)
            {
                throw (new SystemException("Error getting DFS information"));
            }
            else
            {
                DFS_INFO_3 dfsInfo = (DFS_INFO_3)Marshal.PtrToStructure(buffer, typeof(DFS_INFO_3));

                for (int i = 0; i < dfsInfo.NumberOfStorages; i++)
                {
                    IntPtr storage = new IntPtr(dfsInfo.Storages.ToInt64() + i * Marshal.SizeOf(typeof(DFS_STORAGE_INFO)));

                    DFS_STORAGE_INFO storageInfo = (DFS_STORAGE_INFO)Marshal.PtrToStructure(storage, typeof(DFS_STORAGE_INFO));

                    PSObject psObject = new PSObject();

                    psObject.Properties.Add(new PSNoteProperty("State", storageInfo.State));
                    psObject.Properties.Add(new PSNoteProperty("ServerName", storageInfo.ServerName));
                    psObject.Properties.Add(new PSNoteProperty("ShareName", storageInfo.ShareName));

                    returnList.Add(psObject);
                }
            }
        }
        catch (Exception e)
        {
            throw(e);
        }
        finally
        {
            NetApiBufferFree(buffer);
        }
        return returnList;
    }
}
'@

if (-not ('DFSFunctions' -as [Type])) {
    Add-Type -TypeDefinition $signature
}

Function Get-DFSDetails {
<# 
    .SYNOPSIS   
        Gets DFS details for a UNC path.

    .DESCRIPTION
        The Get-DFSDetails CmdLet gets DFS details like DFS Server name, DFS Share name and the local path on the DFS Server for a specific UNC path.

    .PARAMETER Credentials 
        PowerShell credential object used to connect to the DFS Server to retrieve the local path on the server.

    .PARAMETER Path 
        Specifies a UNC path for the folder.

    .EXAMPLE
        Get-DFSDetails -Path '\\domain.net\HOME\Bob' -Credentials $Credentials
        Gets the DFS details for the UNC path '\\domain.net\HOME\Bob'

        Path         : \\domain.net\HOME\Bob
        ComputerName : SERVER1.DOMAIN.NET
        ComputerPath : E:\HOME\Bob
        ShareName    : HOME

    .EXAMPLE
        '\\domain.net\HOME\Mike', '\\domain.net\HOME\Jake' | Get-DFSDetails -Credentials $Credentials
        Gets the DFS details for the UNC paths '\\domain.net\HOME\Mike' and '\\domain.net\HOME\Jake'

        Path         : \\domain.net\HOME\Mike
        ComputerName : SERVER1.DOMAIN.NET
        ComputerPath : E:\HOME\Mike
        ShareName    : HOME 

        Path         : \\domain.net\HOME\Jake
        ComputerName : SERVER2.DOMAIN.NET
        ComputerPath : E:\HOME\Jake
        ShareName    : HOME    

    .NOTES
        CHANGELOG
        2015/10/27 Function born #>

    [CmdLetBinding()]
    Param (
        #[Parameter(Mandatory, Position=0)]
        #[PSCredential]$Credentials,
        [Parameter(Mandatory, ValueFromPipeline, Position=1)]
        #[ValidateScript({
        #    if (Test-Path -LiteralPath $_ -PathType Container) {$true}
        #    else {throw "Could not find path '$_'"}
        #})]
        [String[]]$Path
    )

    $retval = @()
    foreach ($P in $Path) {
        Try {
            # State 6 notes that the DFS path is online and active
            $DFS = [Win32Api]::NetDfsGetClientInfo($P) | Where-Object { $_.State -eq 6 } | 
                Select-Object ServerName, ShareName

            $CimParams = @{
                CimSession = New-CimSession -ComputerName $DFS.ServerName -SessionOption (New-CimSessionOption -Protocol Dcom)
                ClassName  = 'Win32_Share'
            }

            $LocalPath = Get-CimInstance @CimParams | Where-Object Name -EQ $DFS.ShareName | Select-Object -ExpandProperty Path

            $DFSInfo = [PSCustomObject][Ordered]@{
                Path         = $P
                ComputerName = $DFS.ServerName
                ComputerPath = $LocalPath + ($P -split $DFS.ShareName, 2)[1]
                ShareName    = $DFS.ShareName
            }
            $retval += $DFSInfo
        }
        Catch {
            Write-Error $Error[0].Exception.Message
            $Global:Error.Remove($Global:Error[0])
        }
    }
    $retval
}

Function Close-FileSession
{
<# 
    .SYNOPSIS   
        Closes sessions to files on a network share.

    .PARAMETER File 
        The full UNC path to the file.

    .EXAMPLE
        Close-FileSession \\fileserver\Scripts\Powershell\Functions\Close-FileSession-Function.ps1
#>

    param
    (
        $File
    )
 
    $DFSInfos = Get-DFSDetails -Path $File

    foreach ($DFSInfo in $DFSInfos)
    {
        $adsi = [adsi]"WinNT://$($DFSInfo.ComputerName)/LanmanServer"

        $Files = $adsi.psbase.Invoke("resources") | %{
            try
            {
                New-Object psobject -Property @{
                    ID = $_.gettype().invokeMember("Name", "GetProperty", $null, $_, $null)
                    Path = $_.gettype().invokeMember("Path", "GetProperty", $null, $_, $null)
                    User = $_.gettype().invokeMember("User", "GetProperty", $null, $_, $null)
                    LockCount = $_.gettype().invokeMember("LockCount", "GetProperty", $null, $_, $null)
                    Server = $DFSInfo.ComputerName
                }
            }
            catch{}
        }
        
        $HandlesToClose = $Files | ?{$_.Path -like "*" + $DFSInfo.ComputerPath}
        if ($HandlesToClose.Count -gt 0)
        {
            Write-Host "Closing $($HandlesToClose.Count) handles"

            $HandlesToClose | %{
            $return += [win32api]::NetFileClose($_.Server, $_.ID)
            }

            if ($return = 0)
            {
                "All handles closed successfully"
            }
        }
        else
        {
            Write-Host "No handles to close"
        }
    }
}
# SIG # Begin signature block
# MIILmgYJKoZIhvcNAQcCoIILizCCC4cCAQExCzAJBgUrDgMCGgUAMGkGCisGAQQB
# gjcCAQSgWzBZMDQGCisGAQQBgjcCAR4wJgIDAQAABBAfzDtgWUsITrck0sYpfvNR
# AgEAAgEAAgEAAgEAAgEAMCEwCQYFKw4DAhoFAAQUnI/2AmzaM8m9nN1V3NT+qi6C
# iLOgggkgMIIEezCCA2OgAwIBAgIDGR83MA0GCSqGSIb3DQEBCwUAMFoxCzAJBgNV
# BAYTAlVTMRgwFgYDVQQKEw9VLlMuIEdvdmVybm1lbnQxDDAKBgNVBAsTA0RvRDEM
# MAoGA1UECxMDUEtJMRUwEwYDVQQDEwxET0QgSUQgQ0EtNDIwHhcNMTgwMTAzMDAw
# MDAwWhcNMjEwMTAyMjM1OTU5WjB5MQswCQYDVQQGEwJVUzEYMBYGA1UEChMPVS5T
# LiBHb3Zlcm5tZW50MQwwCgYDVQQLEwNEb0QxDDAKBgNVBAsTA1BLSTENMAsGA1UE
# CxMEVVNBRjElMCMGA1UEAxMcV0FMS0VSLk5JQ0hPTEFTLkQuMTAwNTE3NDE2MDCC
# ASIwDQYJKoZIhvcNAQEBBQADggEPADCCAQoCggEBANcbJSSCw05cE0Y0ew3EXmBt
# w+0iMjNu7i5xgl0kQrfP7gOzUgky3x5n/HXtq7x5UDigGOOAuHo9CNnIvQAX0cH2
# b+Qi0I+B5JnWQU7zJy8s8xtt78iZ+rM8uy+L/TouQViRZdCRN5zKnokuCWS4YUPV
# cGUSlYUsLAuy/wz5XINOuCMgYhcgwRi7PGLiOTydDmodVbbMm6Wxx9otU8xgN/t7
# OVRK//z9i8oh+UxJJvi5hDSvVzzWWJmnlmZXKnhW88zsqf0sh+v/+HPALWb80Ox5
# w9CFm5YHHRo+yENT/XR+8AYmXZP+Io2jHKPbAENy8dXy48iSNuU/A9zwSwx9LjcC
# AwEAAaOCASkwggElMB8GA1UdIwQYMBaAFDKgAMpZi8TOfHvb3hkqEIqGQdHjMDcG
# A1UdHwQwMC4wLKAqoCiGJmh0dHA6Ly9jcmwuZGlzYS5taWwvY3JsL0RPRElEQ0Ff
# NDIuY3JsMA4GA1UdDwEB/wQEAwIGwDAWBgNVHSAEDzANMAsGCWCGSAFlAgELKjAd
# BgNVHQ4EFgQUdQXRFLfipjlYwy0BllcFduHSKU8wZQYIKwYBBQUHAQEEWTBXMDMG
# CCsGAQUFBzAChidodHRwOi8vY3JsLmRpc2EubWlsL3NpZ24vRE9ESURDQV80Mi5j
# ZXIwIAYIKwYBBQUHMAGGFGh0dHA6Ly9vY3NwLmRpc2EubWlsMBsGA1UdCQQUMBIw
# EAYIKwYBBQUHCQQxBBMCVVMwDQYJKoZIhvcNAQELBQADggEBAEdMSr5oI7i9JpJQ
# poOFwc1Y/r+i2MQqbMzCdgwxB5P1elTntdXjRo8SsSGPhLJC2vh3E0mLCF+HwaG4
# GdCRkhPaLPzQfMrqyTR/Ocr84ul39DQxfCMthWCpUKc8dX0HN3ySrgNtXLHMK/Xo
# U1YobF22eri05EARkBwlFco+smzM/1V4GwO+mvjvQzzB9W5aPcRKP6xuzut4lVMr
# +v/lusjSyvPv0B5QE23IvDIVyKZ3gvvwtMYhr6ET74u1ZCC9RQrogzIav9ikuCdO
# T40ey+81kMjzcNfuS15T0DiJc2n78Vh4kaUc0Qwq6kLc7Kl6UG3+0n452GPtYh3R
# QVEBQhwwggSdMIIDhaADAgECAgEZMA0GCSqGSIb3DQEBCwUAMFsxCzAJBgNVBAYT
# AlVTMRgwFgYDVQQKEw9VLlMuIEdvdmVybm1lbnQxDDAKBgNVBAsTA0RvRDEMMAoG
# A1UECxMDUEtJMRYwFAYDVQQDEw1Eb0QgUm9vdCBDQSAzMB4XDTE1MTEwOTE2MTUw
# MloXDTIxMTEwOTE2MTUwMlowWjELMAkGA1UEBhMCVVMxGDAWBgNVBAoTD1UuUy4g
# R292ZXJubWVudDEMMAoGA1UECxMDRG9EMQwwCgYDVQQLEwNQS0kxFTATBgNVBAMT
# DERPRCBJRCBDQS00MjCCASIwDQYJKoZIhvcNAQEBBQADggEPADCCAQoCggEBAK3j
# /71t4NveD2QaDYyXOdRj3cI62IMt60wKSzhpDn8xhpK2Lp6gPDkvsQeWQ1+es7ld
# cptAdnseqKnDITq5nfpY8S9Tq5+KfnsWv75ohg2TfEsAfiZ7qNPyrKvOf0VQFeHZ
# SyeoIyjmMeX7oUluxOrb+xKkhmXxIxRLjDrA2L+BFKuF1V+YmJuFCASPpBu9Svxo
# BLOXJL37O8xFNmrskEMQ+Vt2x8TeZsZa87T48Pwcyw2uPmsovvB2gDNAMH9iKwX/
# 198nDwtwU+xSKxR1mwVOT0vuowJyBJ8K0Z/DkATDiVyYgCIdFfQCl3+IkziQAO4d
# QU9jMzYQ3ieCMPErqNUCAwEAAaOCAWswggFnMB8GA1UdIwQYMBaAFGyKlKJ3sYBy
# HYF6Fqry3M5m7kXAMB0GA1UdDgQWBBQyoADKWYvEznx7294ZKhCKhkHR4zAOBgNV
# HQ8BAf8EBAMCAYYwTAYDVR0gBEUwQzALBglghkgBZQIBCyQwCwYJYIZIAWUCAQsn
# MAsGCWCGSAFlAgELKjAMBgpghkgBZQMCAQMNMAwGCmCGSAFlAwIBAxEwEgYDVR0T
# AQH/BAgwBgEB/wIBADAMBgNVHSQEBTADgAEAMDcGA1UdHwQwMC4wLKAqoCiGJmh0
# dHA6Ly9jcmwuZGlzYS5taWwvY3JsL0RPRFJPT1RDQTMuY3JsMGwGCCsGAQUFBwEB
# BGAwXjA6BggrBgEFBQcwAoYuaHR0cDovL2NybC5kaXNhLm1pbC9pc3N1ZWR0by9E
# T0RST09UQ0EzX0lULnA3YzAgBggrBgEFBQcwAYYUaHR0cDovL29jc3AuZGlzYS5t
# aWwwDQYJKoZIhvcNAQELBQADggEBADmEiOg+XqN7XXvrAObuLgU0Z6G4qSszoo6o
# RkvLN7ZuRJFldXzAi97oKQzEvz08sRr0E9cX8+kXlafa2jhhmBmbHSP7cz2Qi4jM
# PEocAcG18ug5ceJP+D1T1JyXT1GJZV+G6XXdHv5DoJB0o7XK7r1s228vVTGzPYto
# Y/ekVpJCSUz42zno3drZgneo3KMacyiSwEMVKSK1gkmta14dK/WIG/0VWB793dIT
# 34+r9YNDbbIr/SmHeBMTDrV70Rhn9MB41vTUm7nps2jmVUcDPZRrCvAaFGSUlCF/
# +L0lF1qDKRiDhmRzOX5lc37Rt8kNn6SmKzTCVw+tXM0o2kBWfN8xggHkMIIB4AIB
# ATBhMFoxCzAJBgNVBAYTAlVTMRgwFgYDVQQKEw9VLlMuIEdvdmVybm1lbnQxDDAK
# BgNVBAsTA0RvRDEMMAoGA1UECxMDUEtJMRUwEwYDVQQDEwxET0QgSUQgQ0EtNDIC
# AxkfNzAJBgUrDgMCGgUAoFowGAYKKwYBBAGCNwIBDDEKMAigAoAAoQKAADAZBgkq
# hkiG9w0BCQMxDAYKKwYBBAGCNwIBBDAjBgkqhkiG9w0BCQQxFgQUpRIv/wmz93Oy
# Ei4TIuZ4i5WGpkEwDQYJKoZIhvcNAQEBBQAEggEAIFBUBFyp2+VbuDE6hVQ4Zm5p
# SThzbfqftgRSFBIYMlQOF1ffC18onmwr8IeTo51RE6eHESOUPapSBZCaj6vLjN5P
# 41f68M64qG2U/bQYuuF8NjWTrnvI39wm3HV2mcUQGxHjeDPKtxGJgib8CBgrK/jQ
# tTknk0Y+440Gpr0QOOdhXM3VYW5OxcTyczpmOwh8trqP6mouvhCVr08GwE2XQI6G
# yJbKDsMPi5xO9RF9jkt5aDVEjoL47kkWlNKXS0wqQh442nOq8SqdpS3GEQwqBonX
# dHL2Eeygv0MIJz7QkxFsDv/rQbcYBRln+kDq1OvQqiaFZzd5mM20OFU4NNs5tA==
# SIG # End signature block
