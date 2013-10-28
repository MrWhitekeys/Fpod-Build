###########################################################################################################################
# Generate csv with with variables and values from data gathering excel sheet. 										      #
# 			Created by Ryan Neubauer, Ryan@whitekeys.net			 													  #
###########################################################################################################################


###############################################################################################################################
# This Script was built by taking a "Best-of-Breed" approach from many scripts.           						  #
###############################################################################################################################

###########################
# Sets up basic functions #
###########################
 
param([parameter(mandatory=$true)][validateNotNullOrEmpty()]$excelFile, [switch]$toConsole)


### Imports
Import-Module "../src/FPodConfig.psm1"

##### set up script logging

$thisPath = Split-Path (Resolve-Path $MyInvocation.MyCommand.Path)
Start-Transcript "../logs/Get-Answers-Script.log" -Append
Write-Host "Starting script logging."


function Remove-File
{
	param($fileName)
	if (Test-Path($fileName)) { del $fileName }
} ##### End of function Remove-File

######################################
# Do the import from the Excel Sheet #
######################################

##### make sure the Excel file exists
if (!(Test-Path $excelFile))
{ Write-Host "The Excel file, $excelFile, does not exist. Quit the script."; exit(2) }

Write-Host "Read the excel file..."
$fullPathName = Join-Path $thisPath $excelFile
try { $excel = New-Object -ComObject Excel.Application}
catch {
	Write-Host "..Failed to access to Excel application. Quit the script."
	exit(2)
}
$excel.Visible = $false
try { $wb = $excel.Workbooks.Open($fullPathName) }
catch {
	Write-Host "..Failed to open the Excel file, $fullPathName. Quit the script."
	$excel.Quit()
	Remove-ComObject
	exit(3)
}
$Answers = @{}
$Netapp = @{}
$UCS = @{}
$VMWare = @{}
$Global = @{}
$Nexus = @{}
$NX1000v = @{}
$config = @{}
$nexusA = @{}
$nexusB = @{}
$netappA = @{}
$netappB = @{}
$ucsFIA =@{}
$ucsFIB =@{}
$1000vA =@{}
$1000vB =@{}

### First go to Question sheet
$cust_sheet_name = "Answers"
Write-Host "Open worksheet $cust_sheet_name..."
try { $ws1 = $wb.Worksheets.Item($cust_sheet_name) }
catch {
	Write-Host "..Cannot open worksheet $cust_sheet_name. Quit the script."
	$wb.Close()
	$excel.Quit()
	Remove-ComObject
	exit(4)
}
$ws1.Activate()

### Dump answers into Hash
Write-Host "Read values from worksheet $cust_sheet_name..."
$i=2
do{
	$Answers.add($ws1.Cells.Item($i, 1).Value2.Trim(), $ws1.Cells.Item($i, 2).Value2)
	$i++
}
while($ws1.Cells.Item($i, 1).Value2)

###Get Variables
$cust_sheet_name = $answers.Get_Item("<<ans_boot_from>>") + " Variables"
Write-Host "Open worksheet $cust_sheet_name..."
try { $ws1 = $wb.Worksheets.Item($cust_sheet_name) }
catch {
	Write-Host "..Cannot open worksheet $cust_sheet_name. Quit the script."
	$wb.Close()
	$excel.Quit()
	Remove-ComObject
	exit(4)
}
$ws1.Activate()

### Dump answers into Hash
Write-Host "Read values from worksheet $cust_sheet_name..."
$i=3
$temp=$ws1.Cells.Item($i, 1).Value2
while($temp){
	switch -wildcard ($temp)
	{
		"<<ntap*" {$Netapp.add($temp, $ws1.Cells.Item($i, 2).Value2)}
		"<<ucs*" {$UCS.add($temp, $ws1.Cells.Item($i, 2).Value2)}
		"<<nex*" {$Nexus.add($temp, $ws1.Cells.Item($i, 2).Value2)}
		"<<global*" {$Global.add($temp, $ws1.Cells.Item($i, 2).Value2)}
		"<<ans*" {$answers.add($temp, $ws1.Cells.Item($i, 2).Value2)}
		"<<vmw*" {$VMWare.add($temp, $ws1.Cells.Item($i, 2).Value2)}
		"<<nx1*" {if($answers.Get_Item("<<ans_1000v>>")){$NX1000v.add($temp, $ws1.Cells.Item($i, 2).Value2)}}
		default {$config.add($temp, $ws1.Cells.Item($i, 2).Value2)}
	}
	$i++
	$temp=$ws1.Cells.Item($i, 1).Value2
}

