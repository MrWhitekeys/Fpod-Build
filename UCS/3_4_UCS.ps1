Param(
	[parameter(Mandatory=$true)]
	[string]$csv_file
)

Import-Module "..\helpers\FPodConfig"
## Import-Module "..\helpers\UCShelper"
Import-Module "C:\Program Files\Cisco\Cisco UCS PowerTool\CiscoUcsPS.psd1"

## Compute the last address of a mac pool according to its size and starting address
## TODO: Use to compute wwnn/wwpn
## TODO: function returns one address to much
function Get-MacPoolEnd {
param([string] $startAddress, [int] $poolSize)
    ## Remove colons
    $startAddress = $startAddress.Replace(":", "")

    ## Compute the last address in decimal and convert back to hex
    $macPoolEnd = [convert]::toInt64($startAddress, 16) + $poolSize
    $macPoolEnd = “{0:x}” -f $macPoolEnd

    ## Append with leading zeros
    $zeroFilledMacPoolEnd = ""
    for($i = 0; $i -lt 12; $i++) {
        if($macPoolEnd[$i]) {
            $zeroFilledMacPoolEnd += $macPoolEnd[$i]
        } else {
            $zeroFilledMacPoolEnd = "0" + $zeroFilledMacPoolEnd
        }
    }
    
    ## Insert colons
    $returnString = ""
    for($i = 0; $i -lt 12; $i++) {
        $returnString += $zeroFilledMacPoolEnd[$i]
        
        if(($i % 2) -and $i -lt 11) {
            $returnString += ":"
        }
    }
    
    return $returnString
}

## $csv_file = "config\fpod.csv"
$config = Read-FPodConfig($csv_file)

### this code reads the file of the running script and checks if all required parameters in $config exist

if($myInvocation.mycommand.path) {
    $scriptfile = $myInvocation.mycommand.path
    Test-VarPresence $scriptfile $config
}

$config.GetEnumerator() | sort name

#############################
## Constants               ##
#############################

## Variables from config
$VAR_UCSM_INFRA_ORG_NAME = $config.Get_Item("<<var_ucsm_infra_org_name>>")
#Set-Variable VAR_UCSM_INFRA_ORG_NAME -option ReadOnly

$VAR_UCSM_INFRA_ORG_DESCR = $config.Get_Item("<<var_ucsm_infra_org_descr>>")
if(!$VAR_UCSM_INFRA_ORG_DESCR) {
    ## TODO: more usefull description or none at all?
    $VAR_UCSM_INFRA_ORG_DESCR = "Created by 3_4_UCS.ps1"
}   
#Set-Variable VAR_UCSM_INFRA_ORG_DESCR -option ReadOnly

$VAR_UCSM_MAC_POOL_A_START = $config.Get_Item("<<var_ucsm_mac_pool_A_start>>")
#Set-Variable VAR_UCSM_MAC_POOL_A_START -option ReadOnly

$VAR_UCSM_MAC_POOL_B_START = $config.Get_Item("<<var_ucsm_mac_pool_B_start>>")
#Set-Variable VAR_UCSM_MAC_POOL_B_START -option ReadOnly

$VAR_GLOBAL_VSAN_A_ID = $config.Get_Item("<<var_global_vsan_A_id>>")
#Set-Variable VAR_GLOBAL_VSAN_A_ID -option ReadOnly

$VAR_GLOBAL_FCOE_A_VLAN_ID = $config.Get_Item("<<var_global_fcoe_A_vlan_id>>")
#Set-Variable VAR_GLOBAL_FCOE_A_VLAN_ID -option ReadOnly

$VAR_GLOBAL_VSAN_B_ID = $config.Get_Item("<<var_global_vsan_B_id>>")
#Set-Variable VAR_GLOBAL_VSAN_B_ID -option ReadOnly

$VAR_GLOBAL_FCOE_B_VLAN_ID = $config.Get_Item("<<var_global_fcoe_B_vlan_id>>")
#Set-Variable VAR_GLOBAL_FCOE_B_VLAN_ID -option ReadOnly

$VAR_NTAP_A_HOSTNAME = $config.Get_Item("<<var_ntap_A_hostname>>")
#Set-Variable VAR_NTAP_A_HOSTNAME -option ReadOnly

$VAR_NTAP_B_HOSTNAME = $config.Get_Item("<<var_ntap_B_hostname>>")
#Set-Variable VAR_NTAP_B_HOSTNAME -option ReadOnly

$VAR_NTAP_A_FC_2A = $config.Get_Item("<<var_ntap_A_fc_2a>>")
#Set-Variable VAR_NTAP_A_FC_2A -option ReadOnly

$VAR_NTAP_B_FC_2A = $config.Get_Item("<<var_ntap_B_fc_2a>>")
#Set-Variable VAR_NTAP_B_FC_2A -option ReadOnly

$VAR_NTAP_A_FC_2B = $config.Get_Item("<<var_ntap_A_fc_2b>>")
#Set-Variable VAR_NTAP_A_FC_2B -option ReadOnly

$VAR_NTAP_B_FC_2B = $config.Get_Item("<<var_ntap_B_fc_2b>>")
#Set-Variable VAR_NTAP_B_FC_2B -option ReadOnly

## Mac pools
$MAC_POOL_A_NAME = "MAC_Pool_A"
#Set-Variable MAC_POOL_A_NAME -Option ReadOnly

$MAC_POOL_B_NAME = "MAC_Pool_B"
#Set-Variable MAC_POOL_B_NAME -Option ReadOnly

$NUMBER_OF_MAC_ADDRS = 33
#Set-Variable NUMBER_OF_MAC_ADDRS -option ReadOnly

## WWNN pool
$WWNN_POOL_NAME = "WWNNPool"
#Set-Variable WWNN_POOL_NAME -option ReadOnly

$WWNN_POOL_START = "20:00:00:25:B5:00:00:00"
#Set-Variable WWNN_POOL_START -option ReadOnly

$WWNN_POOL_END = "20:00:00:25:B5:00:00:20"
#Set-Variable WWNN_POOL_END -option ReadOnly

# WWPN pools
$WWPN_POOL_A_NAME = "WWPN_Pool_A"
#Set-Variable WWPN_POOL_A_NAME -option ReadOnly

$WWPN_POOL_B_NAME = "WWPN_Pool_B"
#Set-Variable WWPN_POOL_B_NAME -option ReadOnly

$WWPN_POOL_A_START = "20:00:00:25:B5:00:0A:00"
#Set-Variable WWPN_POOL_A_START -option ReadOnly

$WWPN_POOL_A_END = "20:00:00:25:B5:00:0A:3F"
#Set-Variable WWPN_POOL_A_END -option ReadOnly

