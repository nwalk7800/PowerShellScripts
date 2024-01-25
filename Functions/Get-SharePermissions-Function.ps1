
Function global:GetSharedFolderPermission
{
    Param
    (
	    [Parameter(Mandatory=$false)]
	    [Alias('Computer')][String[]]$ComputerName=$Env:COMPUTERNAME,

	    [Parameter(Mandatory=$false)]
	    [Alias('Share')][String[]]$ShareName,

	    [Parameter(Mandatory=$false)]
	    [Alias('Cred')][System.Management.Automation.PsCredential]$Credential
    )

	#test server connectivity
	$PingResult = Test-Connection -ComputerName $ComputerName -Count 1 -Quiet
	if($PingResult)
	{
		#check the credential whether trigger
		if($Credential)
		{
			$SharedFolderSecs = Get-WmiObject -Class Win32_LogicalShareSecuritySetting -ComputerName $ComputerName -Filter "Name Like '$ShareName%'" -Credential $Credential -ErrorAction SilentlyContinue
		}
		else
		{
            $SharedFolderSecs = Get-WmiObject -Class Win32_LogicalShareSecuritySetting -ComputerName $ComputerName -Filter "Name Like '$ShareName%'" -ErrorAction SilentlyContinue
		}
		
		foreach ($SharedFolderSec in $SharedFolderSecs) 
		{ 
		    $Objs = @() #define the empty array
			
	        $SecDescriptor = $SharedFolderSec.GetSecurityDescriptor()
	        foreach($DACL in $SecDescriptor.Descriptor.DACL)
			{  
				$DACLDomain = $DACL.Trustee.Domain
				$DACLName = $DACL.Trustee.Name
				if($DACLDomain -ne $null)
				{
	           		$UserName = "$DACLDomain\$DACLName"
				}
				else
				{
					$UserName = "$DACLName"
				}
				
				#customize the property
				$Properties = @{'ComputerName' = $ComputerName
								'ConnectionStatus' = "Success"
								'SharedFolderName' = $SharedFolderSec.Name
								'SecurityPrincipal' = $UserName
								'FileSystemRights' = [Security.AccessControl.FileSystemRights]`
								$($DACL.AccessMask -as [Security.AccessControl.FileSystemRights])
								'AccessControlType' = [Security.AccessControl.AceType]$DACL.AceType}
				$SharedACLs = New-Object -TypeName PSObject -Property $Properties
				$Objs += $SharedACLs

	        }
			$Objs|Select-Object ComputerName,ConnectionStatus,SharedFolderName,SecurityPrincipal, `
			FileSystemRights,AccessControlType
	    }  
	}
	else
	{
		$Properties = @{'ComputerName' = $ComputerName
						'ConnectionStatus' = "Fail"
						'SharedFolderName' = "Not Available"
						'SecurityPrincipal' = "Not Available"
						'FileSystemRights' = "Not Available"
						'AccessControlType' = "Not Available"}
		$SharedACLs = New-Object -TypeName PSObject -Property $Properties
		$Objs += $SharedACLs
		$Objs|Select-Object ComputerName,ConnectionStatus,SharedFolderName,SecurityPrincipal, `
		FileSystemRights,AccessControlType
	}
}

Function global:GetSharedFolderNTFSPermission
{
    Param
    (
	    [Parameter(Mandatory=$false)]
	    [Alias('Computer')][String[]]$ComputerName=$Env:COMPUTERNAME,

	    [Parameter(Mandatory=$false)]
	    [Alias('Share')][String[]]$ShareName,

	    [Parameter(Mandatory=$false)]
	    [Alias('Cred')][System.Management.Automation.PsCredential]$Credential
    )

	#test server connectivity
	$PingResult = Test-Connection -ComputerName $ComputerName -Count 1 -Quiet
	if($PingResult)
	{
		#check the credential whether trigger
		if($Credential)
		{
			$SharedFolders = Get-WmiObject -Class Win32_Share -ComputerName $ComputerName -Filter "Name Like '$ShareName%'" -Credential $Credential -ErrorAction SilentlyContinue
		}
		else
		{
			$SharedFolders = Get-WmiObject -Class Win32_Share -ComputerName $ComputerName -Filter "Name Like '$ShareName%'" -ErrorAction SilentlyContinue
		}

		foreach($SharedFolder in $SharedFolders)
		{
			$Objs = @()
			
			$SharedFolderPath = [regex]::Escape($SharedFolder.Path)
			if($Credential)
			{	
				$SharedNTFSSecs = Get-WmiObject -Class Win32_LogicalFileSecuritySetting -Filter "Path='$SharedFolderPath'" -ComputerName $ComputerName  -Credential $Credential
			}
			else
			{
				$SharedNTFSSecs = Get-WmiObject -Class Win32_LogicalFileSecuritySetting -Filter "Path='$SharedFolderPath'" -ComputerName $ComputerName
			}
			
			$SecDescriptor = $SharedNTFSSecs.GetSecurityDescriptor()
			foreach($DACL in $SecDescriptor.Descriptor.DACL)
			{  
				$DACLDomain = $DACL.Trustee.Domain
				$DACLName = $DACL.Trustee.Name
				if($DACLDomain -ne $null)
				{
	           		$UserName = "$DACLDomain\$DACLName"
				}
				else
				{
					$UserName = "$DACLName"
				}
				
				#customize the property
				$Properties = @{'ComputerName' = $ComputerName
								'ConnectionStatus' = "Success"
								'SharedFolderName' = $SharedFolder.Name
								'SecurityPrincipal' = $UserName
								'FileSystemRights' = [Security.AccessControl.FileSystemRights]`
								$($DACL.AccessMask -as [Security.AccessControl.FileSystemRights])
								'AccessControlType' = [Security.AccessControl.AceType]$DACL.AceType
								'AccessControlFalgs' = [Security.AccessControl.AceFlags]$DACL.AceFlags}
								
				$SharedNTFSACL = New-Object -TypeName PSObject -Property $Properties
	            $Objs += $SharedNTFSACL
	        }
			$Objs |Select-Object ComputerName,ConnectionStatus,SharedFolderName,SecurityPrincipal,FileSystemRights, `
			AccessControlType,AccessControlFalgs -Unique
		}
	}
	else
	{
		$Properties = @{'ComputerName' = $ComputerName
						'ConnectionStatus' = "Fail"
						'SharedFolderName' = "Not Available"
						'SecurityPrincipal' = "Not Available"
						'FileSystemRights' = "Not Available"
						'AccessControlType' = "Not Available"
						'AccessControlFalgs' = "Not Available"}
					
		$SharedNTFSACL = New-Object -TypeName PSObject -Property $Properties
	    $Objs += $SharedNTFSACL
		$Objs |Select-Object ComputerName,ConnectionStatus,SharedFolderName,SecurityPrincipal,FileSystemRights, `
		AccessControlType,AccessControlFalgs -Unique
	}
} 

