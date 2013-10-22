#
# This Powershell script is used to setup a clustered NetApp storage system.
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
	[string]$csv_file,
	
	[string] $action,
	[string] $undoFile,
	[Array] $functions_a
)

# Has to happen before the undo-logger is initialized
if($undoFile) {
	$functions_a = Get-Content $undoFile
	[Array]::Reverse($functions_a)	
}

#Import NetApp Modulesp
Import-Module DataOntap
#Import variables

Import-Module "..\helpers\FPodConfig.psm1"
#Import-Module "C:\Data_Steffend\UCS\faspart\FlexPod-PowerShellScripts\helpers\FPodConfig.psm1"

$Elapsed = [System.Diagnostics.Stopwatch]::StartNew()

$config = @{}

#$csv_file = "config\fpod.csv"
$config = Read-FPodConfig($csv_file)

### this code reads the file of the running script and checks if all required parameters in $config exist
$scriptfile = $myInvocation.mycommand.path

Test-VarPresence $scriptfile $config

$config.GetEnumerator() | sort name

#############################
# Global constants          #
#############################

$AGGR_ATTEMPT_DELAY = 10
Set-Variable AGGR_ATTEMPT_DELAY 

# Assume log config file is in the same directory as the script
$LOG_CONFIG_PATH = (Split-Path $MyInvocation.MyCommand.Definition) + "\log4net.xml"

$VAR_GLOBAL_NTP_SERVER_IP = $config.Get_Item("<<var_global_ntp_server_ip>>")
#Set-Variable VAR_GLOBAL_NTP_SERVER_IP 

$VAR_NTAP_A_MGMT_INT_IP = $config.Get_Item("<<var_ntap_A_mgmt_int_IP>>")
#Set-Variable VAR_NTAP_A_MGMT_INT_IP 

$VAR_NTAP_B_MGMT_INT_IP = $config.Get_Item("<<var_ntap_B_mgmt_int_IP>>")
#Set-Variable VAR_NTAP_B_MGMT_INT_IP

$VAR_GLOBAL_DEFAULT_PASSWD = $config.Get_Item("<<var_global_default_passwd>>")
#Set-Variable VAR_GLOBAL_DEFAULT_PASSWD

$AGGR_NAME = "aggr1"
#Set-Variable AGGR_NAME 

$VIRTUAL_ETH_INTERFACE_NAME = "vif0"
#Set-Variable VIRTUAL_ETH_INTERFACE_NAME 

$LICENSE_TYPES_H = @{   "a_sis"             = $config.Get_Item("<<var_ntap_a_sis_lic>>");
                        "multistore"        = $config.Get_Item("<<var_ntap_multistore_lic>>");
                        "nearstore_option"  = $config.Get_Item("<<var_ntap_nearstore_option_lic>>");
                        "flex_clone"        = $config.Get_Item("<<var_ntap_flexclone_lic>>");
                        "fcp"               = $config.Get_Item("<<var_ntap_fcp_lic>>");
                        "nfs"               = $config.Get_Item("<<var_ntap_nfs_lic>>");
                        "cluster"           = $config.Get_Item("<<var_ntap_cluster_lic>>");
                        # TODO: "flash_cache" == "flex_scale"?
                        #"flash_cache"       = $config.Get_Item("<<var_ntap_flash_cache_lic>>");
                    }
#Set-Variable LICENSE_TYPES_A 
                    
$CONTROLLER_A_VOLUMES_H = @{        "infra_root"        =  @{ "size"                 = $config.Get_Item("<<var_ntap_infra_root_vol_size>>");
                                                              "enable_sis"           = 0;
                                                              "enable_snap_schedule" = 1;};
                                    "infra_datastore_1" = @{  "size"                 = $config.Get_Item("<<var_ntap_infra_datastore_1_vol_size>>");
                                                              "enable_sis"           = 1;
                                                              "enable_snap_schedule" = 1;};
                                    "esxi_boot_A"       = @{  "size"                 = $config.Get_Item("<<var_ntap_esxi_boot_vol_size>>");
                                                              "enable_sis"           = 1;
                                                              "enable_snap_schedule" = 1;};
                                 }
#Set-Variable CONTROLLER_A_VOLUMES_H 

$CONTROLLER_B_VOLUMES_H = @{        "infra_root"        = @{  "size"                 = $config.Get_Item("<<var_ntap_infra_root_vol_size>>");
                                                              "enable_sis"           = 0;
                                                              "enable_snap_schedule" = 1;};
                                    "infra_swap"        = @{  "size"                 = $config.Get_Item("<<var_ntap_infra_swap_vol_size>>");
                                                              "enable_sis"           = 0;
                                                              "enable_snap_schedule" = 0;};
                                    "esxi_boot_B"       = @{  "size"                 = $config.Get_Item("<<var_ntap_esxi_boot_vol_size>>");
                                                              "enable_sis"           = 1;
                                                              "enable_snap_schedule" = 1;};
							}
#Set-Variable CONTROLLER_B_VOLUMES_H 

$CONTROLLER_A_VFILER_H = 	@{	"name"			= "infrastructure_vfiler_1"
								"address"		= $config.Get_Item("<<var_ntapA_infra_vfiler_IP>>");
								"storage"		= "/vol/infra_root";
							}
#Set-Variable CONTROLLER_A_VFILER_H 
													
$CONTROLLER_B_VFILER_H =	@{	"name"			= "infrastructure_vfiler_2"
								"address"		= $config.Get_Item("<<var_ntapB_infra_vfiler_IP>>");
								"storage"		= "/vol/infra_root";
							}
#Set-Variable CONTROLLER_B_VFILER_H 

#########################################
# Initialize logging					#
#########################################

#$script:logger = Prepare-Logger $LOG_CONFIG_PATH
#$script:undoLogger = Prepare-UndoLogger $LOG_CONFIG_PATH

#########################################
# Helper functions						#
#########################################

### base code for function taken from http://www.out-web.net/?p=334"
function ComputeMD5Hash([string] $inputString) {
	$cryptoServiceProvider = [System.Security.Cryptography.MD5CryptoServiceProvider]
	$algorithm = New-Object $cryptoServiceProvider
	
	$resultByte_a = $algorithm.ComputeHash([Char[]] $inputString)
	
	$resultString = ""
	
	# Convert byte array to hex number
	foreach($byte in $resultByte_a) {
		$resultString += “{0:X2}” -f $byte
	}
	
	return $resultString
}


