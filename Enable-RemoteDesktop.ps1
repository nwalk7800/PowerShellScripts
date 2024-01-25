param
(
	$ComputerName
)

(Get-WmiObject -Class Win32_TerminalServiceSetting -Computername $ComputerName -Namespace root\cimv2\TerminalServices).SetAllowTsConnections(1,1) | Out-Null

(Get-WmiObject -Class Win32_TSGeneralSetting -Computername $ComputerName -Namespace root\cimv2\TerminalServices -Filter "TerminalName='RDP-tcp'").SetUserAuthenticationRequired(0) | Out-Null