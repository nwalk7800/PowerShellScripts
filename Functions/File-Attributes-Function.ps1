Update-TypeData -TypeName System.IO.FileInfo -MemberName FileSize -MemberType ScriptProperty -ErrorAction SilentlyContinue -Value { 

    switch($this.length)
    {
        { $_ -gt 1tb }
            { "{0:n2} TB" -f ($_ / 1tb); break }
        { $_ -gt 1gb } 
            { "{0:n2} GB" -f ($_ / 1gb); break }
        { $_ -gt 1mb } 
            { "{0:n2} MB " -f ($_ / 1mb); break }
        { $_ -gt 1kb } 
            { "{0:n2} KB " -f ($_ / 1Kb); break }
        default  
            { "{0} B " -f $_} 
    }      

 } -DefaultDisplayPropertySet Mode,LastWriteTime,FileSize,Name -Force

function global:Get-FileAttribute
{
	<#
	.SYNOPSIS
		Lists attributes for a file.
	.PARAMETER File
		Name of file to check.
	.PARAMETER Attribute
        	The attribute to check.  Omit for all attributes.
	.NOTES
		Name: Get-FileAttribute
		Author: Nick Walker
		DateCreated: 26 Oct 2012
	.EXAMPLE
		Get-FileAttribute -file .\File-Attribites-Function.ps1 -Attribute ReadOnly

	Description
	-----------
	This command will list attributes for a file.

	#>

	param
	(
        [string]$File = $(throw "Invalid file path"),
		[System.IO.FileAttributes]$Attribute
	)

	if(-not(test-path -path $File))
	{
		write-error "Invalid file path";
		return;
	}

	$returnObject = @()
	$attrNames = [enum]::getNames([System.IO.FileAttributes]);
	if ($Attribute -eq "")
	{
		$attr = $attrNames;
	}
	elseif ($attrNames -notContains $Attribute)
	{
		write-error "Invalid attribute name.  Possible values: $([string]::Join(', ', $attrNames))";
		return;
	}
	else
	{
		$attrNames = @($Attribute);
	}

	ForEach ($attr in $attrNames)
	{
		$out = "" | select Attribute, Set;
		$attr = [System.IO.FileAttributes]$attr;
		if((gci $File -force).Attributes -band $attr -eq $attr)
		{
			$out.Attribute = $attr;
			$out.Set = $true;
		}
		else
		{
			$out.Attribute = $attr;
			$out.Set = $false;
		}
		$returnObject += $out;
	}
	$returnObject
}

function global:Set-FileAttribute
{
	<#
	.SYNOPSIS
		Sets attributes for a file.
	.DESCRIPTION
		Sets attributes for a file.
	.PARAMETER Filename
		Name of file to change.
	.PARAMETER Attribute
        	The attribute to set.
	.NOTES
		Name: Set-FileAttribute
		Author: Nick Walker
		DateCreated: 26 Oct 2012
	.EXAMPLE
		Set-FileAttribute -file .\File-Attribites-Function.ps1 -Attribute ReadOnly

	Description
	-----------
	This command will set attributes for a file.

	#>

	param
	(
		[string]$Filename = $(throw "Invalid file path"),
		[System.IO.FileAttributes]$Attribute
	)

	if(-not(test-path -path $Filename))
	{
		write-error "Invalid file path";
		return;
	}

	$attrNames = [enum]::getNames([System.IO.FileAttributes]);
	if ($attrNames -notContains $Attribute)
	{
		write-error "Invalid attribute name.  Possible values: $([string]::Join(', ', $attrNames))";
		return;
	}

	$File = (gci $Filename -force);
	$File.Attributes = $File.Attributes -bor ([System.IO.FileAttributes]$Attribute).value__;
	if($?){$true;}else{$false;}
}

