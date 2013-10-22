###########################################################################################################################
# Generate csv with with variables and values from data gathering excel sheet. 										      #
# 			Forked and revised by Ryan Neubauer, Ryan@whitekeys.net	 													  #
###########################################################################################################################


###############################################################################################################################
# This Script was built by taking a "Best-of-Breed" approach from many scripts i've found.           						  #
###############################################################################################################################

###########################
# Sets up basic functions #
###########################
 
param([parameter(mandatory=$true)][validateNotNullOrEmpty()]$excelFile, [switch]$toConsole)

function Remove-File
{
	param($fileName)
	if (Test-Path($fileName)) { del $fileName }
} ##### End of function Remove-File

##### set up script logging
$ErrorActionPreference="SilentlyContinue"
Stop-Transcript | out-null
$ErrorActionPreference = "Continue"
$thisPath = Split-Path (Resolve-Path $MyInvocation.MyCommand.Path)
Set-Location $thisPath
$scriptLog = "./Logs/Get-Answers_Script_Log.txt"
$scriptLogFullPath = Join-Path $thisPath $scriptLog
Start-Transcript $scriptLogFullPath -Append
Write-Host "Starting script logging."



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
$Anwsers = @{}
$Netapp = @{}
$UCS = @{}
$VMWare = @{}
$Global = @{}
$Nexus = @{}
$NX1000v = @{}
$config = @{}
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
	$config.add($ws1.Cells.Item($i, 1).Value2.Trim(), $ws1.Cells.Item($i, 2).Value2)
	$i++
}
while($ws1.Cells.Item($i, 1).Value2)

###Get Variables
$cust_sheet_name = $config.Get_Item("<<ans_boot_from>>") + " Variables"
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
while($ws1.Cells.Item($i, 1).Value2){
	switch -wildcard ($ws1.Cells.Item($i, 1).Value2)
	{
		"<<ntap*" {$Netapp.add($_, $ws1.Cells.Item($i, 2).Value2)}
		"<<ucs*" {$UCS.add($_, $ws1.Cells.Item($i, 2).Value2)}
		"<<nex*" {$Nexus.add($_, $ws1.Cells.Item($i, 2).Value2)}
		"<<global*" {$Global.add($_, $ws1.Cells.Item($i, 2).Value2)}
		"<<ans*" {$Answers.add($_, $ws1.Cells.Item($i, 2).Value2)}
		"<<vmw*" {$VMWare.add($_, $ws1.Cells.Item($i, 2).Value2)}
		"<<nx1*" {if($Answers.Get_Item("<<ans_1000v>>")){$NX1000v.add($_, $ws1.Cells.Item($i, 2).Value2)}}
		default {$config.add($_, $ws1.Cells.Item($i, 2).Value2)}
	}
	$i++
}


Write-Host "Save configurations in separate files..."
#Save answers to file so each script can run separately 
$Netapp.GetEnumerator() | sort name | Select-Object -Property Name,Value | export-csv "./Config/netapp-config.csv" -notype
$Nexus.GetEnumerator() | sort name | Select-Object -Property Name,Value | export-csv "./Config/nexus-config.csv" -notype
$UCS.GetEnumerator() | sort name | Select-Object -Property Name,Value | export-csv "./Config/ucs-config.csv" -notype
$VMWare.GetEnumerator() | sort name | Select-Object -Property Name,Value | export-csv "./Config/vmware-config.csv" -notype
$Global.GetEnumerator() | sort name | Select-Object -Property Name,Value | export-csv "./Config/global-config.csv" -notype
$Answers.GetEnumerator() | sort name | Select-Object -Property Name,Value | export-csv "./Config/Answers-config.csv" -notype
if($Answers.Get_Item("<<ans_1000v>>")){
	$NX1000v.GetEnumerator() | sort name | Select-Object -Property Name,Value | export-csv "./Config/1000v-config.csv" -notype
}
#Write-Host "the following items have been added"
#foreach ($name in @($config.keys)){
#	Write-Host "$name "$config.Get_Item($name)
#}
##### close Excel and cleanup
Write-Host "Close Excel file..."
$wb.Close()
$excel.Quit()
Remove-Variable wb, excel, i

