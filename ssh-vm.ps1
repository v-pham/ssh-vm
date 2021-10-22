# To make the uncontrollable, random IP switching less annoying. Requires Hyper-V module (and rights to use the commands). 
# Highly recommend adding user accounts to Hyper-V Administrators group (otherwise, this function would require Administrator rights to work).

function Invoke-SshToVM {
    [CmdletBinding()]
    [Alias("ssh-vm")]
    Param ()
    DynamicParam {
        $ParameterName = 'VM'
        $RuntimeParameterDictionary = New-Object System.Management.Automation.RuntimeDefinedParameterDictionary
        $AttributeCollection = New-Object System.Collections.ObjectModel.Collection[System.Attribute]
        $ParameterAttribute = New-Object System.Management.Automation.ParameterAttribute
        $ParameterAttribute.Mandatory = $true
        $ParameterAttribute.Position = 0
        $AttributeCollection.Add($ParameterAttribute)
        $arrSet = Get-VM | Select-Object -ExpandProperty Name
        $ValidateSetAttribute = New-Object System.Management.Automation.ValidateSetAttribute($arrSet)
        $AttributeCollection.Add($ValidateSetAttribute)
        $RuntimeParameter = New-Object System.Management.Automation.RuntimeDefinedParameter($ParameterName, [string], $AttributeCollection)
        $RuntimeParameterDictionary.Add($ParameterName, $RuntimeParameter)
        return $RuntimeParameterDictionary
    }

    begin {
        $VM = $PsBoundParameters[$ParameterName]
    }

    process{
        [array]$IpAddress = Get-VMNetworkAdapter -VMName $VM | Select-Object -ExpandProperty IPAddresses
        # Added option to ignore HostKeyChecking since the IPs are constantly changing (which is why this function was written in the first place)
        Invoke-Expression -Command "ssh -o StrictHostKeyChecking=no $($IpAddress[0])"
    }
}
