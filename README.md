# win-crossregion-reip

This project details a powershell script that can be executed at startup on a GCE, Windows VM, that has been created from an image of another VM, to automatically change the IP address to a new one that has been inserted into metadata.

This solves that problem of restoring for DR purposes, and adding the instance on a subnet on which it will be unable to communicate, without the execution of such a script.

Note: DHCP is still the preferred solution.  This solution is a work-around in the event that you absolutely must use static IP addresses which should be avoided.



Here is an example of a command to provison an instance, inserting the appropriate metadata to allow the process to succeed:

  gcloud beta compute --project={your-project-name} instances create {instance} \
--zone=us-east1-b \
--source-machine-image {image you made from your prod instance} \
--machine-type=e2-medium \
--subnet=ipmigration-east-subnet \
--private-network-ip=10.0.2.10 \
--metadata ipaddr=10.0.2.10,gateway=10.0.2.1\
--metadata-from-file windows-startup-script-ps1=windows-set-static.ps1 \
--service-account={machine service account} --scopes=https://www.googleapis.com/auth/cloud-platform,storage-ro \
--tags=rdp


Example of how these metadata keys get accessed from within windows:

#Customer metadata
$ipaddress = Invoke-RestMethod -Headers @{"Metadata-Flavor" = "Google"} -Uri http://169.254.169.254/computeMetadata/v1/instance/attributes/ipaddr
$gateway = Invoke-RestMethod -Headers @{"Metadata-Flavor" = "Google"} -Uri http://169.254.169.254/computeMetadata/v1/instance/attributes/gateway

#Standard metadata
$name =  Invoke-RestMethod -Headers @{"Metadata-Flavor" = "Google"} -Uri http://169.254.169.254/computeMetadata/v1/instance/name
$zone = Invoke-RestMethod -Headers @{"Metadata-Flavor" = "Google"} -Uri http://169.254.169.254/computeMetadata/v1/instance/zone

#Remove the script from metadata so it doesn't get called again
gcloud compute instances remove-metadata "$name" --zone $zone --keys windows-startup-script-ps1
