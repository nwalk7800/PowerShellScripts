function global:Unlock-Account
{
	<#
	.SYNOPSIS
		Unlocks a domain user account or accounts.
	.DESCRIPTION
		Unlocks a domain user account or accounts.
	.PARAMETER Users
		A comma separated list of usernames to unlock.
	.PARAMETER Continuous
        	Causes the script to repeatedly check and unlock the accounts until stopped by the user.
	.NOTES
		Name: Unlock-Account
		Author: Nick Walker
		DateCreated: 29 Oct 2012
	.EXAMPLE
		Unlock-Account walkern -Continuous

	Description
	-----------
	Unlocks a domain user account or accounts.

	#>

	[CmdletBinding(SupportsShouldProcess=$True, ConfirmImpact="Low")]
	param
	(
		[Parameter(Mandatory=$True,
		            HelpMessage='What user would you like to unlock?')]
		[String[]]$Users,
		[Switch]$Continuous = $False
	)

	$Error.Clear()
	$ErrorActionPreference = "Silentlycontinue"

	$Filter = "(&(ObjectCategory=user)(|"
	Foreach ($user in $users)
	{
		$Filter += "(samaccountname=$user)"
	}
	$Filter += "))"

	$ADSI = [ADSI]"LDAP://stratcom"
	$Searcher = new-object System.DirectoryServices.DirectorySearcher($ADSI)
	$Searcher.Filter = $Filter
	$Searcher.CacheResults = $false
	$Searcher.PageSize = 1000
	$Searcher.ServerTimeLimit = 30

	$Continue = $True
	while ($Continue)
	{
		$Continue = $Continuous
		$lckAccounts = @()
		$Searcher.Findall() | %{if($_.properties.lockouttime -gt 0){$lckAccounts += @($_)}}
		foreach ($act in $lckAccounts)
		{
			if ($PSCmdlet.ShouldProcess($act.Path, "Unlock account"))
			{
				$unlock = [ADSI]"$($($act.properties.adspath))"
				$unlock.Put("lockouttime",0)
				$unlock.SetInfo()
			}
		}

		Start-Sleep -s 10
	}
}