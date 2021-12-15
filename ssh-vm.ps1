# Requires Hyper-V module

function Invoke-SshToVM {
    [CmdletBinding(DefaultParameterSetName="Default")]
    [Alias("ssh-vm")]
    Param (
        [Parameter(Mandatory=$false)][string]$VMHost=$Env:COMPUTERNAME,
        [Parameter(ParameterSetName="Default",Mandatory=$false)][switch]$ClipboardIPAddressOnly,
        [Parameter(ParameterSetName="AltLogin",Mandatory=$false)][string]$LoginName='',
        [Parameter(Mandatory=$false)][switch]$Force
    )
    DynamicParam {
        $ParameterName = 'VMName'
        $RuntimeParameterDictionary = New-Object System.Management.Automation.RuntimeDefinedParameterDictionary
        $AttributeCollection = New-Object System.Collections.ObjectModel.Collection[System.Attribute]
        $ParameterAttribute = New-Object System.Management.Automation.ParameterAttribute
        $ParameterAttribute.Mandatory = $true
        $ParameterAttribute.Position = 0
        $AttributeCollection.Add($ParameterAttribute)
        if(!$PSBoundParameters.ContainsKey('VMHost')){
            $VMHost=$Env:COMPUTERNAME
        }
        [string[]]$ParamSet = Get-VM -ComputerName $VMHost | Where-Object { $_.State -eq 'Running' } | Select-Object -ExpandProperty Name
        if($ParamSet.Count -eq 0 -or $Force.IsPresent){
            $WarningMessage = 'Autocompletion will include all VMs but will require -Force to attempt to start the VM before invoking SSH.'
            if($ParamSet.Count -eq 0){
                $NoVMsRunning = $true
                $WarningMessage = "No running VMs were found. " + $WarningMessage
            }
            Write-Warning -Message $WarningMessage
            [string[]]$ParamSet = Get-VM | Select-Object -ExpandProperty Name
        }
        $ValidateSetAttribute = New-Object System.Management.Automation.ValidateSetAttribute($ParamSet)
        $AttributeCollection.Add($ValidateSetAttribute)

        $RuntimeParameter = New-Object System.Management.Automation.RuntimeDefinedParameter($ParameterName, [string], $AttributeCollection)
        $RuntimeParameterDictionary.Add($ParameterName, $RuntimeParameter)
        return $RuntimeParameterDictionary
    }

    begin {
        if(!$PSBoundParameters.ContainsKey('VMHost')){
            $VMHost=$Env:COMPUTERNAME
        }
        $VMName = $PsBoundParameters[$ParameterName]
        if($LoginName.Length -gt 0){
            $LoginName = $LoginName + "@"
        }else{
            $LoginName = ""
        }
    }

    process{
        if($NoVMsRunning -and !$Force.IsPresent){
            Write-Error "The requested VM was found but not running." -RecommendedAction "Start the VM before re-running this or re-run with the -Force parameter to attempt to start the VM before invoking SSH." -ErrorAction Stop
        }
        [array]$IpAddresses = @()
        if($Force.IsPresent){
            if($(Get-VM -ComputerName $VMHost -VMName $VMName).State -ne 'Running'){
                Start-VM -ComputerName $VMHost -VMName $VMName
                $Timer = 2
                $Timeout = 10
                Start-Sleep -Seconds $Timer #Added as an initial delay for started VMs.
                Do {
                    Start-Sleep -Seconds 1
                    $Timer++
                    $IPAddresses = Get-VMNetworkAdapter -ComputerName $VMHost -VMName $VMName | Select-Object -ExpandProperty IPAddresses
                    Write-Verbose "VM started $Timer second(s) ago. Waiting for an IP address (wait timeout is set to $Timeout seconds)."
                    $ValidIP = Test-Connection $IpAddresses[0] -Ping -IPv4 -Count 1 | Select-Object -ExpandProperty Status
                }
                Until ($($IpAddresses.Count -gt 0) -or $($Timer -ge $Timeout))
            }
        } else {
            $IpAddresses = Get-VMNetworkAdapter -ComputerName $VMHost -VMName $VMName | Select-Object -ExpandProperty IPAddresses
        }
        if($IpAddresses.Count -eq 0){
            Write-Error 'No IP address could be found before wait timeout was reached.' -RecommendedAction 'Ensure Guest Services are enabled and are running on the virtual machine.' -ErrorAction Stop
        }
        if($ClipboardIPAddressOnly.IsPresent){
            Set-Clipboard -Value $IpAddresses[0]
        }else {
            if($LoginName.Length -eq 0){
                [string[]]$SshConfig = $(Get-Content $Env:USERPROFILE\.ssh\config).split([System.Environment]::NewLine)
                $Match = $false
                $i=0
                ForEach($line in $SSHConfig){
                    $i++
                    if($Match -eq $true -and $line.Trim().ToLower().StartsWith('host ')){
                        Write-Verbose "No user was configured."
                        break
                    }elseif($Match -eq $false -and $line.Trim().ToLower().StartsWith('host ')){
                        $($line.ToLower() -replace 'host ').split(' ') | foreach {
                            if($VMName.ToLower() -like "$_"){
                                Write-Verbose "`"$VMName`" matched host `"$_`" and will use the configured user login, if specified."
                                $Match = $true
                            }
                        }
                    }
                    if($Match -eq $true -and $line.Trim().ToLower().StartsWith('user ')){
                        $LoginName = $($line.Trim().ToLower() -replace 'user ').Trim() + "@"
                        break
                    }
                }
            }
            Write-Verbose "Invoking command: ssh -o StrictHostKeyChecking=no $LoginName$($IpAddresses[0])"
            Invoke-Expression -Command "ssh -o StrictHostKeyChecking=no $LoginName$($IpAddresses[0])"
        }
    }
}
