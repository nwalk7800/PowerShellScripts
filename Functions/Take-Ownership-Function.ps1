Function global:Take-Ownership
{
<#
.SYNOPSIS
    Takes ownership of a file or folder removing all existing permissions
.PARAMETER Filename
    The file or folder to take ownership of
.NOTES
    Name: Take-Ownership
    Author: Nick Walker
.EXAMPLE
Take-Ownership .\file

Description
-----------
Takes ownership of a file or folder removing all existing permissions.
.EXAMPLE
Take-Ownership .\file
#>
	param
	(
		[string[]] $Filename,
        [switch] $Recursive
	)
    
    Adjust-TokenPrivileges SeRestorePrivilege | Out-Null          #Needed to set owner permissions
    Adjust-TokenPrivileges SeBackupPrivilege | Out-Null           #Needed to bypass traverse checking
    Adjust-TokenPrivileges SeTakeOwnershipPrivilege | Out-Null    #Needed to override FilePermissions and Take Ownership

    foreach ($File in $Filename)
    {
        $Item = Get-Item $File
    
        if ($Item.GetType() -eq [System.IO.DirectoryInfo])
        {
            $BlankAcl = New-Object System.Security.AccessControl.DirectorySecurity
            $BlankAcl.SetOwner([System.Security.Principal.NTAccount]"$env:USERDOMAIN\$env:USERNAME")
            $Item.SetAccessControl($BlankAcl)
            
            if ($Recursive){Take-Ownership (ls $Item).FullName -Recursive}
        }
        elseif ($Item.GetType() -eq [System.IO.FileInfo])
        {
            $BlankAcl = New-Object System.Security.AccessControl.FileSecurity
            $BlankAcl.SetOwner([System.Security.Principal.NTAccount]"$env:USERDOMAIN\$env:USERNAME")
            $Item.SetAccessControl($BlankAcl)
        }
    }
}