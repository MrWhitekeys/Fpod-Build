function Read-FPodConfig([string] $fpod_conf) {

    $replace_table = @{}
    $pattern = "<<.*>>"

    try {
        Import-Csv $fpod_conf -Delimiter ',' | foreach-object {
            $varname = $_."Variable Name"
            $varvalue = $_."Variable Value"
                      
            $addkeyvalue = $true
            
            if($varvalue.Length -eq 0) {
                $addkeyvalue = $false
            }
            
            if($varname.Length -eq 0) {
                $addkeyvalue = $false
            }
            
            if($varname -eq $null) {
                $addkeyvalue = $false
            }
            
            if($varvalue -eq $null) {
                $addkeyvalue = $false
            }
                    
            if ($varname -eq $varvalue) {
                $addkeyvalue = $false
                write-host $varname " gleich " $varvalue
            }
            
            if ($varname | Select-String $pattern) {
                
            } else {
                $addkeyvalue = $false  
            }
                        
            if($addkeyvalue) {
                if ($replace_table.ContainsKey($varname)) {
                    $replace_table.Set_Item($varname, $varvalue)
                }
                else {
                    $replace_table.Add($varname, $varvalue)
                }
            }   
        }
    }
    
    ### DirectoryNotFoundException
    catch [Exception] {
        throw "Cannot read $fpod_conf"
        Write-Host $_.Exception.ToString()
    }
    
    if($replace_table.Count -eq 0) {
        throw "Couldnt read values from config file $fpod_conf"
    }
       
    ### loop free? we only want concrete parameters in the configuration
    foreach($item in $replace_table.GetEnumerator()) {
         foreach($jtem in $replace_table.GetEnumerator()) {
            if($item.Name -eq $jtem.Value) {
                Write-Host  $item.Name
            }
        }
    }

    $replace_table
}


function Test-VarPresence([string] $scriptfile, $config) {
    $tmp = Get-Content $scriptfile
    $code = [string] $tmp

    $pattern = "<<.*>>"

    filter Matches($pattern) {
        $_ | Select-String $pattern | Select-Object -ExpandProperty Matches | Select-Object -ExpandProperty Value
    }

    foreach($b in $code.split(" ")) {
        if($b -match $pattern) {
            
            if($config.ContainsKey($matches[0])) {
                ##ok
            }
            else {
                write-host $matches[0] + " is missing in " + $csv_file
            }
        }
    }
}

function Append-Var([string] $file, [string] $key, [string] $value) {
	"$key;$value;" | out-file $file -append
}

function Dump-Csv([string] $file, $conf) {
    "Variable Name,Variable Value" | out-file $file
    foreach($item in ($conf.GetEnumerator() | sort name) ) {
        "" + $item.Name + "," + $item.Value | out-file $file -append
    }
}

function isUp([string] $host_or_ip) {
    $ping = new-object System.Net.Networkinformation.Ping
    do{
        $result = $ping.send($host_or_ip);
        write-host "." -NoNewLine -ForegroundColor "Red"}
    until ($result.status -eq "Success")
    write-host (" " + $host_or_ip + " is up")
}