#Step 1 - assign controller disk ownership needs to be done manually from the console

#Step 2 - downgrade ONTAP needs to be done from the console

#Step 3 - Power up controllers and complete initial setup.  This step can be done from the script if we 
#		  can determine the IP address the controller receives from a DHCP server.  To setup or initialize
#		  the controller from the script use the Initialize-NaController command like below.  There are a couple of 
#		  variables that still need to be defined, $config.Get_Item("<<var_global_dns_domain>>") and $config.Get_Item("<<var_global_dns_servers>>")
#Initialize-NaController -DhcpAddress $DHCPAddress_A -Hostname $config.Get_Item("<<var_ntap_A_hostname>>") -Gateway $config.Get_Item("<<var_ntap_A_mgmt_int_gw>>") -PrimaryInterface $config.Get_Item("<<var_ntap_netboot_int>>") -PrimaryInterfaceAddress $config.Get_Item("<<var_ntap_A_netboot_int_IP>>") -Password $config.Get_Item("<<var_global_default_passwd>>") -Timezone $config.Get_Item("<<var_global_default_timezone>>") -Emailhost $config.Get_Item("<<var_ntap_mailhost_name>>") -EmailAddress $config.Get_Item("<<var_ntap_admin_email_address>>") -Location $config.Get_Item("<<var_ntap_location>>") -Dnsdomain $config.Get_Item("<<var_global_dns_domain>>") -DnsServers $config.Get_Item("<<var_global_dns_servers>>")

#Step 4 - installing DataONTAP to the onboard flash storage
#controller A: software install $config.Get_Item("<<var_ntap_data_ontap_url>>")
#controller B: software install $config.Get_Item("<<var_ntap_data_ontap_url>>")

#Step 5 - install required licenses
function Licenses([string] $cmd, [NetApp.Ontapi.Filer.NaController] $controller) {
	$logger.Info(" ")
	$logger.Info("Entered function Licenses on $controller")

    $licenseNames_a = @($LICENSE_TYPES_H.Keys)
    $licenseValues_a = @($LICENSE_TYPES_H.Values)

	switch($cmd) {
	"A"	{		
			$logger.Info("Applying licenses to $controller")
            
            # Avoid unnecessary reboot
            $licenses_a = Get-NaLicense -Names $licenseNames_a -Controller $controller
            
            [bool] $allLicensed = 1
            foreach ($license in $licenses_a) {
                if(!$license.Licensed) {
                    $allLicensed = 0
                    # Break to switch statement
                    break
                }
            }
            
            if ($allLicensed) {
                $logger.Info("All required licenses already installed, skipping reboot")
                # Break out of switch statement
                break
            }
            
            $licenses = Add-NaLicense -Codes $licenseValues_a -Controller $controller -ErrorAction SilentlyContinue
			           
#            foreach ($license in $licenses_a)
#			{
#				# TODO: Would require additional call to Get-NaLicense to work, worth it?
#				if ($license.licensed){$logger.Info("$controller $license is licensed")}
#				else {$logger.Info("$controller $license is not licensed")}
#			}
        
			Invoke-NaSystemApi -Controller $controller "<system-cli><args><arg>reboot</arg><arg>-t</arg><arg>0</arg></args></system-cli>" -ErrorAction SilentlyContinue
			
			isUp $controller
						
			break
		}
	#Check licenses
	"V"	{
			$logger.Info("Verifying licenses to $controller")
			
			$licenses = Get-NaLicense -Controller $controller -Names $licenseNames_a -Verbose
			foreach ($license in $licenses)
			{
				if ($license.licensed){$logger.Info("$controller $license is licensed")}
				else {$logger.Info("$controller $license is not licensed")}
			}
			break
		}
	"R"	{
			$logger.Info("Removing licenses on $controller")
            
            # Avoid unnecessary reboot
            $licenses_a = Get-NaLicense -Names $licenseNames_a -Controller $controller
            
            [bool] $noneLicensed = 1
            foreach ($license in $licenses_a) {
                if($license.Licensed) {
                    $noneLicensed = 0
                    # Break to switch statement
                    break
                }
            }
            
            if ($noneLicensed) {
                $logger.Info("No license to be removed installed, skipping reboot")
                # Break out of switch statement
                break
            }
            
			$licenses = Remove-NaLicense -Controller $controller -Names $licenseNames_a -ErrorAction SilentlyContinue
            
#			foreach ($license in $licenses_a)
#			{
#				if ($license.licensed){$logger.Info("$controller $license is licensed")}
#				else {$logger.Info("$controller $license is not licensed")}
#			}
            
			$logger.Info("Storage controller rebooting for cluster enablement")
			
			Invoke-NaSystemApi -Controller $controller "<system-cli><args><arg>reboot</arg><arg>-t</arg><arg>0</arg></args></system-cli>" -ErrorAction SilentlyContinue
			
			break
		}
	"S"	{
            $logger.Info(" ")
            $logger.Info("Saving licenses")
            $logger.Info(" ")
            break
		}
	}
	$logger.Info("Leaving function Licenses on $controller")
}

#Step 6 - Enable high availablity
function HighAvailability([string] $cmd, [NetApp.Ontapi.Filer.NaController] $controller) {
	$logger.Info(" ")
	$logger.Info("Entered function HighAvailability on $controller")

	switch ($cmd) {
	"A" {
            $logger.Info("Enabling cluster on $controller")
			
            Enable-NaCluster -Controller $controller
			
            #Check high availability			
            Get-NaCluster -Controller $controller
			
            break
		}
	"R" {
            $logger.Info("Disabling cluster on $controller")
			
            $cluster = Get-NaCluster -Controller $controller -ErrorAction SilentlyContinue
            if ($cluster.IsEnabled) 
			{
                $cluster = Disable-NaCluster -Controller $controller
			}
            else {$logger.Warn("cluster already disabled on $controller")}
			
			break
		}
	}
	$logger.Info("Leaving function Licenses on $controller")
}

function Check_equal_WWNN([NetApp.Ontapi.Filer.NaController] $controllera, [NetApp.Ontapi.Filer.NaController] $controllerb) {
	$logger.Info("Entered function Check_equal_WWNN for controllers $controllera and $controllerb")

    ## Name des interfaces einbauen
	$WWNN_A = Get-NaFcpNodeName -Controller $controllera
    $WWNN_B = Get-NaFcpNodeName -Controller $controllerb

    if($WWNN_A -ne $WWNN_B) {
        $logger.Info("WWNNs differ, configuring WWNN of controller A to B!")
        
        Set-NaFcpNodeName -NodeName $WWNN_A -Controller $controllerb
        
		$logger.Info("Rebooting - Waitng for coming back")
        Invoke-NaSystemApi -Controller $controllerb "<system-cli><args><arg>reboot</arg><arg>-t</arg><arg>0</arg></args></system-cli>" -ErrorAction SilentlyContinue
    }
	
	isUp $controllerb
	$logger.Info("Leaving function Check_equal_WWNN")
}

