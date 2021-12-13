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
            Write-Error "The requested VM was found but not running." -RecommendedAction "Start the VM before re-running this or re-run and use the -Force parameter to attempt to start the VM prior to invoking SSH." -ErrorAction Stop
        }
        if($Force.IsPresent){
            if($(Get-VM -ComputerName $VMHost -VMName $VMName).State -ne 'Running'){
                Start-VM -ComputerName $VMHost -VMName $VMName
                $Timer = 2
                $Timeout = 10
                [array]$IpAddresses = @()
                Start-Sleep -Seconds $Timer #Added as an initial delay for started VMs.
                Do {
                    Start-Sleep -Seconds 1
                    $Timer++
                    Get-VMNetworkAdapter -ComputerName $VMHost -VMName $VMName | Select-Object -ExpandProperty IPAddresses | Set-Variable -Name IpAddresses
                    Write-Verbose "VM started $Timer second(s) ago. Waiting for an IP address (wait timeout is set to $Timeout seconds)."
                }
                Until ($($IpAddresses.Count -gt 0) -or $($Timer -ge $Timeout))
            }
        }
        $IpAddresses = Get-VMNetworkAdapter -ComputerName $VMHost -VMName $VMName | Select-Object -ExpandProperty IPAddresses
        if($IpAddresses.Count -eq 0){
            Write-Error 'No IP address could be found before wait timeout was reached.' -RecommendedAction 'Ensure Guest Services are enabled and are running on the virtual machine.' -ErrorAction Stop
        }
        if($ClipboardIPAddressOnly.IsPresent){
            Set-Clipboard -Value $IpAddresses[0]
        }else {
            Write-Verbose "Invoking command: ssh -o StrictHostKeyChecking=no $LoginName$($IpAddresses[0])"
            Invoke-Expression -Command "ssh -o StrictHostKeyChecking=no $LoginName$($IpAddresses[0])"
        }
    }
}
