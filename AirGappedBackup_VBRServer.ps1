#Sample PowerShell Script of Air-Gapped Veeam Backup Repository


#Local paths and files
$LOCALPATH = "C:\Script"
$LOGFILE= "$LOCALPATH\AirGappedBackupLog_VBRServerLog_$(get-date -f yyyy-MM-dd).txt"

#SMB paths and files
$SMBSHAREPATH = "\\freenas\vbrshare"
$SMBSHARECREDENTIALS = "$LOCALPATH\SMBShareCred.xml"

#Flag files
$VEEAMREMOTEREPOSITORYREADY = "$SMBSHARE\VeeamRemoteRepositoryReady.flag"
$VEEAMVBRSERVERREADY = "$SMBSHAREPATH\VeeamVBRServerReady.flag"

#Create Log file if one does not exist
if (-not (Test-Path $LOGFile -PathType leaf)){     
  New-Item -Path $LOGFile -ItemType File
  Add-Content -Path $LOGFILE -Value ((get-date).ToString(‘yyyy/MM/dd HH:m:s ’) + "New log file Created")
}
else{
  Add-Content -Path $LOGFILE -Value ((get-date).ToString(‘yyyy/MM/dd HH:m:s ’) + "Appending existing log file")
}


$PSCREDENTIALS = Import-CliXml -Path $SMBSHARECREDENTIALS
#Map SMB share
Add-Content -Path $LOGFILE -Value ((get-date).ToString(‘yyyy/MM/dd HH:m:s ’) + "Establishing connection to common VBR share")
if (-not (Get-PSDrive vbrshare -ErrorAction:SilentlyContinue)){
  New-PSDrive -Name vbrshare -PSProvider FileSystem -Root $SMBSHAREPATH -Credential $PSCREDENTIALS
  $PSCREDENTIALS = $null
  Add-Content -Path $LOGFILE -Value ((get-date).ToString(‘yyyy/MM/dd HH:m:s ’) + "Connection to common VBR SMB share estalished")
}
else{
  Add-Content -Path $LOGFILE -Value ((get-date).ToString(‘yyyy/MM/dd HH:m:s ’) + "Connection to common VBR SMB share is already active. Removing connection and establishing again")
  Remove-PSDrive -Name vbrshare
  New-PSDrive -Name vbrshare -PSProvider FileSystem -Root $SMBSHAREPATH -Credential $PSCREDENTIALS
  $PSCREDENTIALS = $null
  Add-Content -Path $LOGFILE -Value ((get-date).ToString(‘yyyy/MM/dd HH:m:s ’) + "Connection to common VBR SMB share estalished")
}

#Add Veeam PS Snapin
Add-Content -Path $LOGFILE -Value ((get-date).ToString(‘yyyy/MM/dd HH:m:s ’) + "Adding VeeamPSSnapin ")
Add-PSSnapin VeeamPSSnapin
Add-Content -Path $LOGFILE -Value ((get-date).ToString(‘yyyy/MM/dd HH:m:s ’) + "VeeamPSSnapin added")

#Set up VBR Server flag 
Add-Content -Path $LOGFILE -Value ((get-date).ToString(‘yyyy/MM/dd HH:m:s ’) + "Setting up Veeam VBR Server Ready flag")
New-Item -Path $VEEAMVBRSERVERREADY -ItemType File -Force #-ErrorAction:SilentlyContinue
Add-Content -Path $LOGFILE -Value  ((get-date).ToString(‘yyyy/MM/dd HH:m:s ’) + "Checking if Veeam Repository is ready")




#Wait for remote repository to be ready
While (-not (Test-Path $VEEAMREMOTEREPOSITORYREADY -PathType leaf)){
  Add-Content -Path $LOGFILE -Value  ((get-date).ToString(‘yyyy/MM/dd HH:m:s ’) + "$D Checking if Veeam Repository is ready"
  Start-Sleep -s 60
}

Add-Content -Path $LOGFILE -Value  ((get-date).ToString(‘yyyy/MM/dd HH:m:s ’) + "$D Veeam Repository is ready"

#Read configuration data


#Connect to VBR server
if (-not(Get-VBRServer)){
  Add-Content -Path $LOGFILE -Value  ((get-date).ToString(‘yyyy/MM/dd HH:m:s ’) + "$D VBR Server not connected. Connecting"
  Connect-VBRServer -Server localhost
}
Else {
  Add-Content -Path $LOGFILE -Value  ((get-date).ToString(‘yyyy/MM/dd HH:m:s ’) + "$D VBR Server already connected. Move on"
}


$CRED = Get-VBRCredentials -Name $BCJUSERNAME
Add-VBRWinServer -Name $BCJREPOSITORYSERVER -Credentials $CRED -Description "Baaaa"
Add-Content -Path $LOGFILE -Value "$D Added BCJ Server"
Add-VBRBackupRepository -Name $BCJREPOSITORYSERVER -Server $BCJREPOSITORYSERVER -Folder "D:\VeeamBackups" -Type WinLocal
$CRED = "0" #Deleting Credentials from Variable
Add-Content -Path $LOGFILE -Value "$D Added BCJ Repository"

#Check if BCJ exists
if (-not(Get-VBRJob -Name $BCJNAME)){
  Get-VBRJob -Name "Backup Job PI-Hole" | Add-VBRViBackupCopyJob -DirectOperation -Name $BCJNAME -Repository "Backup Repository Tower"
    Add-Content -Path $LOGFILE -Value "$D Copy Job $BCJNAME does not exist. Creating new $BCJNAME"
  }
<#Else{
  Add-Content -Path $LOGFILE -Value "$D $BCJNAME already exists, exiting"
  Exit
  }
  #>
$CopyJob = Get-VBRJob -Name $BCJNAME

if ( -not($CopyJob.IsRunning) -and -not($CopyJob.IsIdle) -and -not($CopyJob.IsScheduleEnabled)){
  $D=Get-Date
  $CopyJob | Enable-VBRJob
  Add-Content -Path $LOGFILE -Value "$D BCJ not Enalbed. Enabling BCJ" 
} 

$CopyJob = Get-VBRJob -Name $BCJNAME
$WaitCount=1
While (-not($CopyJob.IsIdle)){
  $D=Get-Date
  Add-Content -Path $LOGFILE -Value "$D BCJ in progress" 
  
  
  Add-Content -Path $LOGFILE -Value "$D Updating HeartBeat file"
  New-Item -Path "C:\Flag\HeartBeat.txt" -ItemType File -Force 
 
  Start-Sleep -s 60
  $WaitCount++
}
$D=Get-Date
$CopyJob | Disable-VBRJob
Add-Content -Path $LOGFILE -Value "$D Disabling BCJ"

Add-Content -Path $LOGFILE -Value "$D Setting flag: BackupCopyFinished"
New-Item -Path $Veeam_Local_BCJ_finished -ItemType File


Remove-PSDrive -name S -ErrorAction:SilentlyContinue

#Remove backup infrastucture 

Get-VBRBackupRepository -Name $BCJREPOSITORYSERVER | Remove-VBRBackupRepository -Confirm:$False
Add-Content -Path $LOGFILE -Value "$D Removed BCJ Repository"
Get-VBRServer -Name $BCJREPOSITORYSERVER | Remove-VBRServer -Confirm:$False
Add-Content -Path $LOGFILE -Value "$D Removed BCJ Server"


