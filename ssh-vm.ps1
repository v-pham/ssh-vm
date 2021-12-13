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
        $Timeout = 4
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
            Write-Error "The requested VM was found but not running." -RecommendedAction "Either start the VM or use the -Force parameter to attempt to start the VM prior to invoking SSH." -ErrorAction Stop
        }
        if($Force.IsPresent){
            if($(Get-VM -ComputerName $VMHost -VMName $VMName).State -ne 'Running'){
                Start-VM -ComputerName $VMHost -VMName $VMName
                $Timer = 0
                Do {
                    Start-Sleep -Seconds 1
                    $Timer++
                    [array]$IpAddresses = Get-VMNetworkAdapter -ComputerName $VMHost -VMName $VMName | Select-Object -ExpandProperty IPAddresses
                }
                While ($($IpAddresses.Count -eq 0) -or $($Timer -ge $Timeout))
            }
        }
        [array]$IpAddresses = Get-VMNetworkAdapter -ComputerName $VMHost -VMName $VMName | Select-Object -ExpandProperty IPAddresses
        if($IpAddresses.Count -eq 0){
            Write-Error 'No IP address could be found on network adapter.' -RecommendedAction 'Ensure Guest Services are enabled and are running on the virtual machine.' -ErrorAction Stop
        }
        if($ClipboardIPAddressOnly.IsPresent){
            Set-Clipboard -Value $IpAddresses[0]
        }else {
            Write-Verbose "Invoking command: ssh -o StrictHostKeyChecking=no $LoginName$($IpAddresses[0])"
            Invoke-Expression -Command "ssh -o StrictHostKeyChecking=no $LoginName$($IpAddresses[0])"
        }
    }
}