$WWPN_POOL_B_START = "20:00:00:25:B5:00:0B:00"
#Set-Variable WWPN_POOL_B_START -option ReadOnly

$WWPN_POOL_B_END = "20:00:00:25:B5:00:0B:3F"
#Set-Variable WWPN_POOL_B_END -option ReadOnly

## Vsans
$VSAN_A_NAME = "VSAN_A"
#Set-Variable VSAN_A_NAME -Option ReadOnly

$VSAN_B_NAME = "VSAN_B"
#Set-Variable VSAN_B_NAME -Option ReadOnly

## Network control policy
$NCP_NAME = "Net_Ctrl_Policy"

$BEST_EFFORT_MTU = 9000
#Set-Variable BEST_EFFORT_MTU -option ReadOnly

## vNICs
$VNIC_A_NAME = "vNIC_A"
#Set-Variable VNIC_A_NAME -Option ReadOnly

$VNIC_B_NAME = "vNIC_B"
#Set-Variable VNIC_B_NAME -Option ReadOnly

$VNIC_TEMPLATE_A_NAME = "vNIC_Template_A"
#Set-Variable VNIC_TEMPLATE_A_NAME -option ReadOnly

$VNIC_TEMPLATE_B_NAME = "vNIC_Template_B"
#Set-Variable VNIC_TEMPLATE_B_NAME -option ReadOnly

## vHBAs
$VHBA_A_NAME = "vHBA_A"
#Set-Variable VHBA_A_NAME -Option ReadOnly

$VHBA_B_NAME = "vHBA_B"
#Set-Variable VHBA_B_NAME -Option ReadOnly

$VHBA_TEMPLATE_A_NAME = "vHBA_Template_A"
#Set-Variable VHBA_TEMPLATE_A_NAME -option ReadOnly

$VHBA_TEMPLATE_B_NAME = "vHBA_Template_B"
#Set-Variable VHBA_TEMPLATE_B_NAME -option ReadOnly

## Server pool
$SERVER_POOL_NAME = "Infra-Pool"
#Set-Variable SERVER_POOL_NAME -option ReadOnly

## UUID pool
$UUID_POOL_NAME = "UUID_Pool"
#Set-Variable UUID_POOL_NAME -option ReadOnly

$UUID_POOL_START = "0000-000000000001"
#Set-Variable UUID_POOL_START -Option ReadOnly

$UUID_POOL_END = "0000-000000000064"
#Set-Variable UUID_POOL_END -Option ReadOnly

$FIBER_CHANNEL_SWITCHING_MODE = "end-host"
#Set-Variable FIBER_CHANNEL_SWITCHING_MODE -Option ReadOnly

## Array to loop through both switches
$switchIds_a = "A", "B"

## Match vLan names to ids taken from config
$NAMES_TO_VLANS = @{"MGMT-VLAN" = $config.Get_Item("<<var_global_mgmt_vlan_id>>");
                    "NFS-VLAN" = $config.Get_Item("<<var_global_nfs_vlan_id>>");
                    "vMotion-VLAN" = $config.Get_Item("<<var_global_vmotion_vlan_id>>");
                    "Pkt-Ctrl-VLAN" = $config.Get_Item("<<var_global_packet_control_vlan_id>>");
                    "VM-Traffic-VLAN" = $config.Get_Item("<<var_global_vm_traffic_vlan_id>>");
                    "Native-VLAN" = $config.Get_Item("<<var_global_native_vlan_id>>");}

$Elapsed = [System.Diagnostics.Stopwatch]::StartNew()

#UCS emulator URL set $config.Get_Item("<<var_ucsm_cluster_ip>>") accordingly
## Connection details
$ucsUrl = $config.Get_Item("<<var_ucsm_cluster_ip>>")
$ucsmLogin = $config.Get_Item("<<var_ucsm_cluster_login>>")

$ucsmPass = $config.Get_Item("<<var_global_default_passwd>>")
$ucsmSecPass = ConvertTo-SecureString $ucsmPass -AsPlainText -Force
$ucsmCreds = New-Object System.Management.Automation.PSCredential($ucsmLogin, $ucsmSecPass)

## Make sure no other connection is active
Disconnect-Ucs

## Connect and get handle
$ucsHandle = Connect-Ucs -Name $ucsUrl -Credential $ucsmCreds

##############################################################################
### TODO check 1-link

Write-Host "setting discovery policy"

## get root organization object
$rootOrg = Get-UcsOrg -Level root -Ucs $ucsHandle
#Set-Variable rootOrg -Option ReadOnly

Set-UcsChassisDiscoveryPolicy -Org $rootOrg -Action "2-link" -Rebalance "user-acknowledged" -Ucs $ucsHandle -Force

## configure ports 1 - 6 as server ports on Fabric Interconnects A and B
for($i = 1; $i -le 6; $i++) {
    $slotId = 1
	$port= $i
    
    Write-Host "configuring server ports A/B port: $port"
    
    ## Loop through both switches
    foreach($switchId in $switchIds_a) {
        $fabricServerCloud = Get-UcsFabricServerCloud -Id $switchId -Ucs $ucsHandle
        
        ## Check if port already exists
        $result = Get-UcsServerPort -FabricServerCloud $fabricServerCloud -PortId $port -SlotId $slotId -Ucs $ucsHandle
        if(!$result) {    
            ## Add server port      
            $result = Add-UcsServerPort -FabricServerCloud $fabricServerCloud -PortId $port -SlotId $slotId -Ucs $ucsHandle
        }
        
        ## Add endpoint to server port
        ## TODO: neccessary?
        
		if($result) {
			#$endpoint = New-Object Cisco.Ucs.FabricDceSwSrvEp
	        #$endpoint.Dn = "fabric/server/sw-$switchId/slot-1-port-$port"
	        #Set-UcsServerPort -ServerPort $endpoint -Ucs $ucsHandle -Force
			
			Set-UcsServerPort -ServerPort $result -Ucs $ucsHandle -Force
		} 
		else {
			write-Host "failed to add and configure serverport"
		}
    }
}

##############################################################################

## configure ports 19 - 20 as uplink ports on Fabric Interconnects A and B
Write-Host "enable uplinkports A/B"

for($i = 19; $i -le 20; $i++) {
    $slotId = 1
	$port = $i;

    foreach($switchId in $switchIds_a) {
        $fabricLanCloud = Get-UcsFabricLanCloud -Id $switchId -Ucs $ucsHandle
    
        $result = Get-UcsUplinkPort -FabricLanCloud $fabricLanCloud -PortId $port -SlotId $slotId -Ucs $ucsHandle
        if(!$result) {            
            $result = Add-UcsUplinkPort -FabricLanCloud $fabricLanCloud -PortId $port -SlotId $slotId -AdminSpeed "10gbps" -Ucs $ucsHandle
        }
        
        if($result) {
			#$uPort = New-Object Cisco.Ucs.FabricEthLanEp
       		#$uPort.Dn = "fabric/lan/$switchId/phys-slot-1-port-$port"
			#Set-UcsUplinkPort -UplinkPort $uPort -Ucs $ucsHandle -Force
			
			Set-UcsUplinkPort -UplinkPort $result -AdminState "enabled" -Ucs $ucsHandle -Force
		} 
		else {
			write-Host "failed to add and configure uplinkport"
		}        
    }
}

