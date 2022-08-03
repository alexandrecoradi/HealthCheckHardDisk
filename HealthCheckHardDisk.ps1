#================================================================================
# Organization: 
# Description:  HealthCheckHardDisk
# Created by:   Alexadre Coradi
# Created on:   23/05/2022
#================================================================================

#Sequencia de informacoes enviadas para webserver, separador ";"
#1º $global:PhysicalDiskStatus_FriendlyName - Nome amigavel do disco
#2º $GlobalStorageFreeSpace - Espaco em disco livre por GB
#3º $global:PhysicalDiskStatus_MediaType - Tipo de disco SSD ou HHD
#4º $global:PhysicalDiskStatus_HealthStatus - Status de Saude do Disco
#5º $global:CheckHealthSMART - Status de sauda da SMART
#6º $global:CheckHealthDisk_ReadErrorsCorrected - Erro de leitura do Disco
#7º $global:CheckHealthDisk_ReadErrorsUncorrected - Erro de leitura do Disco
#8º $global:CheckHealthDisk_Temperature - Temperatura do Disco
#9º $global:CheckHealthDisk_Wear - Alerta de erro do Disco
#10º $global:CheckHealthDisk_WriteErrorsCorrected - Erro de escrita do Disco
#11º $global:CheckHealthDisk_WriteErrorsTotal - Erro de escrita do Disco
#12º $global:CheckHealthDisk_WriteErrorsUncorrected - Erro de escrita do Disco
#13º $global:status_checkevent - Leitura de eventos com ERRO no disco
#14º $global:status_checkevent_ID7 - Leitura de eventos relacionado ao ID7 badblock disk 

#Variais de API
$Hostname = $Env:COMPUTERNAME
$ApplicationName = "HealthCheckHardDisk"
$Status = "Sucesso"

#Variaveis Globais
$global:status_checkevent = "NoErrorEventGeral"
$global:status_checkevent_ID7 = "NoErrorEventID7"
$global:CheckHealthDisk_ReadErrorsCorrected = "NoError"
$global:CheckHealthDisk_ReadErrorsTotal = "NoError"
$global:CheckHealthDisk_ReadErrorsUncorrected = "NoError"
$global:CheckHealthDisk_Temperature = "NoError"
$global:CheckHealthDisk_Wear = "NoError"
$global:CheckHealthDisk_WriteErrorsCorrected = "NoError"
$global:CheckHealthDisk_WriteErrorsTotal = "NoError"
$global:CheckHealthDisk_WriteErrorsUncorrected = "NoError"
$global:CheckHealthSMART = "NoErrorSMART"
$global:PhysicalDiskStatus_FriendlyName = "NoError"
$global:PhysicalDiskStatus_MediaType = "NoError"
$global:PhysicalDiskStatus_HealthStatus = "NoError"
$global:PhysicalDiskStatus_Size = "NoError"

#Funcao para envio de informacao http://URL/relatorios/result/hostname/HealthCheckHardDisk/
function SendStatusWS_OPVSAT {
    param ( 
        [string]$ComputerName,
        [string]$ApplicationName,
        [string]$StatusSolution,
        [string]$Details
    )
    
    #Ambiente de HML
    #$url = "http://URL/ws/inserirstatus/$ComputerName/$ApplicationName/$StatusSolution/$User/$pass/$Details"
    
    #Ambiente de PRD
    $url = "http://URL/ws/inserirstatus/$ComputerName/$ApplicationName/$StatusSolution/$User/$pass/$Details"

    Invoke-RestMethod -URI $url
}

#Funcao para verificar erros de Disco no Event Viewer
function CheckEvent {
IF(Get-EventLog -LogName System -Source Disk -EntryType error -ErrorAction SilentlyContinue | Select-Object -Property Source, EventID, InstanceId, Message -First 1)
    {
  
    $global:status_checkevent = "Error Disk Event"
    }
IF(Get-EventLog -LogName System | Where-Object {$_.EventID -eq 7} |  Select-Object -Property Source, EventID, InstanceId, Message -First 1)
    {
    $global:status_checkevent_ID7 = "Error Disk has a bad block Event ID 7"
    }
}

#Funcao para verificar erros com leitura, escrita e temperatura do disco
function CheckHeathDisk {

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

#Funcao para verificar erros de SMART
function CheckSMART {
	$failures = Get-WmiObject -namespace "root\wmi" -ClassName MSStorageDriver_FailurePredictStatus -ErrorAction SilentlyContinue | Select-Object InstanceName, PredictFailure, Reason | Where-Object -Property PredictFailure -NE $false
	foreach($failure in $failures)
	{
	$global:CheckHealthSMART = "Error SMART"
	}
}

#Funcao para verificar Status do disco
function CheckHeathDiskStatus {
    $CheckInfoHeathDisk = (Get-PhysicalDisk)[0] | select FriendlyName, MediaType, HealthStatus, Size

    $global:PhysicalDiskStatus_FriendlyName = $CheckInfoHeathDisk.FriendlyName
    $global:PhysicalDiskStatus_MediaType = $CheckInfoHeathDisk.MediaType
    $global:PhysicalDiskStatus_HealthStatus = $CheckInfoHeathDisk.HealthStatus
    #$global:PhysicalDiskStatus_Size = $CheckInfoHeathDisk.Size/1gb
    
}

#Funcao para verificar espaco de armazenamento do disco
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


#Chamada das funcoes
CheckEvent
CheckHeathDisk
CheckSMART
CheckHeathDiskStatus

#Agrupamento de informacoes para envio ao webserver
$Details = $global:PhysicalDiskStatus_FriendlyName+";"+$GlobalStorageFreeSpace+";"+$global:PhysicalDiskStatus_MediaType+";"+$global:PhysicalDiskStatus_HealthStatus+";"+$global:CheckHealthSMART+";"+$global:CheckHealthDisk_ReadErrorsCorrected+";"+$global:CheckHealthDisk_ReadErrorsUncorrected+";"+$global:CheckHealthDisk_Temperature+";"+$global:CheckHealthDisk_Wear+";"+$global:CheckHealthDisk_WriteErrorsCorrected+";"+$global:CheckHealthDisk_WriteErrorsTotal+";"+$global:CheckHealthDisk_WriteErrorsUncorrected+";"+$global:status_checkevent+";"+$global:status_checkevent_ID7


#Chamada para envio de informacoes ao webserver
SendStatusWS_OPVSAT -ComputerName $Hostname -ApplicationName $ApplicationName -StatusSolution $Status -Details $Details