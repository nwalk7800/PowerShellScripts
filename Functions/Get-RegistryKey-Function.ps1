Function Get-RegistryKey
{
	<#
	.SYNOPSIS
		Retrieves registry keys or values from a computer.
	.DESCRIPTION
		Retrieves registry keys or values from a computer.
	.PARAMETER ComputerName
		Name of computer/s to check.
	.PARAMETER KeyPath
		Path the the registry key, including hive.
	.PARAMETER Property
		Specific property to query.
	.PARAMETER SubKeys
		True to return the subkeys of a key.
	.PARAMETER AllUsers
		If the specified hive is HKU or HKEY_CURRENT_USER this flag will look in all users.
	.NOTES
		Name: Get-RegistryKey
		Author: Nick Walker
		DateCreated: 12 Aug 2012
	.EXAMPLE
		Get-RegistryKey -ComputerName ComputerName -KeyPath "hku\Software\Microsoft\Windows\CurrentVersion\Internet Settings" -AllUsers

	Description
	-----------
	This command will pull registry values for a computer.

	#>
	
	param
	(
		[string[]]$ComputerName = $env:COMPUTERNAME,
		[string]$KeyPath = $(throw "Please specify a registry path"),
		[string]$Property = "*",
		[switch]$SubKeys,
		[switch]$AllUsers,
        [switch]$NoProgress
	) 

	Process
	{
		$Hive = $KeyPath.Substring(0, $KeyPath.IndexOf(":\"))
		$Path = $KeyPath.Substring($KeyPath.IndexOf("\") + 1)

        switch ($Hive)
		{
			"HKCR" {$Base = "ClassesRoot"}
			"HKEY_CLASSES_ROOT" {$Base = "ClassesRoot"}
			"HKCU" {$Base = "CurrentUser"}
			"HKEY_CURRENT_USER" {$Base = "CurrentUser"}
			"HKLM" {$Base = "LocalMachine"}
			"HKEY_LOCAL_MACHINE" {$Base = "LocalMachine"}
			"HKU"  {$Base = "Users"}
			"HKEY_USERS"  {$Base = "Users"}
			"HKPD" {$Base = "PerformanceData"}
			"HKEY_PERFORMANCE_DATA" {$Base = "PerformanceData"}
			"HKCC" {$Base = "CurrentConfig"}
			"HKEY_CURRENT_CONFIG" {$Base = "CurrentConfig"}
			"HKDD" {$Base = "DynData"}
			"HKEY_DYN_DATA" {$Base = "DynData"}
		}
    
    	$StartTime = Get-Date
		$ndx = 0
		$returnObject = @()

        foreach ($Computer in $ComputerName)
		{
    		if (-not $NoProgress)
            {
                $ndx++
    		    $CurTime = (New-TimeSpan $StartTime $(Get-Date))
    		    $TimePer = $CurTime.TotalSeconds / $ndx
    		    $PrettyTime = "{0}:{1}:{2}" -f $CurTime.Hours.ToString(), $CurTime.Minutes.ToString(), $CurTime.Seconds.ToString()
    		    Write-Progress -Activity "Scanning clients $PrettyTime" -Status "$Computer" -PercentComplete (($ndx / $ComputerName.Count) * 100) -SecondsRemaining ($TimePer * ($ComputerName.Count - $ndx))
            }            
            if (Test-Connection $Computer -Count 1 -Quiet)
    		{
                $Skip = $False
                Try{$baseKey = [Microsoft.Win32.RegistryKey]::OpenRemoteBaseKey($Base, $Computer)}
                Catch{$Skip = $True}


    			if ($Skip -eq $False)
                {
                    #Loop through all the loaded user hives
        			if ($Base -eq "Users" -and $AllUsers)
        			{
        				#Create an array of paths for all loaded user hives
        				$Paths = @()
        				foreach($User in $baseKey.GetSubKeyNames())
        				{
        					$Paths += $User + "\" + $Path
        				}
        			}
        			else
        			{
        				$Paths = @($Path)
        			}

        			#Loops through each path
        			#There will only be more than one path if the AllUsers switch is specified
        			foreach ($Path in $Paths)
        			{
        				$key = $baseKey.OpenSubKey($Path)
        				
                        #Make sure the key exists before trying to read it
        				if ($key -ne $Null)
        				{
        					#list the subkeys
        					if ($SubKeys)
        					{
        						#Loop through each subkey and add it to the return object
        						foreach($SubKey in $key.GetSubKeyNames())
        						{
        							$temp = "" | Select Computer, Key
        							$temp.Computer = $Computer
        							$temp.Key = $key.Name + "\" + $Subkey
    								$returnObject += $temp
        						}
        					}
        					#List the properties and their values 
        					else
        					{
        						#Loop through each property and get its value and add them to the return object
        						foreach($keyProperty in $key.GetValueNames())
        						{
        							#Special case where the default property has no name, but you have to refer to it as (Default) to read it.
        							if ($keyProperty -eq "") {$Name = "(Default)"} else {$Name = $keyProperty}
        							if($Name -like $property)
        							{
                                        				$temp = "" | Select Computer, Key, Property, Value
        								$temp.Computer = $Computer
        								$temp.Key = $key.Name
        								$temp.Property = $Name
        								$temp.Value = $key.GetValue($keyProperty)
        								$returnObject += $temp
        							}
        						}
        					}
        					$key.Close()
        				}
        			}
        			$baseKey.Close()
                }
    		}
        }
        $returnObject
	}
}