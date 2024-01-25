$fqdn = "{0}.{1}" -f $env:COMPUTERNAME.ToLower(), $env:USERDNSDOMAIN.ToLower()

$Cert = New-SelfSignedCertificate -DnsName $fqdn -CertStoreLocation Cert:\LocalMachine\My

winrm create winrm/config/Listener?Address=*+Transport=HTTPS "@{Hostname=`"$fqdn`"; CertificateThumbprint=`"$($Cert.Thumbprint)`"}"

netsh advfirewall firewall add rule name="Windows Remote Management (HTTPS-In)" dir=in action=allow protocol=TCP localport=5986