##############################################################################

## disable fc uplink ports 3- 8 on Fabric Interconnects A and B
for($i = 3; $i -le 8; $i++) {
    $slotId = 2
	$port = $i
    
    Write-Host "disable fcs A/B port: $port"
    
    foreach($switchId in $switchIds_a) {
        $fabricSanCloud = Get-UcsFabricSanCloud -Id $switchid -Ucs $ucsHandle
    
        $result = Get-UcsFcUplinkPort -FabricSanCloud $fabricSanCloud -PortId $port -SlotId $slotId -Ucs $ucsHandle
        if($result) {            
            Set-UcsFcUplinkPort -FcUplinkPort $result -AdminState "disabled" -Ucs $ucsHandle -Force
        }
    }
}

##############################################################################

## configure fc ports 1 - 2 as uplink ports on Fabric Interconnects A and B
Write-host "enable fc uplink ports"

for($i = 1; $i -le 2; $i++) {
    $slotId = 2
	$port = $i
    
    foreach($switchId in $switchIds_a) {
        $fabricSanCloud = Get-UcsFabricSanCloud -Id $switchId
    
        $result = Get-UcsFcUplinkPort -FabricSanCloud $fabricSanCloud -PortId $port -SlotId $slotId -Ucs $ucsHandle
        if(!$result) {            
            $result = Add-UcsFcUplinkPort -FabricSanCloud $fabricSanCloud -PortId $port -SlotId $slotId -Ucs $ucsHandle
        }
        
        if($result) {
			#$fcUPort = New-Object Cisco.Ucs.FabricFcSanEp
        	#$fcUPort.Dn = "fabric/san/$switchId/phys-slot-2-port-$port"
           	#Set-UcsFcUplinkPort -FcUplinkPort $fcUPort -Ucs $ucsHandle -Force
						
			Set-UcsFcUplinkPort -FcUplinkPort $result -AdminState "enabled" -Ucs $ucsHandle -Force
		} 
		else {
			write-Host "failed to enable uplinkports"
		}  
    }
}

##############################################################################

#set-FC-switching-mode "switch"
Write-host "set FC mode"

## for 5010 switches put the ucs in fc end-host mode
## Switching mode
	$mode = $FIBER_CHANNEL_SWITCHING_MODE

	## Use xml, since the according powershell function doesn't seem to be implemented
	$cmd = "<configConfMo dn='fabric/san' inHierarchical='false'>
	            <inConfig>
	                <fabricSanCloud dn='fabric/san' mode='" + $mode + "' >
	                </fabricSanCloud>
	            </inConfig>
	        </configConfMo>"
	     
	$result = Invoke-UcsXml -XmlQuery $cmd -Ucs $ucsHandle
	
	if($result) {
		write-Host $result
	}

## waiting for reboot of ucsm
# Start-Sleep -Seconds 300

## for chassis 2 and 3 doe enabble-FC-uplinks

##############################################################################

## create the organization
Write-host "create organization : $VAR_UCSM_INFRA_ORG_NAME"

	$ourOrg

	## Check if organisation already exists
	$result = Get-UcsOrg -Org $rootOrg -Name $VAR_UCSM_INFRA_ORG_NAME -Ucs $ucsHandle
	if(!$result) {
	    $ourOrg = Add-UcsOrg -Org $rootOrg -Name $VAR_UCSM_INFRA_ORG_NAME -Descr $VAR_UCSM_INFRA_ORG_DESCR -Ucs $ucsHandle
	} else {
	    Write-host "organisation $VAR_UCSM_INFRA_ORG_NAME already exists, skipping"
	    $ourOrg = $result
	}

#Set-Variable $ourOrg -Option ReadOnly

##############################################################################

# create mac pool in organization ourOrg
# NOTE the pool and its range are fix
### need to make use of var_ucsm_mac_pool_A_starts var_ucsm_mac_pool_B_starts
write-host "create mac pool in org: $VAR_UCSM_INFRA_ORG_NAME"

	$organization = $rootOrg

	foreach($switchId in $switchIds_a) {
	    $variable = "MAC_POOL_" + $switchId + "_NAME"
	    $macPoolName = Get-Variable $variable -ValueOnly

	    $result = Get-UcsMacPool -Name $macPoolName -Org $organization -Ucs $ucsHandle
	    if($result) {
	        $organizationName = $organization.Name
	        Write-Host "mac pool $macPoolName already exists in org $organization.Name, replacing"
	        
	        Remove-UcsMacPool -MacPool $result -Ucs $ucsHandle -Force
	    }

	    $macPool = Add-UcsMacPool -Org $organization -Name $macPoolName -Descr "Fabric $switchId Mac Pool" -Ucs $ucsHandle

	    $variable = "VAR_UCSM_MAC_POOL_" + $switchId + "_START"
	    $macPoolStart = Get-Variable $variable -ValueOnly

	    $macPoolEnd = Get-MacPoolEnd $macPoolStart $NUMBER_OF_MAC_ADDRS

	    Add-UcsMacMemberBlock -MacPool $macPool -From $macPoolStart -To $macPoolEnd -Ucs $ucsHandle
	}    

##############################################################################
## create vlans
## TODO: VLANs created system wide, VSANs per switch

	$fabricEthLan = New-Object Cisco.Ucs.FabricEthLan
	$fabricEthLan.Dn = "fabric/lan"

	foreach($item in $NAMES_TO_VLANS.GetEnumerator()) {
	    $vLanName = $item.Name

	    Write-Host "create vlan: $vLanName"
	    
	    $result = Get-UcsVlan -FabricLanCloud $fabricEthLan -Name $vLanName -Ucs $ucsHandle
	    if(!$result) {
	        if($vlanName -eq "Native-VLAN") {
				$native = "true"
			} else {
				$native = "false"
			}
			
			Add-UcsVlan -FabricLanCloud $fabricEthLan -Name $vLanName -Id $item.Value -DefaultNet $native -Ucs $ucsHandle
			
	    } else {
	        Write-host "vlan $vLanName already exists, skipping"
	    }
	}