#Step 7 - start FCP and assign ports
function FCP([string] $cmd, [NetApp.Ontapi.Filer.NaController] $controller) {
	$logger.Info("Entered function FCP on $controller")

	switch ($cmd) {
	"A" {
			$logger.Info("Enabling FCP and assigning adapters on controller $controller")
            $logger.Info("Checking if FCP is already enabled on controller $controller")
            if (!(Test-NaFcp -Controller $controller)) {
                $logger.Info("enabling FCP on controller $controller")
                Enable-NaFcp -Controller $controller
                Start-Sleep 10
			}
            else{$logger.Info("FCP already enabled on controller $controller")}
            $logger.Info("setting adapter types to Target")
			
            Set-NaFcAdapterType -Controller $controller -Adapter 0c -Type target
            Set-NaFcAdapterType -Controller $controller -Adapter 0d -Type target			
			
			break
		}
	"R" {
            $logger.Info("Disabling FCP on controller $controller")
            $logger.Info("Checking if FCP is already disabled on controller $controller")
			
            if (Test-NaFcp -Controller $controller) {
                $logger.Info("Disabling FCP on controller $controller")
                Disable-NaFcp -Controller $controller
			}
            else{$logger.Info("FCP already disabled on controller $controller")}
			
			break
		}
	}	
	
	$logger.Info("Leaving function FCP on $controller")
}

#Step 8 - Setting up storage system ntp time synchronization option values
function NTP([string] $cmd, [NetApp.Ontapi.Filer.NaController] $controller){
	$logger.Info(" ")
	$logger.Info("Entered function NTP on $controller")
			
    switch ($cmd) {
    #Verify NTP Values
    "V"	{
            $logger.Info("Verifying NTP settings on $controller")
			Get-NaOption -Controller $controller -OptionName timed.proto 
			Get-NaOption -Controller $controller -OptionName timed.servers 
			Get-NaOption -Controller $controller -OptionName timed.enable 
			break
		}
		#Apply NTP Values
	"A"	{
			$logger.Info("Apply NTP settings on $controller")
			Set-NaOption -Controller $controller -OptionName timed.proto -OptionValue ntp 
			Set-NaOption -Controller $controller -OptionName timed.servers -OptionValue $VAR_GLOBAL_NTP_SERVER_IP 
			Set-NaOption -Controller $controller -OptionName timed.enable -OptionValue on
			break
		}		
		#Rollback NTP Values to factory default (nothing)
	"R"	{
			$logger.Info("Rollback NTP settings on $controller")
			Set-NaOption -Controller $controller -OptionName timed.proto -OptionValue "" 
			Set-NaOption -Controller $controller -OptionName timed.servers -OptionValue "" 
			Set-NaOption -Controller $controller -OptionName timed.enable -OptionValue off
			break
		}		
	}	
	$logger.Info("Leaving function NTP on $controller")
}

#Step 9 - Create aggregates
function Aggregate([string] $cmd, [NetApp.Ontapi.Filer.NaController] $controller, [string] $aggrName, [int] $numDisk){
	$logger.Info(" ")
	$logger.Info("Entered function Aggregate on $controller")

    switch ($cmd) {
    #List aggregates 
	"V"	{
			$logger.Info("List aggregates on $controller")
			Get-NaAggr -Controller $controller

			break
		}
		#Add aggregate aggr1
	"A"	{
			$logger.Info("Add $aggrName on $controller")
			
            if($config.ContainsKey("<<var_paulwilsons_rg_size>>")) {
                $rg_size = $config.Get_Item("<<var_paulwilsons_rg_size>>")
                New-NaAggr -Controller $controller -Name $aggrName -Use64Bit -DiskCount $numdisk -RaidSize $rg_size -ErrorAction SilentlyContinue
                
				break
            }
            
            New-NaAggr -Controller $controller -Name $aggrName -Use64Bit -DiskCount $numdisk -ErrorAction SilentlyContinue
			
			break
		}
    "R" {
			$logger.Info("Remove $aggrName on $controller")
            
			Set-NaAggr -Controller $controller -Name $aggrName -Offline
			Remove-NaAggr -Controller $controller -Name $aggrName -Confirm:$false
			
            break
        }	
	}		
	$logger.Info("Leaving function Aggregate on $controller")
}

#Step 10 - enable 802.1q vlan trunking and adding the NFS vlan
function VLAN([string] $cmd, [NetApp.Ontapi.Filer.NaController] $controller) {
	switch ($cmd) {
	"A" {
            $logger.Info("Start step 10 for controller $controller")
            $logger.Info("Adding VLAN $VIRTUAL_ETH_INTERFACE_NAME with ID " + $config.Get_Item("<<var_global_nfs_vlan_id>>") + "on controller $controller")
            Add-NaNetVlan -Controller $controller -Interface VIRTUAL_ETH_INTERFACE_NAME -Vlans $config.Get_Item("<<var_global_nfs_vlan_id>>")  
		
            $logger.Info("setting interface " + $config.Get_Item("<<var_global_nfs_vlan_id>>") + " MTUSize to 9000 and Partner to "+ $config.Get_Item("<<var_global_nfs_vlan_id>>"))
            Set-NaNetInterface -Controller $controller -InterfaceName VIRTUAL_ETH_INTERFACE_NAME -MtuSize 9000 -Partner $config.Get_Item("<<var_global_nfs_vlan_id>>")
            Get-NaNetInterface -Controller $controller
		}
	"R" {
            $logger.Info("Start step 10 for controller $controller")
            $logger.Info("Removing VLAN $VIRTUAL_ETH_INTERFACE_NAME on controller $controller")
            Remove-NaNetVlan -Controller $controller -Interface $VIRTUAL_ETH_INTERFACE_NAME
		}
	}
	$logger.Info("Step 10 completed on controller $controller")
}

