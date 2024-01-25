Function Test-MemoryUsage {
[cmdletbinding()]
Param($ComputerName)
 
$os = Get-Ciminstance -Class Win32_OperatingSystem -ComputerName $ComputerName
$pctFree = [math]::Round(($os.FreePhysicalMemory/$os.TotalVisibleMemorySize)*100,2)
 
$os | Select @{Name = "Free%"; Expression = {$pctFree}}, 
@{Name = "FreeGB";Expression = {[math]::Round($_.FreePhysicalMemory/1mb,2)}},
@{Name = "TotalGB";Expression = {[int]($_.TotalVisibleMemorySize/1mb)}}
 
}