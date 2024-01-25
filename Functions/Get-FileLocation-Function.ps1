Function Global:Update-FileLocations
{
    <#
    .SYNOPSIS
        Updates the file list similar to Linux's updatedb
    .NOTES
        Name: Update-FileLocations
        Author: Nick Walker
    .EXAMPLE
    Update-FileLocations
    #>
	
    foreach ($Disk in (Get-WmiObject -Query "select * from Win32_LogicalDisk where DriveType='3'" | select -ExpandProperty DeviceID))
    {
        (ls "$Disk\" -Recurse).FullName > "$env:LOCALAPPDATA\mlocate" 2>&1 | Out-Null
    }
}

Function Global:Get-FileLocation
{
    <#
    .SYNOPSIS
        Gets the location of a file matching the input regex, similar ot Linux's mlocate
    .NOTES
        Name: Get-FileLocation
        Author: Nick Walker
    .EXAMPLE
    Get-FileLocation file.txt
    #>

    param
    (
        [string] $Regex
    )
	
    foreach ($String in (cat "$env:LOCALAPPDATA\mlocate"))
    {
        if ($String -match $Regex)
        {
            $String
        }
    }
}

Set-Alias -Name updatedb -Value Update-FileLocations
Set-Alias -Name locate -Value Get-FileLocation