function global:Clear-FileAttribute
{
	<#
	.SYNOPSIS
		Clears attributes for a file.
	.DESCRIPTION
		Clears attributes for a file.
	.PARAMETER Filename
		Name of file to change.
	.PARAMETER Attribute
        	The attribute to clear.
	.NOTES
		Name: Clear-FileAttribute
		Author: Nick Walker
		DateCreated: 26 Oct 2012
	.EXAMPLE
		Clear-FileAttribute -file .\File-Attribites-Function.ps1 -Attribute ReadOnly

	Description
	-----------
	This command will clear attributes for a file.

	#>

	param
	(
		[string]$Filename = $(throw "Invalid file path"),
		[System.IO.FileAttributes]$Attribute
	)

	if(-not(test-path -path $Filename))
	{
		write-error "Invalid file path";
		return;
	}

	$attrNames = [enum]::getNames([System.IO.FileAttributes]);
	if ($attrNames -notContains $Attribute)
	{
		write-error "Invalid attribute name.  Possible values: $([string]::Join(', ', $attrNames))";
		return;
	}

	$allExcept = ([int]0xFFFFFFFF -bxor ([System.IO.FileAttributes]$Attribute).value__);

	$File = (gci $Filename -force);
	$File.Attributes = [System.IO.FileAttributes]($Attribute.value__ -band $allExcept);
	if($?){$true;}else{$false;}
}

Function global:Get-FilePermissions
{
	param
	(
		[string]$Filename = $(throw "Invalid file path"),
        [switch]$Owner
	)

    $Perms = Get-Acl $Filename
    if ($Owner)
    {
        $Perms.Owner
    }
    else
    {
        $Perms.Access | select IdentityReference, FileSystemRights, AccessControlType, IsInherited | Format-Table
    }
}

Function global:Add-FilePermissions
{
	param
	(
		[string]$Filename = $(throw "Invalid file path"),
        [string]$UserName = "$env:USERDNSDOMAIN\$env:USERNAME",
        [System.Security.AccessControl.FileSystemRights]$FileSystemRights = [System.Security.AccessControl.FileSystemRights]::FullControl,
        [System.Security.AccessControl.AccessControlType]$AccessControlType = [System.Security.AccessControl.AccessControlType]::Allow
	)

    $ACL = Get-Acl $Filename
    $AccessRule = New-Object System.Security.AccessControl.FileSystemAccessRule($UserName, $FileSystemRights, $AccessControlType)
    $ACL.AddAccessRule($AccessRule)
    Set-Acl $Filename -AclObject $ACL
}

Function global:Replace-ChildPermissions
{
    param
    (
        [System.IO.DirectoryInfo]$Directory = $(throw "Invalid file path"),
        [switch]$FilesOnly,
        [switch]$DontRecurse
    )

    $Access = (Get-Acl $Directory).Access
    
    $AllFiles = ls $Directory -Recurse:(-not $DontRecurse)
    if ($FilesOnly){$AllFiles = $AllFiles | ?{-not $_.PSIsContainer}}

    $TotalFiles = $AllFiles.Count
    $CurrentFile = 0

    foreach ($Item in $AllFiles)
    {
        $CurrentFile++
        Write-Progress -Activity "Replacing child permissions" -Status $Item.FullName -PercentComplete (($CurrentFile/$TotalFiles)*100)
        $ACL = Get-Acl $Item.FullName
        $ACL.Access | %{$ACL.RemoveAccessRule($_) | Out-Null}
        foreach ($AccessRule in $Access)
        {
            try
            {
                $ACL.SetAccessRule($AccessRule) | Out-Null
            }
            catch
            {
                if ($_.Exception -notmatch "No flags can be set")
                {
                    throw $_
                }
            }
        }
        Set-Acl $Item.FullName $ACL
    }
}

