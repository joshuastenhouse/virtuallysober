########################################################################################################################
# Start of the script - Description, Requirements & Legal Disclaimer
########################################################################################################################
# Written by: Joshua Stenhouse joshuastenhouse@gmail.com
################################################
# Description:
# This script shows you how to connect to a vSphere 6.5 vCenter REST API, get a list of VMs and use each VM mo ref to get more info
################################################ 
# Requirements:
# - Run PowerShell as administrator with command "Set-ExecutionPolcity unrestricted" on the host running the script
# - A v6.5 vCenter
# - A username and password that can authenticate with the vCenter
# - To view what REST APIs are avaible use swagger on your vCenter by browsing to https://vCenterName/apiexplorer/
################################################
# Legal Disclaimer:
# This script is written by Joshua Stenhouse is not supported under any support program or service. 
# All scripts are provided AS IS without warranty of any kind. 
# The author further disclaims all implied warranties including, without limitation, any implied warranties of merchantability or of fitness for a particular purpose. 
# The entire risk arising out of the use or performance of the sample scripts and documentation remains with you. 
# In no event shall its authors, or anyone else involved in the creation, production, or delivery of the scripts be liable for any damages whatsoever (including, without limitation, damages for loss of business profits, business interruption, loss of business information, or other pecuniary loss) arising out of the use of or inability to use the sample scripts or documentation, even if the author has been advised of the possibility of such damages.
################################################
# Configure the variables below for the vCenter
################################################
$RESTAPIServer = "192.168.1.10"
# Prompting for credentials
$Credentials = Get-Credential -Credential $null
$RESTAPIUser = $Credentials.UserName
$Credentials.Password | ConvertFrom-SecureString
$RESTAPIPassword = $Credentials.GetNetworkCredential().password
################################################
# Nothing to configure below this line - Starting the main function of the script
################################################
# NOTE: Using regions to split up the demo script into 3 parts
#region1 
################################################
# Adding certificate exception to prevent API errors
################################################
add-type @"
    using System.Net;
    using System.Security.Cryptography.X509Certificates;
    public class TrustAllCertsPolicy : ICertificatePolicy {
        public bool CheckValidationResult(
            ServicePoint srvPoint, X509Certificate certificate,
            WebRequest request, int certificateProblem) {
            return true;
        }
    }