##############################################################################
# create net control policy in organization
Write-Host "create network control policy"

	$ourNCP
	$organization = $rootOrg

	$result = Get-UcsNetworkControlPolicy -Org $organization -Name $NCP_NAME -Ucs $ucsHandle
	if(!$result) {
	    $ourNCP = Add-UcsNetworkControlPolicy -Org $organization -Name $NCP_NAME -Ucs $ucsHandle
	    $ourNCP
	} else {
	    Write-host "network control policy $NCP_NAME already exists, skipping"
	    $ourNCP = $result
	}    

	Set-UcsNetworkControlPolicy -NetworkControlPolicy $ourNCP -Cdp "enabled" -UplinkFailAction "link-down" -Ucs $ucsHandle -Force

##############################################################################
# create vnic template for fabric a and b
write-host "create vnic templates"

$organization = $rootOrg

	# Add-UcsVnicTemplate -Org $rootOrg -Name "gaga" -IdentPoolName "MAC_Pool_A" -Mtu 9000 -NwCtrlPolicyName "Net_Ctrl_policy"  -SwitchId "A" -TemplType "updating-template" -Target "vm"
	# $z = Add-UcsVnicTemplate -Org $rootOrg -Name "gaga" -IdentPoolName "MAC_Pool_A" -Mtu 9000 -NwCtrlPolicyName "Net_Ctrl_policy"  -SwitchId "A" -TemplType "updating-template" 
	# Add-UcsVnicInterface -VnicTemplate $z -Name "MGMT-VLAN"

	foreach($switchId in $switchIds_a) {
	    $orgName = $organization.Name
	    
	    $variable = "VNIC_TEMPLATE_" + $switchId + "_NAME"
	    $vNicTemplateName = Get-Variable $variable -ValueOnly
	    
	    $vNicTemplateDescr = $vNicTemplateName + " description"
	    
	    $variable= "MAC_POOL_" + $switchId + "_NAME"
	    $macPoolName = Get-Variable $variable -ValueOnly

	    $result = Get-UcsVnicTemplate -Org $organization -Name $vNicTemplateName -Ucs $ucsHandle
	    if($result) {
	        Write-Host "vNIC template $vNicTemplateName already exists in org $($ourOrg.Name), replacing"
	        Remove-UcsVnicTemplate -VnicTemplate $result -Ucs $ucsHandle -Force
	    }

		$z = Add-UcsVnicTemplate -Org $rootOrg -Name $vNicTemplateName -IdentPoolName $macPoolName -Mtu 9000 -NwCtrlPolicyName $NCP_NAME -SwitchId $switchId -TemplType "updating-template" 
		
		foreach($item in $NAMES_TO_VLANS.GetEnumerator()) {
	    	
			#Add-UcsVnicInterface -VnicTemplate $z -Name $item.Name
			
			if($item.Name -eq "Native-VLAN") {
				#Add-UcsVnicInterface -VnicTemplate $z -Name $item.Name -DefaultNet "yes"
				$native = "true"
			} 
			else {
				#Add-UcsVnicInterface -VnicTemplate $z -Name $item.Name -DefaultNet "no"
				$native = "false"
			}
			
			Add-UcsVnicInterface -VnicTemplate $z -Name $item.Name -DefaultNet $native
		}
		
	    Get-UcsVnicTemplate -Org $organization -Name $vNicTemplateName -Ucs $ucsHandle
	}

##############################################################################
# set jumbo frames in fabric

write-host "set MTU"

	Set-UcsBestEffortQosClass -Mtu $BEST_EFFORT_MTU -Ucs $ucsHandle -Force

##############################################################################
# create uplink port channel

write-host "create uplink port channels"

	$switchToPortChannelId_h = @{"A" = 13; "B" = 14}
	foreach($switchId in $switchToPortChannelId_h.keys) {
	    $portId = $switchToPortChannelId_H.Get_Item($switchId)

	    $fabricLan = Get-UcsFabricLanCloud -Dn "fabric/lan/$switchId" -Ucs $ucsHandle
	    
	    $result = Get-UcsUplinkPortChannel -FabricLanCloud $fabricLan -PortId $portId -Ucs $ucsHandle
	    if(!$result) {
	        $fabricLanPc = Add-UcsUplinkPortChannel -FabricLanCloud $fabricLan -AdminSpeed "10gbps" -Name "Po$portId" -PortId $portId -OperSpeed "10gbps" -Ucs $ucsHandle
	        $fabricLanPc
	    } else {
	        "uplink port channel $portId already exists, skipping"
	        $fabricLanPc = $result
	    }
	    
	    for($i = 19; $i -le 20; $i++) {
	        $port = $i
	    
	        Add-UcsUplinkPortChannelMember -UplinkPortChannel $fabricLanPc -PortId $port -SlotId 1 -AdminState "enabled" -Ucs $ucsHandle
	    }
	    
	    ## Enable Port Channel
	    ## TODO: necessary?
	    Write-Host "enable port channel $portId"
	    
	    Set-UcsUplinkPortChannel -UplinkPortChannel $fabricLanPc -AdminState "enabled" -Ucs $ucsHandle -Force
	}

##############################################################################

# create WWNN Pool
write-host "create WWNN pool"
	$organization = $rootOrg

	$result = Get-UcsWwnPool -Name $WWNN_POOL_NAME -Org $organization -Ucs $ucsHandle
	if($result) {
	    $ourOrgName = $organization.Name
	    Write-Host "WWNN pool $WWNN_POOL_NAME already exists in org $ourOrgName, replacing"
	    
	    Remove-UcsWwnPool -WwnPool $result -Ucs $ucsHandle -Force
	}

	## create pool
	$wwnnPool = Add-UcsWwnPool -Org $organization -Name $WWNN_POOL_NAME -Purpose "node-wwn-assignment" -Ucs $ucsHandle
	#Set-Variable wwnnPool -Option ReadOnly
	$wwnnPool

	## assign range of addresses to pool
	Add-UcsWwnMemberBlock -WwnPool $wwnnPool -From $WWNN_POOL_START -To $WWNN_POOL_END -Ucs $ucsHandle

##############################################################################
# create WWPN Pools
### var_ucsm_wwpn_pool_A_start  var_ucsm_wwpn_pool_B_start 

write-host "create WWPN pools"
$organization = $rootOrg

	foreach($switchId in $switchIds_a) {
	    $variable = "WWPN_POOL_" + $switchId + "_NAME"
	    $wwpnPoolName = Get-Variable $variable -ValueOnly
	    
	    $result = Get-UcsWwnPool -Org $organization -Name $wwpnPoolName -Ucs $ucsHandle
	    if($result) {
	        $ourOrgName = $organization.Name
	        Write-Host "WWPN pool $wwpnPoolName already exists in org $ourOrgName, replacing"
	        
	        Remove-UcsWwnPool -WwnPool $result -Ucs $ucsHandle -Force
	    }
	    
	    ## create pool
	    $wwpnPool = Add-UcsWwnPool -Org $organization -Name $wwpnPoolName -Purpose "port-wwn-assignment" -Descr "Fabric $switchId WWPN Pool" -Ucs $ucsHandle
	    $wwpnPool
	    
	    $variable = "WWPN_POOL_" + $switchId + "_START"
	    $wwpnPoolStart = Get-Variable $variable -ValueOnly
	    
	    $variable = "WWPN_POOL_" + $switchId + "_END"
	    $wwpnPoolEnd = Get-Variable $variable -ValueOnly

	    Add-UcsWwnMemberBlock -WwnPool $wwpnPool -From $wwpnPoolStart -To $wwpnPoolEnd -Ucs $ucsHandle
	}

