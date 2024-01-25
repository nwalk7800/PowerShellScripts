Function Get-PublicIP
{
    $Response = Invoke-WebRequest -Uri "http://checkip.dyndns.com:8245" -UseBasicParsing
    if ($Response.Content -match "Current IP Address: (.*?)<\/body>")
    {
        $Matches[1]
    }
}