Function global:Remove-FilePermissions
{
    [CmdletBinding(SupportsShouldProcess=$true)]
    param
	(
		[string]$Filename = $(throw "Invalid file path"),
        [Parameter(Mandatory=$true)]
        [string]$UserName,
        [System.Security.AccessControl.FileSystemRights]$FileSystemRights,
        [System.Security.AccessControl.AccessControlType]$AccessControlType
	)

    $ACL = Get-Acl $Filename

    ForEach ($Access in $ACL.Access)
    {
        ForEach ($User in $Access.IdentityReference.Value)
        {
            $FSRemove = $false
            $ACRemove = $false
            
            If ($UserName -eq $User)
            {
                If ($FileSystemRights -eq $null)
                {
                    $FSRemove = $true
                }
                Else
                {
                    If ($Access.FileSystemRights -eq $FileSystemRights)
                    {
                        $FSRemove = $true
                    }
                }

                If ($AccessControlType -eq $null)
                {
                    $ACRemove = $true
                }
                Else
                {
                    If ($Access.AccessControlType -eq $AccessControlType)
                    {
                        $ACRemove = $true
                    }
                }
                
                If ($FSRemove -and $ACRemove)
                {
                    $ACL.RemoveAccessRule($Access) | Out-Null
                    
                    If ($PSCmdlet.MyInvocation.BoundParameters["Verbose"].IsPresent -or $PSCmdlet.MyInvocation.BoundParameters["Confirm"].IsPresent)
                    {
                        If ($Access.IsInherited -eq "True")
                        {
                            Write-Verbose "Can't remove inherited access"
                        }
                        $Access | select IdentityReference, FileSystemRights, AccessControlType, IsInherited | Format-Table
                    }
                }
            }
        }
    }
    
    If ($PSCmdlet.ShouldProcess($Filename, "Remove permissions"))
    {
        Set-Acl $Filename -AclObject $ACL
    }
}

Function global:Set-FileOwner
{
    [CmdletBinding(SupportsShouldProcess=$true)]
    param
	(
		[string]$Filename = $(throw "Invalid file path"),
        [Parameter(Mandatory=$true)]
        [System.Security.Principal.NTAccount]$NewOwner
	)

    $ACL = Get-Acl $Filename

    $ACL.SetOwner($NewOwner)
    
    Set-Acl $Filename -AclObject $ACL
}

Function global:Remove-DuplicatePermissions
{
    [CmdletBinding(SupportsShouldProcess=$true)]
    param
	(
        [string]$Filename = $(throw "Invalid file path")
	)

    $ACL = Get-Acl $Filename
    ForEach ($Access in $ACL.Access | Where-Object {-not $_.IsInherited})
    {
        ForEach ($InheritedAccess in $ACL.Access | Where-Object {$_.IsInherited})
        {
            If ($InheritedAccess.IdentityReference -eq $Access.IdentityReference `
                -and $InheritedAccess.FileSystemRights -eq $Access.FileSystemRights `
                -and $InheritedAccess.AccessControlType -eq $Access.AccessControlType)
            {
                $ACL.RemoveAccessRule($Access) | Out-Null
                break
            }
        }
    }
    Set-Acl $Filename -AclObject $ACL
}

Function global:Set-FileInheritance
{
    [CmdletBinding(SupportsShouldProcess=$true)]
    param
	(
		[string]$Filename = $(throw "Invalid file path"),
        [switch]$Remove,
        [switch]$DoNotPreserve
	)

    $ACL = Get-Acl $Filename

    $ACL.SetAccessRuleProtection($Remove, -not $DoNotPreserve)
    

    Set-Acl $Filename -AclObject $ACL

    #Remove duplicate permissions
    If (-not $Remove)
    {
        Remove-DuplicatePermissions $Filename
    }
}

$completion_UserName = {
    param
    (
        $commandName,
        $parameterName,
        $wordToComplete,
        $commandAst,
        $fakeBoundParameter
    )

    $Users = List-DomainUsers -SAMAccountName -Users "$wordToComplete*"

    ForEach ($User in $Users)
    {
        New-Object System.Management.Automation.CompletionResult $User, $User, ParameterValue, $User
    }
}

If (-not $Global:options)
{
    $Global:options = @{CustomArgumentCompleters = @{};NativeArgumentCompleters = @{}}
}

$Global:options['CustomArgumentCompleters']['Set-FileOwner:NewOwner'] = $completion_UserName
$Global:options['CustomArgumentCompleters']['Add-FilePermissions:UserName'] = $completion_UserName
$Global:options['CustomArgumentCompleters']['Remove-FilePermissions:UserName'] = $completion_UserName

$function:tabexpansion2 = $function:tabexpansion2 -replace 'End\r\n{','End {if ($null -ne $options) { $options += $global:options} else {$options = $global:options}'