##############################################################################
# create VSAN

write-host "create vsans"
## take ids out of the excel sheet «var_global_vsan_A_id»” «var_global_fcoe_A_vlan_id»

$switchToFcPortChannelId_h = @{"A" = 1; "B" = 2}
foreach($switchId in $switchToFcPortChannelId_h.keys) {
    $portChannelId = $switchToFcPortChannelId_h.Get_Item($switchId)
	$portChannelName = "SPo" + $portChannelId 
	
    $variable = "VSAN_" + $switchId + "_NAME"
    $vSanName = Get-Variable $variable -ValueOnly

    ## get vsan id for that switch
    $variable = "VAR_GLOBAL_VSAN_" + $switchId + "_ID"
    $vSanId = Get-Variable $variable -ValueOnly
    
    ## get fcoe vlan id for that switch
    $variable = "VAR_GLOBAL_FCOE_" + $switchId + "_VLAN_ID"
    $fcoeVLanId = Get-Variable $variable -ValueOnly
	
	$fabricFcSan = New-Object Cisco.Ucs.FabricFcSan
    $fabricFcSan = Get-UcsFabricSanCloud -Id $switchId -Ucs $ucsHandle
    
    $vSan
    
    $result = Get-UcsVsan -FabricSanCloud $fabricFcSan -Name $vSanName -Ucs $ucsHandle
    if(!$result) {
        ## fcoe vlan id must be unique
        $fcoeResult = Get-UcsVsan -FcoeVlan $fcoeVLanId -Ucs $ucsHandle
        if($fcoeResult) {
            Write-Host "FcoE id $fcoeVLanId already taken, removing vSan $($result.name)"
            Remove-UcsVsan -Vsan $result -Ucs $ucsHandle -Force
        }
        
        ## vsan id must be unique
        $vsanRresult = Get-UcsVsan -Id $vSanId -Ucs $ucsHandle
        if($vsanResult){
            Write-Host "VSan id $vSanId already taken, removing vSan $($result.name)"
			Remove-UcsVsan -Vsan $result -Ucs $ucsHandle -Force
            
        }
    
        $vSan = Add-UcsVsan -FabricSanCloud $fabricFcSan -Name $vSanName -Id $vSanId -FcoeVlan $fcoeVLanId -Ucs $ucsHandle
    } else {
        Write-Host "vsan $vSanName already exists on fabric interconnect $switchId, skipping"
        $vSan = $result
    }


	write-host "create SAN port channels"
    $result = Get-UcsFcUplinkPortChannel -FabricSanCloud $fabricFcSan -PortId $portChannelId -Ucs $ucsHandle
    
	if($result) {
		Remove-UcsFcUplinkPortChannel -FcUplinkPortChannel $result -Force
	}
	
	$result = Get-UcsFcUplinkPortChannel -FabricSanCloud $fabricFcSan -PortId $portChannelId -Ucs $ucsHandle
	
	if(!$result) {		
        $cmd = "<configConfMos inHierarchical='true'>
                    <inConfigs>
                        <pair key='fabric/san/" + $switchId + "/pc-" + $portChannelId + "'>
                        <fabricFcSanPc
                            adminSpeed='auto'
                            adminState='disabled'
                            dn='fabric/san/" + $switchId + "/pc-" + $portChannelId + "'
                            name='SPo" + $portChannelId + "'
                            portId='" + $portChannelId + "'
                            status='created'>
    				 
                                <fabricFcSanPcEp
                                    adminSpeed='auto'
                                    adminState='enabled'
                                    name=''
                                    portId='1'
                                    rn='ep-slot-2-port-1'
                                    slotId='2'>
                                </fabricFcSanPcEp>
                                <fabricFcSanPcEp
                                    adminSpeed='auto'
                                    adminState='enabled'
                                    name=''
                                    portId='2'
                                    rn='ep-slot-2-port-2'
                                    slotId='2'>
                                </fabricFcSanPcEp>
                        </fabricFcSanPc>
                        </pair>
                    </inConfigs>
                </configConfMos>"
                
        Invoke-UcsXml -XmlQuery $cmd -Ucs $ucsHandle
		
		#$z = Add-UcsFcUplinkPortChannel -FabricSanCloud $fabricFcSan -PortId $portChannelId -Name $portChannelName -Ucs $ucsHandle	
    }
	else {
        Write-Host "port channel $portChannelId already exists on fabric interconnect $switchId, skipping"
    }
    
    ## get the port channel we just created
    $fcUplinkPortChannel = Get-UcsFcUplinkPortChannel -FabricSanCloud $fabricFcSan -PortId $portChannelId -Ucs $ucsHandle
    
    Write-Host "assign vsans to port channels" 
    
    $result = Get-UcsVsanMemberFcPortChannel -Vsan $vSan -PortId $portChannelId -SwitchId $switchId -Ucs $ucsHandle
    if(!$result) {
        Add-UcsVsanMemberFcPortChannel -Vsan $vSan -PortId $portChannelId -SwitchId $switchId -Ucs $ucsHandle
    } else {
        Write-Host "port channel $portChannelId already assigned to vsan $vSanName, skipping"
    }
    
    write-host "enable san port channels"
    
    Set-UcsFcUplinkPortChannel -FcUplinkPortChannel $fcUplinkPortChannel -AdminState "enabled" -Ucs $ucsHandle -Force
}

#### not sure what this is doing at the moment

#write-host "assign vsan to fc ports 1 and 2"
#
#foreach($switchId in $switchIds_a) {
#    $variable = "VAR_GLOBAL_VSAN_" + $switchId + "_id"
#    $vSanId = Get-Variable $variable -ValueOnly
#
#    $vSan = Get-UcsVsan -Id $vSanId -Ucs $ucsHandle
#
#    for($i = 1; $i -le 2; $i++) {
#        $port = $i
#        
#        $result = Get-UcsVsanMemberFcPort -Vsan $vSan -PortId $port -Ucs $ucsHandle
#        if(!$result) {
#            Add-UcsVsanMemberFcPort -Vsan $vSan -PortId $port -SlotId 2 -SwitchId $switchId -Ucs $ucsHandle
#        } else {
#            Write-Host "vsan $vsanId already assigned to port $port on switch $switchId, skipping"
#        }
#    }
#
#}