#Step 10 - enable 802.1q vlan trunking and adding the NFS vlan
function VLAN_viaSSH([string] $cmd, [NetApp.Ontapi.Filer.NaController] $controller, [string] $ifName, [int] $vLanId) {
	$logger.Info(" ")
	$logger.Info("Entered function VLAN_viaSSH on $controller")

	# TODO: is "ifconfig e0M partner e0M" supposed to happen here
	$ifconfigSshCmd_a = @("ifconfig e0M partner e0M",
				"vlan create $ifName $vLanId",
				"ifconfig $ifName-$vLanId mtusize 9000",
				"ifconfig $ifName-$vLanId partner $ifName-$vLanId")

	$ifconfigHash = ComputeMD5Hash $ifconfigSshCmd_a
	$fingerprintStart = "# vlan begin $ifconfigHash"
	$fingerprintEnd = "# vlan end $ifconfigHash"

	switch ($cmd) {
	"A" {			
			$logger.Info("Adding VLAN $ifName-$vLanId with ID $vLanId on controller $controller")
			$logger.Info("setting interface $ifName-$vLanId MTUSize to 9000 and Partner to $ifName-$vLanId")

			# Collect start fingerprint
			$rcFileSshCmd_a = @("wrfile -a /etc/rc `"$fingerprintStart`"")

			# Execute one command at a time and prepare them to be written to /etc/rc
			foreach ($ifconfigSshCmd in $ifconfigSshCmd_a) {
				$logger.Debug("Invoking ssh command $ifconfigSshCmd")
				Invoke-NaSsh -Controller $controller -Command $ifconfigSshCmd
				
				# Collect every command
				$rcFileSshCmd_a += "wrfile -a /etc/rc `"$ifconfigSshCmd`""
			}
			
			# Collect end fingerprint
			$rcFileSshCmd_a += "wrfile -a /etc/rc `"$fingerprintEnd`""
			$rcFileSshCmd_a += "rdfile /etc/rc"
			
			# Check if vLan already exists
			$oldFile = Invoke-NaSsh -Controller $controller -Command "rdfile /etc/rc"
			if(!($oldFile -match "$fingerprintStart\b")) {						
				
				# Write every line to /etc/rc
				foreach ($rcFileSshCmd in $rcFileSshCmd_a) {
					$logger.Debug("Invoking ssh command $rcFileSshCmd")
					Invoke-NaSsh -Controller $controller -Command $rcFileSshCmd
				}
			}
			
			break
		}
	"R" {
			$logger.Info("Removing VLAN $ifName on controller $controller")
		
			# Delete vlan
			Invoke-NaSsh -Controller $controller -Command "ifconfig e0M -partner"
			Invoke-NaSsh -Controller $controller -Command "vlan delete $ifName $vLanId"
		
			# Reset /etc/rc on controller					
			# Get /etc/rc
			$ssh_cmd = "rdfile /etc/rc"
			$oldFile = Invoke-NaSsh -Controller $controller -Command $ssh_cmd

			# Remove vLan config
			$newFile = $oldFile -replace "$fingerprintStart(.|\n)*?$fingerprintEnd"
			
			if(!($newFile -eq $oldFile)) {
				$logger.Debug("Removing vlan $ifName-$vLanId from /etc/rc on $controller")
			
				# Split lines into an array and remove empty lines
				$newFile -split "`n" | Where-Object { $_ -ne "" } | Set-Variable newFileLines_a
				
				# Move the file so /etc/rc will be empty
				Invoke-NaSsh -Controller $controller -Command "mv /etc/rc /etc/rc.backup"
				
				# Append lines
				foreach ($line in $newFileLines_a) {
					$logger.Debug("Writing line $line to /etc/rc")
					Invoke-NaSsh -Controller $controller -Command "wrfile -a /etc/rc `"$line`""
				}
			} else {
				$logger.Debug("No content replaced in /etc/rc on controller $controller")
			}
			
			break
		}
	}
	$logger.Info("Leaving function VLAN_viaSSH on $controller")
}


#Step 11 - hardening storage system logins and security (needs to be moved to the end for SSH and SSL)
function hardening([NetApp.Ontapi.Filer.NaController] $controller) 
{
    # TODO: Password is $VAR_GLOBAL_DEFAULT_PASSWD from the start
	$logger.Info("Start step 11 for controller $controller")
	Set-NaUserPassword -Controller $controller -User "root" -OldPassword "Netapp1" -NewPassword $VAR_GLOBAL_DEFAULT_PASSWD
	$logger.Info("Step 11 completed on controller")
}

#Step 12 - Create SNMP request role and assign SNMP login priviledges
function SNMP([string] $cmd, [NetApp.Ontapi.Filer.NaController] $controller) {
	$logger.Info(" ")
	$logger.Info("Entered function SNMP on $controller")

    switch ($cmd) {
    "A" {
			$roleName = $config.Get_Item("<<var_ntap_snmp_request_role>>")
			$logger.Info("Adding role $roleName to $controller")
            if (!(Get-NaRole -Controller $controller -Role $config.Get_Item("<<var_ntap_snmp_request_role>>") -ErrorAction SilentlyContinue)) {                
                New-NaRole -Controller $controller -Role $config.Get_Item("<<var_ntap_snmp_request_role>>") -Capabilities "login-snmp"
            }
            else {
				$logger.Info("role " + $config.Get_Item("<<var_ntap_snmp_request_role>>") + "exists")
				# Make sure it has the right capability
				Set-NaRole -Controller $controller -Role $config.Get_Item("<<var_ntap_snmp_request_role>>") -AddCapabilities "login-snmp"
			}

            #Step 13 - create SNMP management group and assign SNMP request role to it
			$groupName = $config.Get_Item("<<var_ntap_snmp_managers>>")
			$logger.Info("Adding group $groupName to $controller")
            if (!(Get-NaGroup -Controller $controller -Group $config.Get_Item("<<var_ntap_snmp_managers>>") -ErrorAction SilentlyContinue))
            {                
                New-NaGroup -Controller $controller -Group $config.Get_Item("<<var_ntap_snmp_managers>>") -Roles $config.Get_Item("<<var_ntap_snmp_request_role>>")
            }
            else {
				$logger.Info("group " + $config.Get_Item("<<var_ntap_snmp_managers>>") + " exists")
				# Make sure the right role is assigned
				Set-NaGroup -Controller $controller -Group $config.Get_Item("<<var_ntap_snmp_managers>>") -AddRoles $config.Get_Item("<<var_ntap_snmp_request_role>>")
			}

            #Step 14 - create SNMP user and assign to the SNMP mgmt group
			$userName = $config.Get_Item("<<var_ntap_snmp_user>>")
			$logger.Info("Adding user $userName to $controller")
			
			# Remove existing user to be shure we have the right password set
            if (Get-NaUser -Controller $controller -User $config.Get_Item("<<var_ntap_snmp_user>>") -ErrorAction SilentlyContinue)
            {
				$logger.Info("User " +  $config.Get_Item("<<var_ntap_snmp_user>>") + " exists, replacing.")
                Remove-NaUser -Controller $controller -User $config.Get_Item("<<var_ntap_snmp_user>>") -Confirm:$false
            }
	
			New-NaUser -Controller $controller -User $config.Get_Item("<<var_ntap_snmp_user>>") -Groups $config.Get_Item("<<var_ntap_snmp_managers>>") -Password $config.Get_Item("<<var_ntap_snmp_password>>")

            #Step 15 - Enable SNMP on the storage controllers
            $logger.Info("Enabling snmp on $controller")
			# TODO: Skip?
            Set-NaOption -Controller $controller -OptionName "snmp.enable" -OptionValue "on"

            #Step 16 - Delete SNMP v1 communities from the storage controllers
            $logger.Info("Removing existing SNMP communities from $controller")
            Remove-NaSnmpCommunity -Controller $controller -All

            #Step 17 - Set SNMP contact information for each of the storage controller
            $logger.Info("Setting SNMP contact information on $controller")
            Set-NaSnmpContact -Controller $controller -Contact $config.Get_Item("<<var_ntap_admin_email_address>>")

            #Step 18 - Set SNMP location information for each storage controller
            $logger.Info("Setting SNMP location information on $controller")
            Set-NaSnmpLocation -Controller $controller -Location $config.Get_Item("<<var_ntap_snmp_site_name>>") -ErrorAction SilentlyContinue

            #Step 19 - Establish SNMP trap destination
            $logger.Info("Establishing SNMP trap host on $controller")
            # TODO: var_ntap_dfm_hostname or var_ntap_snmp_trapdest or var_ntap_traphost
            Add-NaSnmpTrapHost -Controller $controller -Hosts $config.Get_Item("<<var_ntap_dfm_hostname>>") -ErrorAction SilentlyContinue
            #Add-NaSnmpTrapHost -Controller $controller -Hosts $config.Get_Item("<<var_ntap_dfm_hostname>>").$config.Get_Item("<<var_global_domain_name>>")

            #Step 20 - Reinitialize SNMP on the storage controllers
            $logger.Info("Reinitializing SNMP on $controller")
            Enable-NaSnmp -Controller $controller
            
            break
        }
    "R" {
            #Step 15/20 - Disable SNMP on the storage controllers
            $logger.Info("Removing SNMP trap host from $controller")
            Set-NaOption -Controller $controller -OptionName "snmp.enable" -OptionValue "off"
    
            #Step 19 - Remove SNMP trap destination
            $logger.Info("Start step 19 for controller $controller")
            $snmp = Get-NaSnmp -Controller $controller                        
            Remove-NaSnmpTrapHost -Controller $controller -Hosts $snmp.Traphosts
            $logger.Info("Step 19 completed for controller $controller" )
            
            #Step 18 - Unset SNMP location information for each storage controller
            $logger.Info("SUnset SNMP location information for $controller")
            Set-NaSnmpLocation -Controller $controller -Location ""
            
            #Step 17 - Unset SNMP contact information for each of the storage controller
            $logger.Info("Start step 17 for controller $controller")
            Set-NaSnmpContact -Controller $controller -Contact ""
            $logger.Info("Step 17 completed for controller $controller")
            
            #Step 16 - Restore default SNMP v1 communities on the storage controllers
            $logger.Info("Restore default SNMP communities on $controller")
            Add-NaSnmpCommunity -Controller $controller -Community "public"
    
            $logger.Info("Removing SNMP user from $controller")
            Remove-NaUser -Controller $controller -User $config.Get_Item("<<var_ntap_snmp_user>>") -Confirm:$false
    
            $logger.Info("Removing SNMP group from $controller")
            Remove-NaGroup -Controller $controller -Group $config.Get_Item("<<var_ntap_snmp_managers>>") -Confirm:$false
    
            $logger.Info("Removing SNMP role from $controller")
            Remove-NaRole -Controller $controller -Role $config.Get_Item("<<var_ntap_snmp_request_role>>") -Confirm:$false
            
            break
        }
    }
}

#Step 21 - Enable FlashCache
# TODO
# FlexCache is symetrical on the cluster, so we will enable both at the same time. TODO: Necessary?
#function FlashCache([string] $cmd, [NetApp.Ontapi.Filer.NaController] $controller){
#    # TODO: don't use variables from "main" section
#    switch ($cmd) {
#    #List aggregates 
#    "V"	{
#            $logger.Info(" ")
#			$logger.Info("Start step 21 for controller $controller")
#			$logger.Info("Verify FlashCache Status")
#			Get-NaOption -Controller $controllera -OptionName "flexscale.enable"
#			Get-NaOption -Controller $controllerb -OptionName "flexscale.enable"
#			break
#        }
#		#Enable FlashCache
#    "A"	{
#			$logger.Info(" ")
#			$logger.Info("Start step 21 for controller $controller")
#			$logger.Info("Enable FlashCache on controllers")
#			Set-NaOption -Controller $controllera -OptionName "flexscale.enable" -OptionValue "on" -ErrorAction SilentlyContinue
#			Set-NaOption -Controller $controllerb -OptionName "flexscale.enable" -OptionValue "on" -ErrorAction SilentlyContinue
#			break
#		}
#    "R" {
#            $logger.Info(" ")
#			$logger.Info("Start step 21 for controller $controller")
#			$logger.Info("Disable FlashCache on controllers")
#            
#            Set-NaOption -Controller $controllera -OptionName "flexscale.enable" -OptionValue "off" -ErrorAction SilentlyContinue
#			Set-NaOption -Controller $controllerb -OptionName "flexscale.enable" -OptionValue "off" -ErrorAction SilentlyContinue
#            
#            break
#        }
#	}
#	$logger.Info("Step 21 completed")
#}

#Step 21 - Enable FlashCache
function FlashCache([string] $cmd, [NetApp.Ontapi.Filer.NaController] $controller){
	$logger.Info(" ")
	$logger.Info("Entered function FlashCache on $controller")
	
	switch ($cmd) {
	"V"	{
			$logger.Info("Verify FlashCache Status")
			
			Get-NaOption -Controller $controller -OptionName "flexscale.enable"
			
			break
		}
	"A" {
			$logger.Info("Enable FlashCache on $controller")
			
			Set-NaOption -Controller $controller -OptionName "flexscale.enable" -OptionValue "on" -ErrorAction SilentlyContinue
			
			break
		}
	"R" {
			$logger.Info("Disable FlashCache on controllers")
			
			Set-NaOption -Controller $controller -OptionName "flexscale.enable" -OptionValue "off" -ErrorAction SilentlyContinue
			
			break
		}
	}
	$logger.Info("Leaving function FlashCache on $controller")
}
			
#Step 22 - Create the nessesary infrastructure volume
function Volumes([string] $cmd, [NetApp.Ontapi.Filer.NaController] $controller, [string] $aggr, [Hashtable] $volumes) {
	$logger.Info(" ")
    $logger.Info("Entered function Volumes on $controller")

    switch ($cmd) {
    "A" {
			# Wait till aggregate is online
			# TODO: Maximal number of attempts
			Write-Host "Waiting for aggregate $aggr to be created" -NoNewline
			while ((Get-NaAggr -Controller $controller -Names $aggr).State -match "creating") {
				write-host "." -NoNewLine -ForegroundColor "Red"
				Start-Sleep $AGGR_ATTEMPT_DELAY
			}
	
            foreach ($volName in $volumes.Keys) {
				$logger.Info("Creating volume $volName on $controller")
			
                $volProperties_h = $volumes.Get_Item($volName)
        
				$volume = $null
				if(!(Get-NaVol -Controller $controller -Names $volName -ErrorAction SilentlyContinue)) {
                	$volume = New-NaVol -Controller $controller -Aggregate $aggr -Name $volName -SpaceReserve none -Size $volProperties_h.Get_Item("size")
				} else {
					# Make sure the existing volume is online
					$logger.Warn("Volume $volName exists on $controller, using the existing one")
					Set-NaVol -Controller $controller -Name $volName -Online
				}
        
                if($volProperties_h.Get_Item("sis_enable")) {
                    Enable-NaSis -Controller $controller -Volume $volume | Set-NaSis -Controller $controller -Schedule "0@mon,tue,wed,thu,fri,sat,sun"
                }
        
                if(!$volProperties_h.Get_Item("snap_schedule_enable")) {
                    Set-NaSnapshotSchedule -Controller $controller -TargetName $volName -Weeks 0 -Days 0 -Hours 0 -Minutes 0
                    Set-NaSnapshotReserve -Controller $controller -TargetName $volName -Percentage 0
                }
            }
            
            break
        }
    "R" {   
            foreach ($volName in $volumes.Keys) {
				$logger.Info("Removing volume $volName")
                Set-NaVol -Controller $controller -Name $volName -Offline
				Remove-NaVol -Controller $controller -Name $volName -Confirm:$false
            }
            
            break
        }
    }   
    
    $logger.Info("Leaving function Volumes on $controller")
}



#Step 23 - Create the infrastructure IP space 
function IPSpace() {
	$logger.Info("Start step 23 for controller $controller")
	Remove-NaNetIpspace -Controller $controllera -Name "infrastructure"
	New-NaNetIpspace -Controller $controllera -Name "infrastructure" -Interfaces "$VIRTUAL_ETH_INTERFACE_NAME"
	Remove-NaNetIpspace -Controller $controllerb -Name "infrastructure"
	New-NaNetIpspace -Controller $controllerb -Name "infrastructure" -Interfaces "$VIRTUAL_ETH_INTERFACE_NAME"
	$logger.Info("Step 23 completed")
}

#Step 23 - Create the infrastructure IP space 
function IPSpace_viaSSH([string] $cmd, [NetApp.Ontapi.Filer.NaController] $controller) {
	$logger.Info(" ")
	$logger.Info("Entered function IPSpace_viaSSH on $controller")
	
	switch ($cmd) {
	"A" {
			$ssh_cmd = @("ipspace create infrastructure",
		    "ipspace assign infrastructure $VIRTUAL_ETH_INTERFACE_NAME-<<var_global_nfs_vlan_id>>")
    
		    foreach ($line in $ssh_cmd) {
		        
		        foreach($item in $config.GetEnumerator()) {
		             $line = $line.Replace($item.Name, $item.Value)
		        }
				
				$logger.Info("Executing ssh command $line")
		        Invoke-NaSsh  -Command $line -Controller $controller
		    }
			
			break
		}
	"R" {
			$ssh_cmd = @(	"ipspace assign default-ipspace $VIRTUAL_ETH_INTERFACE_NAME-<<var_global_nfs_vlan_id>>",
							"ipspace destroy infrastructure")

			foreach ($line in $ssh_cmd) {
		        foreach($item in $config.GetEnumerator()) {
		             $line = $line.Replace($item.Name, $item.Value)
		        }
				
				$logger.Info("Executing ssh command $line")
		        Invoke-NaSsh  -Command $line -Controller $controller
		    }
			
			break
		}
	}

	$logger.Info("Leaving function IPSpace_viaSSH on $controller")
}


#Step 24 - Create the infrastructure vfiler units
function VFilers([string] $cmd, [NetApp.Ontapi.Filer.NaController] $controller, [Hashtable] $vFiler_h) {
	$logger.Info(" ")
	$logger.Info("Entered function VFilers on $controller")
	
	switch ($cmd) {
	"A" {
				New-NaVfiler -Controller $controller -Name $vFiler_h.Get_Item("name") -Ipspace "infrastructure" -Addresses $vFiler_h.Get_Item("address") -Storage $vFiler_h.Get_Item("storage")
				Set-NaVfilerPassword -Controller $controller -Name $vFiler_h.Get_Item("name") -Password $VAR_GLOBAL_DEFAULT_PASSWD
		}
	"R" {
                Stop-NaVfiler -Controller $controller -Name $vFiler_h.Get_Item("name")
				Remove-NaVfiler -Controller $controller -Name $vFiler_h.Get_Item("name") -Confirm:$false
		}
	}

	$logger.Info("Step 24 completed")
}


#Step 24_a_half
### cmdline controllera : ifconfig $VIRTUAL_ETH_INTERFACE_NAME-100 <<var_infrastructure_vfiler_1>>
### cmdline controllerb: ifconfig $VIRTUAL_ETH_INTERFACE_NAME-100 <<var_infrastructure_vfiler_2>>
### put this into /etc/rc file
function SetIPtovif([string] $cmd, [NetApp.Ontapi.Filer.NaController] $controller, [Hashtable] $vFiler_h) {
	$logger.Info(" ")
    $logger.Info("Entered function SetIPtovif on $controller")

	$vFilerAddress = $vFiler_h.Get_Item("address")
	$ifconfigSshCmd = "ifconfig $VIRTUAL_ETH_INTERFACE_NAME-<<var_global_nfs_vlan_id>> $vFilerAddress"
	
	$ifconfigHash = ComputeMD5Hash $ifconfigSshCmd
	$fingerprintStart = "# vfiler begin $ifconfigHash"
	$fingerprintEnd = "# vfiler end $ifconfigHash"
	
	switch ($cmd) {
	"A"	{	
   			# Collect beginning fingerprint
   			$rcFileSshCmd_a = @("wrfile -a /etc/rc `"$fingerprintStart`"")
			
   			 foreach ($line in $ifconfigSshCmd) {        
        		foreach($item in $config.GetEnumerator()) {
             		$line = $line.Replace($item.Name, $item.Value)
				}

				Invoke-NaSsh -Controller $controller -Command $line		
				
				$rcFileSshCmd_a += "wrfile -a /etc/rc `"$line`""
        	}
			
			# Collect end fingerprint
			$rcFileSshCmd_a += "wrfile -a /etc/rc `"$fingerprintEnd`""
			
			# Check if entry in /etc/rc exists
			$oldFile = Invoke-NaSsh -Controller $controller -Command "rdfile /etc/rc"
			if(!($oldFile -match "$fingerprintStart\b")) {
				foreach ($rcFileSshCmd in $rcFileSshCmd_a) {
					Invoke-NaSsh -Controller $controller -Command $rcFileSshCmd
				}
			}
			
			break
		}
	"R"	{
			$ssh_cmd = "ifconfig $VIRTUAL_ETH_INTERFACE_NAME-<<var_global_nfs_vlan_id>> 0.0.0.0"
			
			foreach ($line in $ssh_cmd) {        
        		foreach($item in $config.GetEnumerator()) {
             		$line = $line.Replace($item.Name, $item.Value)
				}

				Invoke-NaSsh -Controller $controller -Command $line		
			}
				
			# Remove line from /etc/rc
			$ssh_cmd = "rdfile /etc/rc"
			$oldFile = Invoke-NaSsh -Controller $controller -Command $ssh_cmd

			# Remove vFiler config
			$newFile = $oldFile -replace "$fingerprintStart(.|\n)*?$fingerprintEnd"
							
			# Split lines into an array and remove empty lines
			$newFile -split "`n" | Where-Object { $_ -ne "" } | Set-Variable newFileLines_a
			
			# Move the file so /etc/rc will be empty
			Invoke-NaSsh -Controller $controller -Command "mv /etc/rc /etc/rc.backup"
			
			# Append lines
			foreach ($line in $newFileLines_a) {
				Invoke-NaSsh -Controller $controller -Command "wrfile -a /etc/rc `"$line`""
			}
		}
    }
	
	$logger.Info("Leaving function SetIPtovif on $controller")
}

### Cream on cake, do /etc/hosts
### /etc/hosts
### FLP-FAS-A <ip>
### FLP-FAS-A-vif0-100 <ip>

#Step 25 - Map the nessesary infrastructure volumes to the infrastructure vfiler
function MapVols([string] $cmd, [NetApp.Ontapi.Filer.NaController] $controller, [System.Management.Automation.PSCredential] $cred, [Hashtable] $vFiler_h, [string] $storage) {		
	$logger.Info(" ")
    $logger.Info("Entered function MapVols on $controller")

	switch ($cmd) {	
	"A" {	
			Set-NaVfilerStorage -Controller $controller -Name $vFiler_h.Get_Item("name") -AddStorage $storage

			#Step 26 - Export the infrastructure volumes to the ESXi servers over NFS
			$logger.Info("Exporting volume $storage on vfiler of $controller")
			
			$storagePath = "/vol/" + $storage

			$vFiler = Connect-NaController -Credential $cred -Name $controller -Vfiler $vFiler_h.Get_Item("name")

    		$permitted = @($config.Get_Item("<<var_vm_host1_vmk_nfs_ip>>"),$config.Get_Item("<<var_vm_host2_vmk_nfs_ip>>"))

			Add-NaNfsExport -Controller $vFiler -ReadWrite $permitted -Root $permitted -Path $storagePath -Persistent
			
			# TODO: options httpd.admin.enable on
			
			break
		}
	"R"	{
			$logger.Info("Start step 26 for controller $controller")
			
			# TODO: unnecessary? remove
			Remove-NaNfsExport -Controller $controller -Paths $storage -Persistent
			
			$logger.Info("Step 26 completed")
			
			$logger.Info("Start step 25 for controller $controller")
			
			Set-NaVfilerStorage -Controller $controller -Name $vFiler_h.Get_Item("name") -RemoveStorage $storage
			
			$logger.Info("Step 25 completed")
			
			break
		}
	}	
	$logger.Info("Leaving function MapVols on $controller")
}

#Step 27 - Implement security on the console
function ImplementSecurity() {
	Write-Host "Start step 27"
	Write-Host "Continue with final manual steps to complete the storage controller installation"
	Write-Host "Each section should be performed for each storage controller"

	#Turn on SSH and SSL manually on the console

	Write-Host "Change the root password on the storage controllers"
	Write-Host "***************************************************"
	Write-Host ""
	Write-Host "From the storage controller console:"
	Write-Host "Type 'passwd' to change the password for the root user."
	Write-Host ""
	Write-Host "Enter the new root password twice as prompted."
	Write-Host ""
	Write-Host ""
	Write-Host "Setup SSH on the storage controllers"
	Write-Host "************************************"
	Write-Host "Type 'secureadmin setup ssh' to enable ssh on the storage controller."
	Write-Host ""
	Write-Host "Accept the default values for ssh1.x protocol."
	Write-Host ""
	Write-Host "Enter '1024' for the ssh2.0 protocol."
	Write-Host ""
	Write-Host "Enter 'yes' if the information specified is correct and to create the ssh keys."
	Write-Host ""
	Write-Host "Type 'options telnet.enable off' to disable telnet on the storage controller."
	Write-Host ""
	Write-Host "Type 'secureadmin setup ssl' to enable ssl on the storage controller."
	Write-Host ""
	Write-Host "  Enter country name code: " + $config.Get_Item("<<var_global_ssl_country>>")
	Write-Host ""
	Write-Host "  Enter state or province name: " + $config.Get_Item("<<var_global_ssl_state>>")
	Write-Host ""
	Write-Host "  Enter locality name: " + $config.Get_Item("<<var_global_ssl_locality>>")
	Write-Host ""
	Write-Host "  Enter organization name: " + $config.Get_Item("<<var_global_ssl_org>>")
	Write-Host ""
	Write-Host "  Enter organization unit name: " + $config.Get_Item("<<var_global_ssl_org_unit>>")
	Write-Host ""
	Write-Host "  Enter " + $config.Get_Item("<<var_ntap_B_hostname>>") + "." + $config.Get_Item("<<var_global_domain_name>>") + "as the fully qualified domain name of the storage system."
	Write-Host ""
	Write-Host "  Enter " + $config.Get_Item("<<var_ntap_admin_email_address>>") + " as the administrator’s e-mail address."
	Write-Host ""
	Write-Host "  Accept the default for days until the certificate expires."
	Write-Host ""
	Write-Host "  Enter '1024' for the ssl key length."
	Write-Host ""
	Write-Host ""
	Write-Host "Change filer options"
	Write-Host "********************"
	Write-Host "Enter 'options httpd.admin.enable off' to disable http access to the storage system."
	Write-Host ""
	Write-Host "Enter 'options tls.enable on' to enable Java tools to run in FilerView."
}


#### TODO: FIX PORTS and their names
function SavePortnames
{param($config)
    $config["<<var_ntap_A_fc_2a>>"] = (Get-NaFcpAdapter -Controller $controllera -Adapter 1a | select -property PortName).PortName
    $config["<<var_ntap_A_fc_2b>>"] = (Get-NaFcpAdapter -Controller $controllera -Adapter 1b | select -property PortName).PortName
    $config["<<var_ntap_B_fc_2a>>"] = (Get-NaFcpAdapter -Controller $controllerb -Adapter 1a | select -property PortName).PortName
    $config["<<var_ntap_B_fc_2b>>"] = (Get-NaFcpAdapter -Controller $controllerb -Adapter 1b | select -property PortName).PortName
    
    ## Note config need to be dumped in csv file
}

#############################################
# Start of 'main' section					#
#############################################

isUp $VAR_NTAP_A_MGMT_INT_IP
isUp $VAR_NTAP_B_MGMT_INT_IP
# Gather the NetApp controller credentials
$password = ConvertTo-SecureString $VAR_GLOBAL_DEFAULT_PASSWD -AsPlainText -Force
$cred = New-Object -TypeName System.Management.Automation.PSCredential -ArgumentList "root",$password
#$logger.Info("Updated controller credentials $cred")

# Connect to controllers
Add-NaCredential -Controller $VAR_NTAP_A_MGMT_INT_IP -Credential $cred
Add-NaCredential -Controller $VAR_NTAP_B_MGMT_INT_IP -Credential $cred

$controllera = Connect-NaController -Name $VAR_NTAP_A_MGMT_INT_IP -Credential $cred
$controllerb = Connect-NaController -Name $VAR_NTAP_B_MGMT_INT_IP -Credential $cred

# TODO
$script:logger = Prepare-Logger $LOG_CONFIG_PATH
$script:undoLogger = Prepare-UndoLogger $LOG_CONFIG_PATH

$logger.Info("Connected to controllers")

##############################################
# Enter commands on the lines below
##############################################

if(!$action) {
	$action = 'A'  ### 'R' is for removal
}

# Don't invert functions if they were passed in by undo.log, since they already are
if(!$undoFile) {
	if(!$functions_a) {
		# Functions have to be in single quotes for undo logging to work
		$functions_a = @(	'Licenses $action $controllera',
							'Licenses $action $controllerb',
							
							'HighAvailability $action $controllera',
							
							'Check_equal_WWNN $controllera $controllerb',
							
							'FCP $action $controllera',
							'FCP $action $controllerb',
							
							'NTP $action $controllera',
							'NTP $action $controllerb',
							
							'Aggregate $action $controllera $AGGR_NAME <<var_ntap_A_num_disks_aggr1>>',
							'Aggregate $action $controllerb $AGGR_NAME <<var_ntap_B_num_disks_aggr1>>',
							
							'VLAN_viaSSH $action $controllera $VIRTUAL_ETH_INTERFACE_NAME <<var_global_nfs_vlan_id>>',
							'VLAN_viaSSH $action $controllerb $VIRTUAL_ETH_INTERFACE_NAME <<var_global_nfs_vlan_id>>',
							
							'SNMP $action $controllera',
							'SNMP $action $controllerb',

							# TODO:
							'FlashCache $action $controllera',
							'FlashCache $action $controllerb',
							
							'Volumes $action $controllera $AGGR_NAME $CONTROLLER_A_VOLUMES_H',
							'Volumes $action $controllerb $AGGR_NAME $CONTROLLER_B_VOLUMES_H',
							
							'IPSpace_viaSSH $action $controllera',
							'IPSpace_viaSSH $action $controllerb',
							
							'VFilers $action $controllera $CONTROLLER_A_VFILER_H',
							'VFilers $action $controllerb $CONTROLLER_B_VFILER_H',
							
							'SetIPtovif $action $controllera $CONTROLLER_A_VFILER_H',
							'SetIPtovif $action $controllerb $CONTROLLER_B_VFILER_H',
							
							# TODO: Is infrastructure_* in TR 3939
							'MapVols $action $controllera $cred $CONTROLLER_A_VFILER_H "infra_datastore_1"',
							'MapVols $action $controllerb $cred $CONTROLLER_B_VFILER_H "infra_swap"'
						)
		
	}
	
	if($action -eq "R") {
		[Array]::Reverse($functions_a)
	}
}

foreach ($function in $functions_a) {
	$logger.Debug("Replacing variables in $function")
	# Replace variables
	foreach($item in $config.GetEnumerator()) {
		             $function = $function.Replace($item.Name, $item.Value)
	}
	$logger.Info("Executing $function")

	Invoke-Expression $function
	
	# Collect functions in reverse order
	$logger.Debug("Executed function $function")
	$undoLogger.Info($function)
}

# Not necessary after undo
if($action -eq "A") {
	ImplementSecurity
	SavePortnames $config

	Dump-Csv $csv_file $config
}

$Elapsed.Elapsed
						
return