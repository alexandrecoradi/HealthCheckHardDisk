# Health Check HardDisk - Verificar saúde do disco

Já imaginou ser preditivo com problemas no disco referente aos computadores de seu parque? Pensando nisso esse projeto contempla varias verificações que podem ajudar de forma proativa a avaliação e substituição do disco. Pense em executar uma rotina semanal para essa validação, utilize recursos nativos como SchedulerTask do Windows ou ferramentas de deploy como SCCM e Ivanti Landesk. Neste projeto os dados obtidos na ponta são enviados para um webserver, e de la tratamos, criamos dashboards no grafana e alertas. 


# Funcao para verificar erros de Disco no Event Viewer
```
function CheckEvent 
{
  IF(Get-EventLog -LogName System -Source Disk -EntryType error -ErrorAction SilentlyContinue | Select-Object -Property Source, EventID, InstanceId, Message -First 1)
    {
      $global:status_checkevent = "Error Disk Event"
    }
  IF(Get-EventLog -LogName System | Where-Object {$_.EventID -eq 7} |  Select-Object -Property Source, EventID, InstanceId, Message -First 1)
    {
      $global:status_checkevent_ID7 = "Error Disk has a bad block Event ID 7"
    }
}
```


# Funcao para verificar erros com leitura, escrita e temperatura do disco
```
function CheckHeathDisk
{
    $diskerror = (Get-PhysicalDisk)[0] | Get-StorageReliabilityCounter | select ReadErrorsCorrected, ReadErrorsTotal, ReadErrorsUncorrected, Temperature, Wear, WriteErrorsCorrected, WriteErrorsTotal,WriteErrorsUncorrected 
    $global:CheckHealthDisk_ReadErrorsCorrected = $diskerror.ReadErrorsCorrected
    $global:CheckHealthDisk_ReadErrorsTotal = $diskerror.ReadErrorsTotal
    $global:CheckHealthDisk_ReadErrorsUncorrected = $diskerror.ReadErrorsUncorrected
    $global:CheckHealthDisk_Temperature = $diskerror.Temperature
    $global:CheckHealthDisk_Wear = $diskerror.Wear
    $global:CheckHealthDisk_WriteErrorsCorrected = $diskerror.WriteErrorsCorrected
    $global:CheckHealthDisk_WriteErrorsTotal = $diskerror.WriteErrorsTotal
    $global:CheckHealthDisk_WriteErrorsUncorrected = $diskerror.WriteErrorsUncorrected    
}
```

# Funcao para verificar erros de SMART
```
function CheckSMART 
{
	$failures = Get-WmiObject -namespace "root\wmi" -ClassName MSStorageDriver_FailurePredictStatus -ErrorAction SilentlyContinue | Select-Object InstanceName, PredictFailure, Reason | Where-Object -Property PredictFailure -NE $false
	foreach($failure in $failures)
	{
	  $global:CheckHealthSMART = "Error SMART"
	}
}
 ```

# Funcao para verificar Status do disco
 ```
function CheckHeathDiskStatus {
    $CheckInfoHeathDisk = (Get-PhysicalDisk)[0] | select FriendlyName, MediaType, HealthStatus, Size
    $global:PhysicalDiskStatus_FriendlyName = $CheckInfoHeathDisk.FriendlyName
    $global:PhysicalDiskStatus_MediaType = $CheckInfoHeathDisk.MediaType
    $global:PhysicalDiskStatus_HealthStatus = $CheckInfoHeathDisk.HealthStatus
    #$global:PhysicalDiskStatus_Size = $CheckInfoHeathDisk.Size/1gb
    
}
 ```
 
# Verificar espaco de armazenamento do disco
 ```
$StorageSize = Get-WmiObject Win32_LogicalDisk | Where-Object { $_.DriveType -eq "3" -and $_.DeviceID -like "*c*"} | 
Select-Object SystemName, 
    @{ Name = "Drive" ; Expression = { ( $_.DeviceID ) } },
    @{ Name = "Size" ; Expression = {"{0:N1}" -f ( $_.Size / 1gb)}},
    @{ Name = "FreeSpace" ; Expression = {"{0:N1}" -f ( $_.Freespace / 1gb ) } },
    @{ Name = "PercentFree" ; Expression = {"{0:P1}" -f ( $_.FreeSpace / $_.Size ) } }  
    $GlobalStorageDrive = $StorageSize.Drive
    $GlobalStorageSize = $StorageSize.Size
    $GlobalStorageFreeSpace = $StorageSize.FreeSpace
    $GlobalStoragePercentFree = $StorageSize.PercentFree
  ```
