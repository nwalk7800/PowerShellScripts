Function GetValue
{
    param
    (
        $Key,
        $ValueName
    )

    if($Key.GetValue($ValueName))
    {
        $Key.GetValue($ValueName)
    }
}

Function global:Get-InstalledPrograms
{
    <#
    .SYNOPSIS
        Returns a list of installed programs
    .PARAMETER ComputerName
        An optional list of computers to scan
    .NOTES
        Name: Get-InstalledPrograms
        Author: Nick Walker
    .EXAMPLE
    Get-InstalledPrograms

    Description
    -----------
    Returns a list of the installed programs on this computer excluding system components and updates.
    .EXAMPLE
    Get-InstalledPrograms hostname -All

    Description
    -----------
    Returns a list of the installed programs on computer "hostname", including system components and updates.
    #>
	
    [CmdletBinding(SupportsShouldProcess=$true)]
    param
	(
        [string[]] $ComputerName = $env:COMPUTERNAME,
        [switch] $All
	)

    Process
	{
        $defaultProperties = @('DisplayName', 'DisplayVersion', 'UninstallString')
        $defaultDisplayPropertySet = New-Object System.Management.Automation.PSPropertySet('DefaultDisplayPropertySet', [string[]]$defaultProperties)
        $PSStandardMembers = [System.Management.Automation.PSMemberInfo[]]$defaultDisplayPropertySet

        foreach ($Computer in $ComputerName)
        {
            $array = @()
            $ProductsKey = "HKEY_LOCAL_MACHINE\SOFTWARE\Classes\Installer\Products"
            $UninstallKeys = "LocalMachine\SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall", "LocalMachine\SOFTWARE\Wow6432Node\Microsoft\Windows\CurrentVersion\Uninstall"
            
            $baseKey = [Microsoft.Win32.RegistryKey]::OpenRemoteBaseKey('Users', $Computer)
            $Path = "SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall"
            foreach($User in $baseKey.GetSubKeyNames())
            {
                $UninstallKeys += @("Users\$User\$Path")
            }
            
            foreach ($UninstallKey in $UninstallKeys)
            {
                $Base = $UninstallKey.Substring(0, $UninstallKey.IndexOf("\"))
                $UninstallKey = $UninstallKey.Substring($UninstallKey.IndexOf("\") + 1)

                $reg = [Microsoft.Win32.RegistryKey]::OpenRemoteBaseKey($Base, $Computer)
                $regkey = $reg.OpenSubKey($UninstallKey)
                
                if ($regkey)
                {
                    $subkeys = $regkey.GetSubKeyNames()
                    
                    Foreach($Key in $subkeys)
                    {
                        $thisSubKey = $reg.OpenSubKey("$UninstallKey\$Key")
                        
                        $Display = $True
                        if (-not $All)
                        {
                            if ($thisSubKey.GetValue("SystemComponent") -eq "1"){$Display = $False}
                            $ProductID = Transform-ProductID $key

                            if (($thisSubKey.GetValue("WindowsInstaller") -eq "1") -and -not (Test-Path "Registry::$ProductsKey\$ProductID")){$Display = $False}

                            if ($thisSubKey.GetValue("ReleaseType") -ne $Null){$Display = $False}

                            if ($thisSubKey.GetValue("ParentKeyName") -ne $Null){$Display = $False}
                        }

                        if (($thisSubKey.GetValue("DisplayName") -ne $Null) -and ($thisSubKey.GetValue("UninstallString") -ne $Null) -and $Display)
                        {
                            $obj = "" | Select Name, ComputerName, DisplayName, DisplayVersion, InstallDate, InstallLocation, InstallSource, ModifyPath, UninstallString, RegistryPath
                	        $obj.Name = "InstalledPrograms"
                            $obj | Add-Member MemberSet PSStandardMembers $PSStandardMembers
                            $obj.ComputerName = $Computer
                	        $obj.DisplayName = $thisSubKey.GetValue("DisplayName")
                	        $obj.DisplayVersion = $thisSubKey.GetValue("DisplayVersion")
                	        try {$obj.InstallDate = (&{if($thisSubKey.GetValue("InstallDate")){[DateTime]::ParseExact($thisSubKey.GetValue("InstallDate"), "yyyyMMdd", $null).ToString("M/d/yyyy")}})} catch {$obj.InstallDate = $thisSubKey.GetValue("InstallDate")}
                	        $obj.InstallLocation = (GetValue $thisSubKey "InstallLocation")
                	        $obj.InstallSource = (GetValue $thisSubKey "InstallSource")
                	        $obj.ModifyPath = $thisSubKey.GetValue("ModifyPath")
                	        $obj.UninstallString = $thisSubKey.GetValue("UninstallString")
                            $obj.RegistryPath = $thisSubKey
                            
                            $Obj | Add-Member -MemberType ScriptMethod -Name Uninstall -Value ([ScriptBlock]::Create("& $($obj.UninstallString.Replace('{','"{').Replace('}','}"').Replace('/I','/X'))"))
                            $Obj | Add-Member -MemberType ScriptMethod -Name RemoveEntry -Value ([ScriptBlock]::Create("`$reg = [Microsoft.Win32.RegistryKey]::OpenRemoteBaseKey(`"$Base`", `"$Computer`");`$reg.DeleteSubKeyTree(`"$UninstallKey\$Key`")"))
                            
                            $array += $obj
                        }
                    }
                }
	        }
            $array | Sort-Object -Property DisplayName
        }
    }
}

Function Transform-ProductID
{
	param
	(
		[string] $ProductID
	)
    
    if ($ProductID.Length -eq 38)
    {
        $ProductID = $ProductID.Substring(1,36)
        $ProductID = $ProductID.Replace("-", "")
        
        $Transform = -join (7..0 | ForEach-Object {$ProductID[$_]})
        $Transform += -join (11..8 | ForEach-Object {$ProductID[$_]})
        $Transform += -join (15..12 | ForEach-Object {$ProductID[$_]})
        $Transform += -join (17..16 | ForEach-Object {$ProductID[$_]})
        $Transform += -join (19..18 | ForEach-Object {$ProductID[$_]})
        $Transform += -join (21..20 | ForEach-Object {$ProductID[$_]})
        $Transform += -join (23..22 | ForEach-Object {$ProductID[$_]})
        $Transform += -join (25..24 | ForEach-Object {$ProductID[$_]})
        $Transform += -join (27..26 | ForEach-Object {$ProductID[$_]})
        $Transform += -join (29..28 | ForEach-Object {$ProductID[$_]})
        $Transform += -join (31..30 | ForEach-Object {$ProductID[$_]})
    }
}

$completion_ComputerName = {
    param
    (
        $commandName,
        $parameterName,
        $wordToComplete,
        $commandAst,
        $fakeBoundParameter
    )

    $ComputerNames = List-DomainHosts -Names

    ForEach ($ComputerName in $ComputerNames)
    {
        If ($ComputerName -like "$wordToComplete*")
        {
            New-Object System.Management.Automation.CompletionResult $ComputerName, $ComputerName, ParameterValue, $ComputerName
        }
    }
}

If (-not $Global:options)
{
    $Global:options = @{CustomArgumentCompleters = @{};NativeArgumentCompleters = @{}}
}

$Global:options['CustomArgumentCompleters']['Get-InstalledPrograms:ComputerName'] = $completion_ComputerName

$function:tabexpansion2 = $function:tabexpansion2 -replace 'End\r\n{','End {if ($null -ne $options) { $options += $global:options} else {$options = $global:options}'