##############################################################################
# TODO: need var_global_vsan__A_id and .. as input!!
## TODO: tr 3939 suggests creation of template in root org, clean up in XML fragment or replace

write-host "create vhba templates"

$organization = $rootOrg

foreach($switchId in $switchIds_a) {
    $variable = "VHBA_" + $switchId + "_NAME"
    $vHbaName = Get-Variable $variable -ValueOnly
    
    $variable = "WWPN_POOL_" + $switchId + "_NAME"
    $wwpnPoolName = Get-Variable $variable -ValueOnly
    
    $variable = "VHBA_TEMPLATE_" + $switchId + "_NAME"
    $vHbaTemplateName = Get-Variable $variable -ValueOnly
    
    $variable = "VSAN_" + $switchId + "_NAME"
    $vSanName = Get-Variable $variable -ValueOnly

    $orgName = $organization.Name

    $result = Get-UcsVhbaTemplate -Org $organization -Name $vHbaTemplateName
    if($result) {
        Write-Host "vHBA template $vHbaTemplateName already exists in org $($organization.Name), replacing"
        Remove-UcsVhbaTemplate -VhbaTemplate $result -Ucs $ucsHandle -Force
    }
    	
	$z = Add-UcsVhbaTemplate -Org $organization -Name $vHbaTemplateName -IdentPoolName $wwpnPoolName -MaxDataFieldSize 2048 -SwitchId $switchId -TemplType "initial-template"
    
	$cmd = "<configConfMos inHierarchical='false'>
                <inConfigs>
                    <pair key='" + $z.Dn + "'>
                        <vnicSanConnTempl
                            dn='" + $z.Dn + "'
                            identPoolName='" + $z.IdentPoolName + "'
                            maxDataFieldSize='2048'
                            name='" + $z.Name + "'
                            statsPolicyName='default'
                            status='modified'
                            switchId='" + $z.SwitchId + "'
                            templType='initial-template'>  
                            <vnicFcIf
                                name='" + $vSanName + "'
                                rn='if-default'>
                            </vnicFcIf>
                        </vnicSanConnTempl>
                    </pair>
                </inConfigs>
            </configConfMos>"
            
    Invoke-UcsXml -XmlQuery $cmd -Ucs $ucsHandle
}

######################################################
 
# creation of local boot policy
 
write-host "create boot policies"

## create boot policys and add boot storage
## TODO: rename $policy to $hostname and hash accordingly
$policys_h = @{"A" = "a"; "B" = "b"}
foreach($policy in $policys_h.keys) {
    $variable = "VAR_NTAP_" + $policy + "_HOSTNAME"
    $ntapHostname = Get-Variable $variable -ValueOnly
    
    $bootPolicyName = $ntapHostname + "_2" + $policys_h.Get_Item($policy)
    
    $bootPolicy
    $result = Get-UcsBootPolicy -Org $ourOrg -Name $bootPolicyName -Ucs $ucsHandle
    if(!$result) {
        $bootPolicy = Add-UcsBootPolicy -Org $ourOrg -Name $bootPolicyName -Ucs $ucsHandle
    } else {
        Write-Host "boot policy $bootPolicyName already exists in org $($ourOrg.Name), skipping"
        $bootPolicy = $result
    }
    
    ## add cdrom boot media as first choice
    $result = Get-UcsLsbootVirtualMedia -BootPolicy $bootPolicy -Ucs $ucsHandle
    if(!$result) {
        Add-UcsLsbootVirtualMedia -BootPolicy $bootPolicy -Access "read-only" -Order 1 -Ucs $ucsHandle
    } else {
        Write-Host "boot virtual media for boot policy $ntapHostname in org $($ourOrg.Name) already exists, setting order to 1"
        Set-UcsLsbootVirtualMedia -LsbootVirtualMedia $result -Order 1 -Ucs $ucsHandle -Force
    }
    
    ## add storage boot as second choice
    $bootStorage
    $result = Get-UcsLsbootStorage -BootPolicy $bootPolicy  -Ucs $ucsHandle
    if(!$result) {
        $bootStorage = Add-UcsLsbootStorage -BootPolicy $bootPolicy -Order 2 -Ucs $ucsHandle
    } else {
        Write-Host "boot storage for boot policy $ntapHostname in org $($ourOrg.Name) already exists, setting order to 2"
        $bootStorage = $result
        Set-UcsLsbootStorage -LsbootStorage $bootStorage -Order 2 -Ucs $ucsHandle -Force
    }

    ## policy for ntap_A_hostname uses vHBA A as primary san boot, while policy for ntap_B_hostname uses vHBA B
    ## TODO: this is neither modular nor reusable, but I can't find a better way
    $sanImageMap_h
    if($policy -eq "A") {
        $sanImageMap_h = @{"A" = "primary"; "B" = "secondary"}
    } elseif($policy -eq "B") {
        $sanImageMap_h = @{"A" = "secondary"; "B" = "primary"}
    } else {
        throw "Creating boot san images failed"
    }
    
    ## create san boot images for both vHBAs
    foreach($sanImageId in $sanImageMap_h.keys) {
        $variable = "VHBA_" + $sanImageId + "_NAME"
        $vHbaName = Get-Variable $variable -ValueOnly
        
        $result = Get-UcsLsbootSanImage -LsbootStorage $bootStorage -Type $sanImageMap_h.Get_Item($sanImageId) -Ucs $ucsHandle
        if($result) {
            Write-Host "$sanImageMap_h.Get_Item($sanImageId) san boot image already exists for boot policy $bootPolicyName, replacing"
            Remove-UcsLsbootSanImage -LsbootSanImage $result -Ucs $ucsHandle -Force
        }
        
        $bootSanImage = Add-UcsLsbootSanImage -LsbootStorage $bootStorage -Type $sanImageMap_h.Get_Item($sanImageId) -VnicName $vHbaName
    
        ## vHBA A uses port on ntap_A_hostname as primary boot target, while vHBA b uses port on ntap_B_hostname
        $sanImagePathMap_h
        if($sanImageId -eq "A") {
            $sanImagePathMap_h = @{"A" = "primary"; "B" = "secondary"}
        } elseif($sanImageId -eq "B") {
            $sanImagePathMap_h = @{"A" = "secondary"; "B" = "primary"}
        } else {
            throw "Creating boot san image pathes failed"
        }
        
        ## loop through san boot targets
        foreach($sanImagePathId in $sanImagePathMap_h.keys) {
            ## vHBA A uses port 2a on filer A and B, vHBA B uses 2b
            $variable = "VAR_NTAP_" + $sanImagePathId + "_FC_2" + $sanImageId.ToLower()
            $wwpn = Get-Variable $variable -ValueOnly
        
            Add-UcsLsbootSanImagePath -LsbootSanImage $bootSanImage -Type $sanImagePathMap_h.Get_Item($sanImagePathId) -Wwn $wwpn
        }
    }
}
    
    
<#
## TODO: This is not about switch ids but about filer ids
foreach($switchId in $switchIds_a) {
    ## TODO: Make boot policy name a global variable, as it is reused when the service profiles are created,
    ## therefore TODO: make boot policy use global boot policy name    
    $variable = "VAR_NTAP_" + $switchId + "_HOSTNAME"
    $ntapHostname = Get-Variable $variable -ValueOnly


    ## add boot policy, named after the filer hostname
    $bootPolicy
    $result = Get-UcsBootPolicy -Org $ourOrg -Name $ntapHostname -Ucs $ucsHandle
    if(!$result) {
        $bootPolicy = Add-UcsBootPolicy -Org $ourOrg -Name $ntapHostname -Ucs $ucsHandle
    } else {
        Write-Host "boot policy $ntapHostname already exists in org $($ourOrg.Name), skipping"
        $bootPolicy = $result
    }

    ## add cdrom boot media as first choice
    $result = Get-UcsLsbootVirtualMedia -BootPolicy $bootPolicy -Ucs $ucsHandle
    if(!$result) {
        Add-UcsLsbootVirtualMedia -BootPolicy $bootPolicy -Access "read-only" -Order 1 -Ucs $ucsHandle
    } else {
        Write-Host "boot virtual media for boot policy $ntapHostname in org $($ourOrg.Name) already exists, setting order to 1"
        Set-UcsLsbootVirtualMedia -LsbootVirtualMedia $result -Order 1 -Ucs $ucsHandle -Force
    }

    ## add storage boot as second choice
    $bootStorage
    $result = Get-UcsLsbootStorage -BootPolicy $bootPolicy  -Ucs $ucsHandle
    if(!$result) {
        $bootStorage = Add-UcsLsbootStorage -BootPolicy $bootPolicy -Order 2 -Ucs $ucsHandle
    } else {
        Write-Host "boot storage for boot policy $ntapHostname in org $($ourOrg.Name) already exists, setting order to 2"
        $bootStorage = $result
        Set-UcsLsbootStorage -LsbootStorage $bootStorage -Order 2 -Ucs $ucsHandle -Force
    }
    
    ## add primary and secondary san boot images
    $bootSanImageTypes_h = @{"primary" = "a"; "secondary" = "b"}
    foreach($bootSanImageType in $bootSanImageTypes_h.keys) {        
        $result = Get-UcsLsbootSanImage -LsbootStorage $bootStorage -Type $bootSanImageType -Ucs $ucsHandle
        if($result) {
            Remove-UcsLsbootSanImage -LsbootSanImage $result -Ucs $ucsHandle -Force
        }
        
        $bootSanImage = Add-UcsLsbootSanImage -LsbootStorage $bootStorage -Type $bootSanImageType -VnicName "vHBA_$switchId" -Ucs $ucsHandle
        
        $variable = "VAR_NTAP_" + $switchId + "_FC_2" + $bootSanImageTypes_h.Get_Item($bootSanImageType)
        $hbaTarget = Get-Variable $variable -ValueOnly
        
        Add-UcsLsbootSanImagePath -LsbootSanImage $bootSanImage -Type $bootSanImageType -Wwn $hbaTarget -Ucs $ucsHandle
    }
}    
#>
######################################################

