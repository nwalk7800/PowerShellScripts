function Logoff-User
{
	param
	(
		$ComputerName,
		$User
	)

	$SessionID = ((quser /server:$Computername | ?{$_ -match $User}) -split ' +')[2]
	if ($SessionID)
	{
		@{"User"="$Computername\$User";"SessionID"=$SessionID}
		logoff $SessionID /server:$Computername
	}
	else
	{
		"No session found for $User on $Computername"
	}
}