Write-Host "Getting Interface Mapping"
$cust_sheet_name = "Interface map"
try { $ws1 = $wb.Worksheets.Item($cust_sheet_name) }
catch {
	Write-Host "..Cannot open worksheet $cust_sheet_name. Quit the script."
	$wb.Close()
	$excel.Quit()
	Remove-ComObject
	exit(4)
}
$ws1.Activate()

### Dump interfaces into Hashes
$i=2
$temp=$ws1.Cells.Item($i, 1).Value2
while($temp){
	
	switch ($temp)
	{
		"<<Nexus_A>>" {$nexusA.add($ws1.Cells.Item($i, 2).Value2, $ws1.Cells.Item($i, 3).Value2)}
		"<<Nexus_B>>" {$nexusB.add($ws1.Cells.Item($i, 2).Value2, $ws1.Cells.Item($i, 3).Value2)}
		"<<NetApp_A>>" {$netappA.add($ws1.Cells.Item($i, 2).Value2, $ws1.Cells.Item($i, 3).Value2)}
		"<<NetApp_B>>" {$netappB.add($ws1.Cells.Item($i, 2).Value2, $ws1.Cells.Item($i, 3).Value2)}
		"<<Fabric_Interconnect_A>>" {$ucsFIA.add($ws1.Cells.Item($i, 2).Value2, $ws1.Cells.Item($i, 3).Value2)}
		"<<Fabric_Interconnect_B>>" {$ucsFIB.add($ws1.Cells.Item($i, 2).Value2, $ws1.Cells.Item($i, 3).Value2)}
		"<<1000V_A>>" {if($answers.Get_Item("<<ans_1000v>>")){$1000vA.add($ws1.Cells.Item($i, 2).Value2, $ws1.Cells.Item($i, 3).Value2)}}
		"<<1000V_A>>" {if($answers.Get_Item("<<ans_1000v>>")){$1000vB.add($ws1.Cells.Item($i, 2).Value2, $ws1.Cells.Item($i, 3).Value2)}}
		default {}
	}
	$i++
	$temp=$ws1.Cells.Item($i, 1).Value2
}


Write-Host "Saving configurations ..."
#Save answers to file so each script 
Dump-Csv "../Config/netapp-config.csv" $Netapp
Dump-Csv "../Config/nexus-config.csv" $Nexus
Dump-Csv "../Config/ucs-config.csv" $UCS
Dump-Csv "../Config/vmware-config.csv" $VMWare
Dump-Csv "../Config/global-config.csv" $Global
Dump-Csv "../Config/answers-config.csv" $answers 
Dump-Csv "../Config/Device/nexusA.csv" $nexusA
Dump-Csv "../Config/Device/nexusB.csv" $nexusB
Dump-Csv "../Config/Device/netappA.csv" $netappA
Dump-Csv "../Config/Device/netappB.csv" $netappB
Dump-Csv "../Config/Device/ucsFIA.csv" $ucsFIA
Dump-Csv "../Config/Device/ucsFIB.csv" $ucsFIB
if($answers.Get_Item("<<ans_1000v>>")){
	Dump-Csv "../Config/1000v-config.csv" $NX1000v
	Dump-Csv "../Config/Device/1000vA.csv" $1000vA
	Dump-Csv "../Config/Device/1000vB.csv" $1000vB
}

Dump-Csv "../Config/config.csv" $config 
Write-Host "Save complete ..."
##### close Excel and cleanup
Write-Host "Close Excel file..."
$wb.Close()
$excel.Quit()
Remove-Variable wb, excel, answers, Global, VMWare, UCS, Nexus, Netapp

Stop-Transcript
