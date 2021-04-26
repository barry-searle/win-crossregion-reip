<# Copyright 2021 Google Inc

Licensed under the Apache License, Version 2.0 (the "License");
you may not use this file except in compliance with the License.
You may obtain a copy of the License at

    http://www.apache.org/licenses/LICENSE-2.0

Unless required by applicable law or agreed to in writing, software
distributed under the License is distributed on an "AS IS" BASIS,
WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
See the License for the specific language governing permissions and
limitations under the License. #>

Write-Host "Configuring network..."
#function to write debugging info to the console
Function Write-SerialPort ([string] $message) {
    $port = new-Object System.IO.Ports.SerialPort COM1,9600,None,8,one
    $port.open()
    $port.WriteLine($message)
    $port.Close()
}

function Wait-For-Metadata(){
  # above can cause network blip, so wait until metadata server is responsive
  $HaveMetadata = $False
  While( ! $HaveMetadata ) { 
    Try {
      Invoke-RestMethod -Headers @{"Metadata-Flavor" = "Google"} -Uri http://169.254.169.254/ 1>$Null 2>&1
      $HaveMetadata = $True
    } Catch {
      Write-Host "Waiting on metadata..."
      Start-Sleep 5
    } 
  }
  Write-Host "Contacted metadata server. Proceeding..."
}

Write-SerialPort "We are in the powershell script"
Write-Host "Getting network config..."
# reconfigure dhcp address as static
$IpAddr = Get-NetIPAddress -InterfaceAlias Ethernet -AddressFamily IPv4
$IpConf = Get-NetIPConfiguration -InterfaceAlias Ethernet
$originalGateway=$IpConf.IPv4DefaultGateway.NextHop
$pfxlen=$IpAddr.PrefixLength 

$msg="Image Instance has an IP address of: " + $IpAddr.IPAddress + " and a gateway of: " + $IpConf.IPv4DefaultGateway.NextHop
Write-SerialPort $msg

$msg="Fetching arguments from metadata"
Write-SerialPort $msg

$ipaddress = Invoke-RestMethod -Headers @{"Metadata-Flavor" = "Google"} -Uri http://169.254.169.254/computeMetadata/v1/instance/attributes/ipaddr
$gateway = Invoke-RestMethod -Headers @{"Metadata-Flavor" = "Google"} -Uri http://169.254.169.254/computeMetadata/v1/instance/attributes/gateway
$name =  Invoke-RestMethod -Headers @{"Metadata-Flavor" = "Google"} -Uri http://169.254.169.254/computeMetadata/v1/instance/name 
$zone = Invoke-RestMethod -Headers @{"Metadata-Flavor" = "Google"} -Uri http://169.254.169.254/computeMetadata/v1/instance/zone

$msg="Desired Ip address: " + $ipaddress + " Gatway is: " + $gateway + ". Orinial gateway was " + $originalGateway
Write-SerialPort $msg

try
{
  $msg="Now removing the following gateway: " + $Ipconf.IPv4DefaultGateway.NextHop
  Write-SerialPort $msg

  Get-NetRoute -CimSession $name | where NextHop -eq $originalGateway | Remove-NetRoute 

}
catch [Exception]
{
  Write-SerialPort "I just can't seen to get the old gateway removed"
}

Set-NetIPInterface `
	-InterfaceAlias Ethernet `
	-Dhcp Enabled

Write-SerialPort "Wait for NIC to reset to DHCP"
Wait-For-Metadata

$IpAddr = Get-NetIPAddress -InterfaceAlias Ethernet -AddressFamily IPv4

$msg="DHCP has now assigned " + $IpAddr.IPAddress
Write-SerialPort $msg

Set-NetIPInterface `
	-InterfaceAlias Ethernet `
	-Dhcp Disabled

Write-SerialPort "Wait 5 seconds for NIC to reset to static"
Wait-For-Metadata

New-NetIPAddress `
	-InterfaceAlias Ethernet `
	-IPAddress $ipaddress `
	-AddressFamily IPv4 `
	-PrefixLength $pfxlen `
	-DefaultGateway $gateway

$msg="Finished adding the new IP, now to remove the old one;" + $originalGateway + ". Will wait 5 seconds."
Write-Host $msg

Start-Sleep 5

try{
  # Remove the default gateway
  Get-NetRoute -CimSession $name | where NextHop -eq $originalGateway | Remove-NetRoute 
}
catch [Exception]
{
  Write-SerialPort "It just won't go without a fight"
}

$msg="Setting the DNS server to " + $gateway
Write-SerialPort $msg

# set dns to google cloud default, will be set to loopback once dns feature is installed
Set-DnsClientServerAddress -InterfaceAlias Ethernet -ServerAddresses $gateway
Wait-For-Metadata

#Now remove the script so it does not repeatedly waste time doing this stuff
gcloud compute instances remove-metadata "$name" --zone $zone --keys windows-startup-script-ps1

$msg="Getting the state of the DNS Servers"
Write-SerialPort $msg

#Verify what the DNS Servers are now set to
$DNSServerAddresses=Get-DnsClientServerAddress -AddressFamily IPv4 -InterfaceAlias Ethernet 
Write-SerialPort $DNSServerAddresses.ServerAddresses
