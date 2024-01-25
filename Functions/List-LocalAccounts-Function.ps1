Function List-LocalAccounts
{
<#
.SYNOPSIS
    Returns a list of local accounts
.PARAMETER ComputerName
    An optional list of computers to examine
.NOTES
    Name: List-LocalAccounts
    Author: Nick Walker
.EXAMPLE
List-LocalAccounts -ComputerName AP02

Description
-----------
Returns a list of the local users and their groups.
.EXAMPLE
List-LocalAccounts -ComputerName AP02

Description
-----------
Returns a list of the local users and their groups.
#>
	param
	(
		[string[]] $ComputerName = $env:COMPUTERNAME
	)

    $adsi = [ADSI]"WinNT://$ComputerName"
    $users = $adsi.Children | where {$_.SchemaClassName -eq 'user'}

    Foreach ($user in $users)
    {
        Clear-Variable groups -ErrorAction SilentlyContinue
        Foreach ($group in  $user.Groups())
        {
            $groups += $group.GetType().InvokeMember("Name", 'GetProperty', $null, $group, $null)
        }
        $user | Select-Object @{n='UserName';e={$user.Name}},@{n='Groups';e={$groups -join ';'}}
    }
}