# creation of serverpool
# TODO: remove hardcoded servers in pool selection

write-host "create serverpool"

$orgName = $ourOrg.Name

$result = Get-UcsServerPool -Org $ourOrg -Name $SERVER_POOL_NAME
if (!$result) {

    $cmd = "<configConfMos inHierarchical='true'>
                <inConfigs>
                    <pair key='org-root/org-" + $orgName + "/compute-pool-" + $SERVER_POOL_NAME + "'>
                    <computePool
                        descr='description'
                        dn='org-root/-org" + $orgName + "/compute-pool-" + $SERVER_POOL_NAME + "'
                        name='" + $SERVER_POOL_NAME + "'
                        status='created'>
                        <computePooledSlot
                            chassisId='1'
                            rn='blade-1-1'
                            slotId='1'>
                        </computePooledSlot>
                        <computePooledSlot
                            chassisId='1'
                            rn='blade-1-3'
                            slotId='3'>
                        </computePooledSlot>
                    </computePool>
                </pair>
            </inConfigs>
        </configConfMos>"
        
    Invoke-UcsXml -XmlQuery $cmd -Ucs $ucsHandle
} else {
    Write-Host "serverpool $$SERVER_POOL_NAME already exists in org $($ourOrg.Name), skipping"
}

Get-UcsServerPool -Org $ourOrg -Name $SERVER_POOL_NAME

######################################################
# create UUID suffix Pool

write-host "create UUID pool"

$uuidPool
$result = Get-UcsUuidSuffixPool -Org $ourOrg -Name $UUID_POOL_NAME -Ucs $ucsHandle
if($result) {
    "UUID pool $UUID_POOL_NAME already exists in org $($ourOrg.Name), replacing"
    Remove-UcsUuidSuffixPool -UuidSuffixPool $result -Ucs $ucsHandle -Force
}

## create uuid pool
$uuidPool = Add-UcsUuidSuffixPool -Org $ourOrg -Name $UUID_POOL_NAME -Prefix "derived" -Ucs $ucsHandle
$uuidPool

## add range of uuid addresses
Add-UcsUuidSuffixBlock -UuidSuffixPool $uuidPool -From $UUID_POOL_START -To $UUID_POOL_END -Ucs $ucsHandle

######################################################

<# REDUNDANT, port channel already assigned to vsan

write-host "assign vsan to fc ports 1 and 2"

foreach($switchId in $switchIds_a) {
    $variable = "VAR_GLOBAL_VSAN_" + $switchId + "_id"
    $vSanId = Get-Variable $variable -ValueOnly

    $vSan = Get-UcsVsan -Id $vSanId -Ucs $ucsHandle

    for($i = 1; $i -le 2; $i++) {
        $port = $i
        
        $result = Get-UcsVsanMemberFcPort -Vsan $vSan -PortId $port -Ucs $ucsHandle
        if(!$result) {
            Add-UcsVsanMemberFcPort -Vsan $vSan -PortId $port -SlotId 2 -SwitchId $switchId -Ucs $ucsHandle
        } else {
            Write-Host "vsan $vsanId already assigned to port $port on switch $switchId, skipping"
        }
    }

}
#>


write-host "create service profile template"