"@
[System.Net.ServicePointManager]::CertificatePolicy = New-Object TrustAllCertsPolicy
################################################
# Building vCenter API string & invoking REST API
################################################
$BaseAuthURL = "https://" + $RESTAPIServer + "/rest/com/vmware/cis/"
$BaseURL = "https://" + $RESTAPIServer + "/rest/vcenter/"
$vCenterSessionURL = $BaseAuthURL + "session"
$Header = @{"Authorization" = "Basic "+[System.Convert]::ToBase64String([System.Text.Encoding]::UTF8.GetBytes($RESTAPIUser+":"+$RESTAPIPassword))}
$Type = "application/json"
# Authenticating with API
Try 
{
$vCenterSessionResponse = Invoke-RestMethod -Uri $vCenterSessionURL -Headers $Header -Method POST -ContentType $Type
}
Catch 
{
$_.Exception.ToString()
$error[0] | Format-List -Force
}
# Extracting the session ID from the response
$vCenterSessionHeader = @{'vmware-api-session-id' = $vCenterSessionResponse.value}
###############################################
# Getting list of VMs
###############################################
$VMListURL = $BaseURL+"vm"
Try 
{
$VMListJSON = Invoke-RestMethod -Method Get -Uri $VMListURL -TimeoutSec 100 -Headers $vCenterSessionHeader -ContentType $Type
$VMList = $VMListJSON.value
}
Catch 
{
$_.Exception.ToString()
$error[0] | Format-List -Force
}
$VMList | Format-Table -AutoSize
#endregion1 
###############################################
# Getting detailed info for each VM, its disks and nics as the VM API doesn't have much info
###############################################
#region2
# Creating arrays to store information gathered
$VMArray=@()
$VMDiskArray=@()
$VMNICArray=@()
# Performing for each VM action
ForEach ($VM in $VMList)
{
# Selecting the MoRef
$VMMoRef = $VM.vm
# Building Query
$VMInfoURL = $VMListURL + "/$VMMoRef"
# Calling API to get more info
Try 
{
$VMInfoJSON = Invoke-RestMethod -Uri $VMInfoURL -TimeoutSec 100 -Headers $vCenterSessionHeader -ContentType $Type
$VMInfo = $VMInfoJSON.value
}
Catch 
{
$_.Exception.ToString()
$error[0] | Format-List -Force
}
#######################
# Assigning sample variables to VM data collected
#######################
$CDROMs = $VMInfo.cdroms.Count
$CDROMState = $VMInfo.cdroms.value.state
$MemoryMB = $VMInfo.memory.size_MiB
$DiskCount = $VMInfo.disks.count
$Parallel_Ports = $VMInfo.parallel_ports.Count
$SATA_Adapters = $VMInfo.sata_adapters.Count
$CPU = $VMInfo.cpu.count
$CoresPerSocket = $VMInfo.cpu.cores_per_socket
$SCSI_Adapters = $VMInfo.scsi_adapters.Count
$Power_State = $VMInfo.power_state
$Floppies = $VMInfo.floppies.Count
$Name = $VMInfo.name
$NICCount = $VMInfo.nics.Count
$BootType = $VMInfo.boot.type
$Serial_Ports = $VMInfo.serial_ports.Count
$Guest_OS = $VMInfo.guest_OS
$Boot_Devices = $VMInfo.boot_devices
$HardwareVersion = $VMInfo.hardware.version
$HardwareUpgradePolicy = $VMInfo.hardware.upgrade_policy
$HardwareUpgradeStatus = $VMInfo.hardware.upgrade_status
# Converting RAM MB to GB
$MemoryGB = $MemoryMB /1024
$MemoryGB = [Math]::Round($MemoryGB, 1)
# Calculating total cores
$TotalCores = $CoresPerSocket * $CPU
# Creating table array with information gathered that I feel is useful, not keeping everything
$VMArrayLine = new-object PSObject
$VMArrayLine | Add-Member -MemberType NoteProperty -Name "VM" -Value "$Name"
$VMArrayLine | Add-Member -MemberType NoteProperty -Name "GuestOS" -Value "$Guest_OS"
$VMArrayLine | Add-Member -MemberType NoteProperty -Name "MoRef" -Value "$VMMoRef"
$VMArrayLine | Add-Member -MemberType NoteProperty -Name "CPUs" -Value $CPU
$VMArrayLine | Add-Member -MemberType NoteProperty -Name "Cores" -Value $TotalCores
$VMArrayLine | Add-Member -MemberType NoteProperty -Name "RAM" -Value $MemoryGB
$VMArrayLine | Add-Member -MemberType NoteProperty -Name "NICs" -Value $NICCount
$VMArrayLine | Add-Member -MemberType NoteProperty -Name "Disks" -Value $DiskCount
$VMArrayLine | Add-Member -MemberType NoteProperty -Name "PowerState" -Value "$Power_State"
$VMArrayLine | Add-Member -MemberType NoteProperty -Name "HardwareVersion" -Value "$HardwareVersion"
$VMArrayLine | Add-Member -MemberType NoteProperty -Name "CDRomState" -Value "$CDROMState"
$VMArrayLine | Add-Member -MemberType NoteProperty -Name "BootType" -Value "$BootType"
$VMArray += $VMArrayLine
#######################
# Getting more info on NICS for separate table array
#######################
$NICList = $VMInfo.nics
ForEach ($NIC in $NICList)
{
# Assigning sample variables to data collected
$Label = $NIC.value.label
$MAC_Address = $NIC.value.mac_address
$MAC_Type = $NIC.value.mac_type
$Allow_Guest_Control = $NIC.value.allow_guest_control
$Wake_On_LAN_Enabled = $NIC.value.wake_on_lan_enabled
$State = $NIC.value.state
$Type = $NIC.value.type
$UPT_Compatibility_Enabled = $NIC.value.upt_compatibility_enabled
$Start_Connected = $NIC.value.start_connected
$PortGroupType = $NIC.value.backing.type
$PortGroupName = $NIC.value.backing.network_name
$PortGroupID = $NIC.value.backing.network
# Creating table array with information gathered that I feel is useful, not keeping everything
$VMNICArrayLine = new-object PSObject
$VMNICArrayLine | Add-Member -MemberType NoteProperty -Name "NIC" -Value "$Label"
$VMNICArrayLine | Add-Member -MemberType NoteProperty -Name "VM" -Value "$Name"
$VMNICArrayLine | Add-Member -MemberType NoteProperty -Name "MoRef" -Value "$VMMoRef"
$VMNICArrayLine | Add-Member -MemberType NoteProperty -Name "Type" -Value "$Type"
$VMNICArrayLine | Add-Member -MemberType NoteProperty -Name "State" -Value "$State"
$VMNICArrayLine | Add-Member -MemberType NoteProperty -Name "StartState" -Value "$Start_Connected"
$VMNICArrayLine | Add-Member -MemberType NoteProperty -Name "MAC" -Value "$MAC_Address"
$VMNICArrayLine | Add-Member -MemberType NoteProperty -Name "MACType" -Value "$MAC_Type"
$VMNICArrayLine | Add-Member -MemberType NoteProperty -Name "PortGroup" -Value "$PortGroupName"
$VMNICArrayLine | Add-Member -MemberType NoteProperty -Name "PortGroupType" -Value "$PortGroupType"
$VMNICArrayLine | Add-Member -MemberType NoteProperty -Name "PortGroupID" -Value "$PortGroupID"
$VMNICArrayLine | Add-Member -MemberType NoteProperty -Name "AllowGuestControl" -Value "$Allow_Guest_Control"
$VMNICArray += $VMNICArrayLine
}
#######################
# Getting more info on disks for separate table array
#######################
$DiskList = $VMInfo.disks
ForEach ($Disk in $DiskList)
{
# Assigning sample variables to data collected
$Label = $Disk.value.label
$SCSIBus = $Disk.value.scsi.bus
$SCSIUnit = $Disk.value.scsi.unit
$VMDK = $Disk.value.backing.vmdk_file
$CapacityBytes = $Disk.value.capacity
$Type = $Disk.value.type
# Calculating capacity in GB and TB from bytes
$CapacityGB = $CapacityBytes / 1000000000
$CapacityGB = [Math]::Round($CapacityGB, 2)
$CapacityTB = $CapacityGB / 1000
$CapacityTB = [Math]::Round($CapacityTB, 2)
# Creating table array with information gathered that I feel is useful, not keeping everything
$VMDiskArrayLine = new-object PSObject
$VMDiskArrayLine | Add-Member -MemberType NoteProperty -Name "Disk" -Value "$Label"
$VMDiskArrayLine | Add-Member -MemberType NoteProperty -Name "VM" -Value "$Name"
$VMDiskArrayLine | Add-Member -MemberType NoteProperty -Name "MoRef" -Value "$VMMoRef"
$VMDiskArrayLine | Add-Member -MemberType NoteProperty -Name "VMDK" -Value "$VMDK"
$VMDiskArrayLine | Add-Member -MemberType NoteProperty -Name "CapacityTB" -Value $CapacityGB
$VMDiskArrayLine | Add-Member -MemberType NoteProperty -Name "CapacityGB" -Value $CapacityTB
$VMDiskArray += $VMDiskArrayLine
}
# End of for each VM below
}
# End of for each VM above
###############################################
# Output of results
###############################################
"VMs:"
$VMArray | Format-Table -AutoSize
"NICs:"
$VMNICArray | Format-Table -AutoSize
"Disks:"
$VMDiskArray | Format-Table -AutoSize
#endregion2
###############################################
# Power On A VM Demo
###############################################
#region3
$PowerOnVM = $TRUE
$VMToPowerOn = "DemoApp1-VM01"
If ($PowerOnVM -eq $TRUE)
{
# Selecting a VM MoRef
$VMMoRef = $VMArray | Where-Object {$_.VM -eq $VMToPowerOn} | Select -ExpandProperty MoRef
# Building a Power On REST API call
$VMPowerOnURL = $baseURL+"/vm/"+$VMMoRef+"/power/start"
# Only running Post if a VM MoRef is found
If ($VMMoRef -ne $null)
{
# Posting the 
Try 
{
Invoke-RestMethod -Method Post -Uri $VMPowerOnURL -TimeoutSec 100 -Headers $vCenterSessionHeader -ContentType $Type
}
Catch 
{
$_.Exception.ToString()
$error[0] | Format-List -Force
}
}
Else
{
"No VM MoRef Found"
}
}
#endregion3
###############################################
# Get Datastore info demo (this is where you can use the above examples to write your own and I've copied the VMList example, but you need to edit it!)
###############################################
$DatastoreListURL = $BaseURL+"datastore"
Try 
{
$DatastoreListJSON = Invoke-RestMethod -Method Get -Uri $DatastoreListURL -TimeoutSec 100 -Headers $vCenterSessionHeader -ContentType $Type
$DatastoreList = $DatastoreListJSON.value
}
Catch 
{
$_.Exception.ToString()
$error[0] | Format-List -Force
}
$DatastoreList | Format-Table -AutoSize
###############################################
# End of script
###############################################