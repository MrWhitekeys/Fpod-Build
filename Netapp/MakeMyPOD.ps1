Param(
	[parameter(Mandatory=$true)]
	[string]$csv_file
)

function verify_env() {
	## Check for DataONTAP
	$modulename = "DataONTAP"
	
	if(Get-Module -ListAvailable | Where-Object {$_.name -eq $modulename}) {
		write-Host "OK: $modulename Module found"
	}
	else {
		write-Host "WARNING: INSTALL $modulename Powershell Module"
		write-Host "PLS GET IT HERE: http://communities.netapp.com/community/products_and_solutions/microsoft/powershell/data_ontap_powershell_toolkit_downloads"
	}
	
	$modulename = "CiscoUCSPS"
	## Check for CiscoUCSPS
	if(Get-Module -ListAvailable | Where-Object {$_.name -eq $modulename}) {
		write-Host "OK: $modulename Module found in module repository"
	}
	else {
		write-Host "WARNING: INSTALL $modulename Powershell Module - Cisco UCS PowerTool"
		##write-Host "CHECK THESE SITES: "http://developer.cisco.com/documents/2048839/3757058/CiscoUcs-PowerTool-0.9.6.0.zip?redirect=http%3a%2f%2fdeveloper.cisco.com%2fweb%2funifiedcomputing%2fmicrosoft%3fp_p_id%3ddoc_library_summary_portlet_WAR_doclibrarysummaryportlet_INSTANCE_O6sv%26p_p_lifecycle%3d0%26p_p_state%3dnormal%26p_p_mode%3dview%26p_p_col_id%3dcolumn-1%26p_p_col_pos%3d3%26p_p_col_count%3d5"
		write-host "CHECK THIS SITE: http://developer.cisco.com/web/unifiedcomputing/microsoft"
		write-Host "Check presence of C:\Program Files\Cisco\Cisco UCS PowerTool\CiscoUcsPS.psd1"
	}
	
	## Check for java
	java.exe -version
	
	if($? -eq $true){
		write-Host "OK: java is present"
	}
	else {
		write-Host "WARNING: java not found. PLS install or fix path"
		write-Host "PATH: " $env:path		
	}
	
	## Check for log4net
	$modulename = "log4net"
	if((Get-Module -ListAvailable | Where-Object {$_.name -eq $module}) -or (Test-Path "..\lib\log4net-1.2.11\bin\net\3.5\release\log4net.dll")) {
		write-Host "WARNING: INSTALL $modulename Powershell Module - Apache log4net"
		Write-Host "CHECK THIS SITE: http://logging.apache.org/log4net/download_log4net.cgi"
		Write-Host "Check presence of ..\lib\log4net-1.2.11\bin\net\3.5\release\log4net.dll"
	}
}

verify_env

## this corresponds to section 3.2
.\3_2_FAS_part_1 $csv_file

## this corresponds to section 3.3
java -jar ./ssh_exec.jar $csv_file ../N5K/Part1 

## this corresponds to section 3.4
.\3_4_UCS $csv_file

## this corresponds to section 3.6
java -jar ./ssh_exec.jar $csv_file ../N5K/Part2 

## this corresponds to section 3.7
.\3_7_FAS_part_2 $csv_file