## TODO: is this really about switches? not that important, though, since the values match
foreach($switchId in $switchIds_a) {
    $variable = "VAR_NTAP_" + $switchId + "_HOSTNAME"
    $ntapHostname = Get-Variable $variable -ValueOnly
    
    
    ## Service profile name is hostname + _2a/b
    ## TODO: rename to serviceProfileTemplateName
    $serviceProfileName = $ntapHostname + "_2" + $switchId.ToLower()
    
    ## boot policy name is the same as service profile name
    $bootPolicyName = $serviceProfileName
    
    $orgName = $ourOrg.Name

    ## TODO: check if exists
    $cmd = "<configConfMos inHierarchical='true'> 
                <inConfigs>
                    <pair key='org-root/org-" + $orgName + "/ls-" + $serviceProfileName + "' >    
                        <lsServer
                            agentPolicyName=''
                            biosProfileName=''
                            bootPolicyName='" + $bootPolicyName + "'
                            descr='' 
                            dn='org-root/org-" + $orgName + "/ls-" + $serviceProfileName + "' 
                            dynamicConPolicyName=''
                            extIPState='none'
                            hostFwPolicyName=''
                            identPoolName='" + $UUID_POOL_NAME + "'
                			localDiskPolicyName='default'
                			maintPolicyName='default'
                			mgmtAccessPolicyName=''
                			mgmtFwPolicyName=''
                			name='" + $serviceProfileName + "'
                			powerPolicyName='default'
                			scrubPolicyName=''
                			
                			srcTemplName=''
                			statsPolicyName='default'
                			status='created'
                			type='initial-template'
                			usrLbl=''
                			uuid='0'
                			vconProfileName=''>
                				<vnicEther
                					adaptorProfileName='VMWare'
                					addr='derived'
                					adminVcon='any'
                					identPoolName=''
                					mtu='1500'
                					name='" + $VNIC_A_NAME + "'
                					nwCtrlPolicyName=''
                					nwTemplName='" + $VNIC_TEMPLATE_A_NAME + "'
                					order='3'
                					pinToGroupName=''
                					qosPolicyName=''
                					rn='ether-" + $VNIC_A_NAME + "'
                					statsPolicyName='default'
                					status='created'
                					switchId='" + $switchId + "'>
                				</vnicEther>
                				<vnicEther
                					adaptorProfileName='VMWare'
                					addr='derived'
                					adminVcon='any'
                					identPoolName=''
                					mtu='1500'
                					name='" + $VNIC_B_NAME + "'
                					nwCtrlPolicyName=''
                					nwTemplName='" + $VNIC_TEMPLATE_B_NAME + "'
                					order='4'
                					pinToGroupName=''
                					qosPolicyName=''
                					rn='ether-" + $VNIC_B_NAME + "'
                					statsPolicyName='default'
                					status='created'
                					switchId='" + $switchId + "'>
                				</vnicEther>
                				<vnicFcNode
                					addr='pool-derived'
                					identPoolName='" + $WWNN_POOL_NAME + "'
                					rn='fc-node' >
                				</vnicFcNode>
                				<vnicFc
                					adaptorProfileName='VMWare'
                					addr='derived'
                					adminVcon='any'
                					identPoolName=''
                					maxDataFieldSize='2048'
                					name='" + $VHBA_A_NAME + "'
                					nwTemplName='" + $VHBA_TEMPLATE_A_NAME + "'
                					order='1'
                					persBind='disabled'
                					persBindClear='no'
                					pinToGroupName=''
                					qosPolicyName=''
                					rn='fc-" + $VHBA_A_NAME + "'
                					statsPolicyName='default'
                					status='created'
                					switchId='" + $switchId + "'>
                				</vnicFc>
                				<vnicFc
                					adaptorProfileName='VMWare'
                					addr='derived'
                					adminVcon='any'
                					identPoolName=''
                					maxDataFieldSize='2048'
                					name='" + $VHBA_B_NAME + "'
                					nwTemplName='" + $VHBA_TEMPLATE_B_NAME + "'
                					order='2'
                					persBind='disabled'
                					persBindClear='no'
                					pinToGroupName=''
                					qosPolicyName=''
                					rn='fc-" + $VHBA_B_NAME+ "'
                					statsPolicyName='default'
                					status='created'
                					switchId='" + $switchId + "'>
                				</vnicFc>
                				<lsRequirement
                					name='" + $SERVER_POOL_NAME + "'
                					qualifier=''
                					restrictMigration='no'
                					rn='pn-req' >
                				</lsRequirement>
                				<lsPower
                					rn='power'
                					state='down' >
                				</lsPower>
                			</lsServer>
                        </pair>
                    </inConfigs>
                </configConfMos>"

    Invoke-UcsXml -XmlQuery $cmd -Ucs $ucsHandle
}

## TODO same for B

write-host "create service profile from template"

$serviceprofiles = @{}

foreach($switchId in $switchIds_a) {
    $variable = "VAR_NTAP_" + $switchId + "_HOSTNAME"
    $ntapHostname = Get-Variable $variable -ValueOnly
    
    $serviceProfileTemplateName = $ntapHostname + "_2" + $switchId.ToLower()

    $serviceProfileName = "esxi4.1_host_" + $serviceProfileTemplateName
    $serviceprofiles[$switchId] = $serviceProfileName
	
    Add-UcsServiceProfile -Org $ourOrg -Name $serviceProfileName -SrcTemplName $serviceProfileTemplateName -ucs $ucsHandle
}

## TODO
## attach blade to profile

write-host "get wwpn for zoning"
#query-wwpn $outCookie $config $config.Get_Item("<<var_ucsm_infra_org_name>>") 

$z = Get-UcsServiceProfile | Where-Object {$_.Type -eq "instance"  }

foreach($switchId in $switchIds_a) {
	write-Host $switchid
	
	$profile = $z | Where-Object {$_.Name -eq $serviceprofiles[$switchId]}
	
	if($profile) {
		$dn = $profile.Dn

		$cmd =  "<configResolveDn dn='" + $dn + "' inHierarchical='true'> </configResolveDn>"

		$res = Invoke-UcsXml -XmlQuery $cmd -Ucs $ucsHandle
	    $x = [xml] $res
	    
	    $h =@{}
	    $x.configResolveDn.outConfig.lsServer.vnicFC | %{$h.Add($_.name,$_.addr)}
	    
		$h.Get_Item("vHBA_A")
		$h.Get_Item("vHBA_B")  
		
	    $config["<<var_ucsm_sp"+$switchId+"_vHBA_A_wwpn>>"] = $h.Get_Item("vHBA_A")
	    $config["<<var_ucsm_sp"+$switchId+"_vHBA_B_wwpn>>"] = $h.Get_Item("vHBA_B")    
	}
}

Dump-Csv $csv_file $config 

$Elapsed.Elapsed