Function global:Get-SharePermissions
{
    <#
 	    .SYNOPSIS
            This script can be list all of shared folder permission or ntfs permission.
		
        .DESCRIPTION
            This script can be list all of shared folder permission or ntfs permission.
		
	    .PARAMETER  <SharedFolderNTFSPermission>
		    Lists all of ntfs permission of SharedFolder.
		
	    .PARAMETER	<ComputerName <string[]>
		    Specifies the computers on which the command runs. The default is the local computer. 
		
	    .PARAMETER  <Credential>
		    Specifies a user account that has permission to perform this action. 
		
        .EXAMPLE
            C:\PS> Get-OSCFolderPermission -NTFSPermission
		
		    This example lists all of ntfs permission of SharedFolder on the local computer.
		
        .EXAMPLE
		    C:\PS> $cre = Get-Credential
            C:\PS> Get-OSCFolderPermission -ComputerName "APP" -Credential $cre
		
		    This example lists all of share permission of SharedFolder on the APP remote computer.
		
	    .EXAMPLE
            C:\PS> Get-OSCFolderPermission -NTFSPermission -ComputerName "APP" | Export-Csv -Path "D:\Permission.csv" -NoTypeInformation
		
		    This example will export report to csv file. If you attach the <NoTypeInformation> parameter with command, it will omits the type information 
		    from the CSV file. By default, the first line of the CSV file contains "#TYPE " followed by the fully-qualified name of the object type.
    #>

    Param
    (
	    [Parameter(Mandatory=$false)]
	    [Alias('Computer')][String[]]$ComputerName=$Env:COMPUTERNAME,

	    [Parameter(Mandatory=$false)]
	    [Alias('Share')][String[]]$ShareName,

	    [Parameter(Mandatory=$false)]
	    [Alias('NTFS')][Switch]$NTFSPermission,
	
	    [Parameter(Mandatory=$false)]
	    [Alias('Cred')][System.Management.Automation.PsCredential]$Credential
    )

    $RecordErrorAction = $ErrorActionPreference
    #change the error action temporarily
    $ErrorActionPreference = "SilentlyContinue"

    foreach($CN in $ComputerName)
    {
	
	    if($NTFSPermission)
	    {
		    GetSharedFolderNTFSPermission -ComputerName $CN -ShareName $ShareName -Credential $Credential
	    }
	    else
	    {
		    GetSharedFolderPermission -ComputerName $CN -ShareName $ShareName -Credential $Credential
	    }
    }
    #restore the error action
    $ErrorActionPreference = $RecordErrorAction
}

Function Get-Shares
{
    Param
    (
	    [Parameter(Mandatory=$false)]
	    [Alias('Computer')][String[]]$ComputerName=$Env:COMPUTERNAME,

	    [Parameter(Mandatory=$false)]
	    [Alias('Share')][String[]]$ShareName
    )

	$PingResult = Test-Connection -ComputerName $ComputerName -Count 1 -Quiet
	if($PingResult)
	{
		#check the credential whether trigger
		if($Credential)
		{
			$SharedFolders = Get-WmiObject -Class Win32_Share -ComputerName $ComputerName -Filter "Name Like '$ShareName%'" -Credential $Credential -ErrorAction SilentlyContinue
		}
		else
		{
			$SharedFolders = Get-WmiObject -Class Win32_Share -ComputerName $ComputerName -Filter "Name Like '$ShareName%'" -ErrorAction SilentlyContinue
		}
        $SharedFolders
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

$Global:options['CustomArgumentCompleters']['GetSharedFolderPermission:ComputerName'] = $completion_ComputerName
$Global:options['CustomArgumentCompleters']['GetSharedFolderNTFSPermission:ComputerName'] = $completion_ComputerName
$Global:options['CustomArgumentCompleters']['Get-SharePermissions:ComputerName'] = $completion_ComputerName
$Global:options['CustomArgumentCompleters']['Get-Shares:ComputerName'] = $completion_ComputerName

$function:tabexpansion2 = $function:tabexpansion2 -replace 'End\r\n{','End {if ($null -ne $options) { $options += $global:options} else {$options = $global:options}'
