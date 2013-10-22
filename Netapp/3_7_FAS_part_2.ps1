#
# This Powershell script is used to setup performm the actions in tr 3939 section 
#
# The script imports variables that have been derived from the FlexPod Implementation Guide 
# spreadsheet that feed the FlexPod Implementation Guide. The spreaadsheet is used as the source for 
# FlexPod Implementation Guide and mailmerge is used to merge the data from the spreadsheet into 
# the Implementation Guide. 
#
# The script is divided into functions, and the functions are called at the bottom of the script. 
#
# Date       Action    Person Comments
#--------------------------------------------------------------------
# 05-06-2011 Created   MRH 	  Created.
# 06-06-2011 Modified  MRH    Added function capabilities
#

Param(
	[parameter(Mandatory=$true)]
	[string]$csv_file
)

Import-Module DataOntap
Import-Module "..\helpers\FPodConfig"

##Import-Module "C:\Program Files (x86)\NetApp\WFA\PoSH\Modules\DataOntap"
##Import-Module "C:\Program Files (x86)\NetApp\WFA\PoSH\Modules\FPodConfig"

$config = @{}

#$csv_file = "config\fpod.csv"
$config = Read-FPodConfig($csv_file)

### this code reads the file of the running script and checks if all required parameters in $config exist
$scriptfile = $myInvocation.mycommand.path
Test-VarPresence $scriptfile $config

$config.GetEnumerator() | sort name

function replaceNrun([NetApp.Ontapi.Filer.NaController] $controller, $ssh_cmds) {
	
    foreach ($line in $ssh_cmds) {
        
        foreach($item in $config.GetEnumerator()) {
             $line = $line.Replace($item.Name, $item.Value)
             
        }
        
        $line
        
        Invoke-NaSsh  -Command $line -Controller $controller
    }
}

# Gather the NetApp controller credentials
$password = ConvertTo-SecureString $config.Get_Item("<<var_global_default_passwd>>") -AsPlainText -Force
$cred = New-Object -TypeName System.Management.Automation.PSCredential -ArgumentList "root",$password

# Connect to controllers
#Add-NaCredential -Controller $config.Get_Item("<<var_ntap_A_mgmt_int_IP>>") -Credential "root"
$controllera = Connect-NaController -Name $config.Get_Item("<<var_ntap_A_mgmt_int_IP>>") -Credential $cred 
$controllerb = Connect-NaController -Name $config.Get_Item("<<var_ntap_B_mgmt_int_IP>>") -Credential $cred 
Write-Host "Connected to controllers"

##############################################
# Enter commands on the lines below
##############################################

$finalizeA = @("igroup create -f -t vmware esxi4.1_host_<<var_ntap_A_hostname>>_2a1 <<var_ucsm_spA_vHBA_A_wwpn>> <<var_ucsm_spA_vHBA_B_wwpn>>", 
                "igroup set esxi4.1_host_<<var_ntap_A_hostname>>_2a1 alua yes",
                "lun create -s 10g -t vmware -o noreserve /vol/esxi_boot_A/esxi4.1_host_<<var_ntap_A_hostname>>_2a1",
                "lun map /vol/esxi_boot_A/esxi4.1_host_<<var_ntap_A_hostname>>_2a1 esxi4.1_host_<<var_ntap_A_hostname>>_2a1 0")


$finalizeB = @("igroup create -f -t vmware esxi4.1_host_<<var_ntap_B_hostname>>_2b1 <<var_ucsm_spB_vHBA_A_wwpn>> <<var_ucsm_spB_vHBA_B_wwpn>>",
                "igroup set esxi4.1_host_<<var_ntap_B_hostname>>_2b1 alua yes",
                "lun create -s 10g -t vmware -o noreserve /vol/esxi_boot_B/esxi4.1_host_<<var_ntap_B_hostname>>_2b1",
                "lun map /vol/esxi_boot_B/esxi4.1_host_<<var_ntap_B_hostname>>_2b1 esxi4.1_host_<<var_ntap_B_hostname>>_2b1 0")


replaceNrun $controllera $finalizeA
replaceNrun $controllerb $finalizeB