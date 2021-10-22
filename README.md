# ssh-vm
A helpful function that invokes SSH to VMs hosted on Windows 10 running Hyper-V using the default NAT switch.

A permanent virtual switch is created whenever the Hyper-V feature is enabled on Windows 10 which creates a NAT network for hosted VMs to have network access.
However, IPs are dynamically assigned and it just got annoying when IPs on my VMs would randomly change.

So I wrote a PowerShell function which would invoke SSH to the current IP of whatever VM provided at runtime. I took it a step further because I'm lazy and made the parameter used to specify the VM, dynamic based on the names of the VMs on the current host. Which means the Hyper-V module needs to be available.

# Quick notes
Beyond the basic sourcing the script to define the function, I recommend adding your user account to the "Hyper-V Administrators" group. This allows non-administrators to manage Hyper-V (and use the required PS cmdlets). By default, the Hyper-V PS cmdlets this function relies on to get and resolve the IPs for the autocompletion and IP resolution of the VMs, require administrator rights meaning this function would only be useable in elevated windows.

I did not want to have to leave an elevated window open just to use this function.

Anyway, hope it helps.
