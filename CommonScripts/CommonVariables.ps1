	$global:flgError=0
	$ErrorActionPreference = 'Stop'

	set-location "C:\" -PassThru | Out-Null 
	$ScriptDir =  split-path -parent $ParentScript.MyCommand.Path
	"Script executing: "+ $ParentScript.MyCommand.Path
	$LogPath=$ScriptDir + "\pslogs" 
	$ScriptNameWithoutExt=[system.io.path]::GetFilenameWithoutExtension($ParentScript.MyCommand.Path)
	$ScriptNameWithoutExt
	$TempLog=$LogPath + "\" + $DBSERVER + "_" + $ScriptNameWithoutExt + "_CurrentExecution_" + $Logtime + ".log"
	$LastExecutionLogFile=$LogPath + "\" + $DBSERVER + "_" + $ScriptNameWithoutExt + "_LastExecutionLog_"  + $Logtime + ".log"
	$ExecutionSummaryLogFile=$LogPath + "\" + $DBSERVER + "_"  + $ScriptNameWithoutExt + "_ExecutionSummary.log"
	write-output "${runtime}: ExecutionSummaryLogFile: " $TempLog
	write-output "${runtime}: Common Script location: $CommonScriptDir"
	$LOG=$TempLog
	if(!(test-path $LogPath)){[IO.Directory]::CreateDirectory($LogPath)}
	Add-Content -Path $ExecutionSummaryLogFile -Value "--------------------------------------------------------------------------------------"
	Add-Content -Path $ExecutionSummaryLogFile -Value ("Script Started File Runtime Formatted : " + $runtime + ", File Log Time: " + $Logtime)
	Add-Content -Path $ExecutionSummaryLogFile -Value ("Log Folder: " + $LogPath )
	Add-Content -Path $ExecutionSummaryLogFile -Value ("Last Execution Log : " + $LastExecutionLogFile  )
	Add-Content -Path $ExecutionSummaryLogFile -Value ("Temp Log: " + $TempLog)
	Add-Content -Path $ExecutionSummaryLogFile -Value ("Common Script Dir: " + $CommonScriptDir)
	Add-Content -Path $ExecutionSummaryLogFile -Value ("File Executed From Server: " + $DBSERVER)
	#$flgAdmin=(New-Object Security.Principal.WindowsPrincipal $user).IsInRole([Security.Principal.WindowsBuiltinRole]::Administrator)   
	[Security.Principal.WindowsIdentity]::GetCurrent()| out-string | add-content $ExecutionSummaryLogFile
	Add-Content -Path $ExecutionSummaryLogFile -Value "--------------------------------------------------------------------------------------"
	$CentralServer = "vsacsqlbak02.prod.dx"
	$CentralServerDB= "dbastuff"
	set-location $ScriptDir -PassThru | Out-Null 
	write-output "Directory location is: $PWD" 
    $localUserName= [System.Security.Principal.WindowsIdentity]::GetCurrent().Name