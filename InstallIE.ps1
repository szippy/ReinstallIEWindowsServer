
$Bool = ""
$path = '\\Enter\\Path\Like\INSTALLS\_Microsoft\Server\Server 2012\Windows_Svr_Std_and_DataCtr_2012_R2_64Bit.ISO'
$LogString

Function PVS
{
    Invoke-Command -ComputerName $PVSName -ScriptBlock {change user /install } 
}

Function Log {
    Add-Content $Logfile -value $logstring
}



#is it on/did you mess up the name?
While(!$bool){

    Write-Host What PVS would you like to uninstall IE 11 from?

    $PVSName = Read-Host 

    Write-Host .......
    #If it's real break
    if (Test-Connection -ComputerName $PVSName -Quiet) {
	    Write-Host $PVSName is online
        $bool = "true"
    }
    #if not ask again
    else {
        Write-Host $PVSName Is not online or does not exist. Re-enter the name of the PVS to continue

    }
}
#server 2012? 
$OSVersion = (Invoke-Command -ComputerName $PVSName {get-itemproperty -Path "HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion" -Name ProductName}).ProductName 

#if not, break
if (!($OSVersion -eq "Windows Server 2012 R2 Standard")){
    Write-Host $PVSName is not running Windows Server 2012 R2. This script only works on 2012 R2 at this time. 
    Write-Host Press enter to exit
    Read-Host
    exit

}

Write-Host Beginning uninstall. Your log will be at C:\Log\ielog.txt
#Create Log
$Logfile = "\\$PVSName\c$\Log\ielog.txt"
$LogString = "Log File sucecssfully created" 
Log

#Create Session
$s = New-PSSession -ComputerName $PVSName 

#Copy necessary files
Copy-Item -Path "\\Path\Like\INSTALLS\_Microsoft\Server\Server 2012\Windows_Svr_Std_and_DataCtr_2012_R2_64Bit.ISO" -Destination \\$PVSName\d$\Windows_Svr_Std_and_DataCtr_2012_R2_64Bit.ISO

#how to pvs
PVS

#Uninstall Internet Explorer, and remove package. 
Invoke-Command -Session $s -ScriptBlock {dism /online /disable-feature:"Internet-Explorer-Optional-amd64" /remove /quiet}

#Wait long enough for computer to not be in the process of shutting down before testing if its shutting down
Start-Sleep 400

#Check if the computer is on
while (!(Test-Connection -ComputerName $PVSName -Quiet)) {
	    Write-Host Computer has not rebooted. Please delete the maintnence image and try again.  

}

#Check that Internet Explorer has successfully uninstalled

$ie = (Invoke-Command -ComputerName $PVSName {get-itemproperty -Path "HKLM:\SOFTWARE\Microsoft\Internet Explorer"}).Version
if (!($ie -contains '*9.11*')){
    Write-Host Internet explorer has been uninstalled. 
    $LogString = "IE has been sucessfully uninstalled" 
    Log

} 

else {
    Write-Host Internet explorer still exists. Please exit the script, and manually check. 
    $LogString = "IE11 still exists on this system. " 
    Log

}

#Begin Reinstall
Write-Host log into the PVS, and press enter when you are ready to continue. This will take a while. 
Read-Host

#Create Session post reboot
$s = New-PSSession -ComputerName $PVSName 

#how to pvs
PVS

#Mount image to E. 
Invoke-Command -Session $s -ScriptBlock{Mount-DiskImage -StorageType ISO -ImagePath d:\Windows_Svr_Std_and_DataCtr_2012_R2_64Bit.ISO}

Start-Sleep 120

#Check that ISO Mounted
#Log
if (Invoke-Command -ComputerName carl17c-xa001 -scriptblock {test-path e:}){
$LogString = "ISO mounted" 
Log
Write-Host Install ISO has been mounted. 
}

else{
   Write-Host the drive could not be mounted. Please mount the drive manually, or delete the maintnence image and restart. Press enter to continue once the drive has been mounted
   $LogString = "ISO mount failed" 
   Log
   Read-Host
}

#Mount WIM
if (!(Test-Path -Path c:\mount)){
    invoke-command -Session $s -ScriptBlock {New-Item -ItemType directory -Path c:\mount}
    $logstring = "c:\mount created"
    log
}

Invoke-Command -Session $s -ScriptBlock {Mount-WindowsImage -ImagePath "e:\sources\install.wim" -Index 2 -Path "c:\mount" -ReadOnly}

Start-Sleep 180


   Write-Host Necessary files have been mounted. 
   $LogString = "install.wim mounted to c\mount" 
   Log

Invoke-Command -Session $s -ScriptBlock {Enable-WindowsOptionalFeature -Online -FeatureName Internet-Explorer-Optional-amd64 -Source "c:\mount\Windows\WinSxS" -LimitAccess}

#Wait long enough for computer to not be in the process of shutting down before testing if its shutting down
Start-Sleep 400

#Rebooting
while (!(Test-Connection -ComputerName $PVSName -Quiet)) {
	    Write-Host ... Rebooting ... 

}

#Check that IE reinstalled
$ie = (Invoke-Command -ComputerName $PVSName {get-itemproperty -Path "HKLM:\SOFTWARE\Microsoft\Internet Explorer"}).Version
    Write-Host Internet explorer has been re-installed. Please wait for cleanup
    $LogString = "IE has been sucessfully re-installed" 
    Log

#Create Session post reboot
$s = New-PSSession -ComputerName $PVSName 

#Finish Cleanup
Write-Host Press enter once the server is online to finalize the cleanup
Read-Host

#how to pvs
PVS

#Cleanup Folder 
Invoke-Command -Session $s -ScriptBlock {Dismount-DiskImage -ImagePath  d:\Windows_Svr_Std_and_DataCtr_2012_R2_64Bit.ISO}
Remove-Item \\$PVSName\d$\Windows_Svr_Std_and_DataCtr_2012_R2_64Bit.ISO


Write-Host $PVSName is complete. Please test, map drives, and roll. Your log will be at C:\Log\ielog.txt. Press enter to exit. 
    Read-Host
