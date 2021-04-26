# win-crossregion-reip

This project details a powershell script that can be executed at startup on a GCE, Windows VM, that has been created from an image of another VM, to automatically change the IP address to a new one that has been inserted into metadata.

This solves that problem of restoring for DR purposes, and adding the instance on a subnet on which it will be unable to communicate, without the execution of such a script.

Note: DHCP is still the preferred solution.  This solution is a work-around in the event that you absolutely must use static IP addresses which should be avoided.
