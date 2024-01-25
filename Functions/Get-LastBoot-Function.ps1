Function Get-LastBoot
{
	Get-CimInstance -ClassName win32_operatingsystem | select csname, lastbootuptime
}