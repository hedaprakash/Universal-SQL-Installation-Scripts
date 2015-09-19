#+-------------------------------------------------------------------+    
#| = : = : = : = : = : = : = : = : = : = : = : = : = : = : = : = : = |    
#|{>/-------------------------------------------------------------\<}| 
#|: | Script Name: CommonCode.ps1                                    | 
#|: | Author:  Prakash Heda                                          | 
#|: | Email:   prakash@sqlfeatures.com	 Blog:www.sqlfeatures.com   		 |
#|: | Purpose: Common functions		  				 |
#|: |                    Date: 02-22-2012         					 |
#| :|     /^(o.o)^\         Version: 1.0                             |
#|{>\-------------------------------------------------------------/<}|  
#| = : = : = : = : = : = : = : = : = : = : = : = : = : = : = : = : = |  
#+-------------------------------------------------------------------+  
#Set-StrictMode -Version latest 
$CommonScriptDir =  split-path -parent $MyInvocation.MyCommand.Path
if (Get-Module -ListAvailable | Where-Object { $_.name -eq "FailoverClusters"})
{  
    if (!(Get-Module | Where-Object { $_.name -eq "FailoverClusters"})) 
    {  
        Import-Module 'FailoverClusters' –DisableNameChecking 
        Write-Output "failover cluster module loaded"
    } 
    else
    {
        Write-Output "Failover cluster is available but not available to load"
    }

}
else
{
    Write-Output "failover cluster module does not exist"
}

if (Get-Module | Where-Object { $_.name -eq "FailoverClusters"}) 
{  
	$ClusterResources=Get-ClusterResource -ErrorAction SilentlyContinue
	ForEach ($ClusterResource in $ClusterResources) 
	{
		If ("SQL Server" -eq $ClusterResource.name) 
		{
			$ClusterName=Get-ClusterResource "SQL Server" | Get-ClusterParameter VirtualServerName
			if ($ClusterName) {$ClusterName=$ClusterName.Value}
	    }
	}
} 


if ($ClusterName)
{$DBSERVER = $ClusterName}
else
{$DBSERVER  = gc env:computername}
$result= Test-Path C:\WINDOWS\Cluster\CLUSDB
#switch ($result)
#    {TRUE{$split = $DBSERVER.split("-");$DBSERVER = $split[0]}}

$runtime=Get-Date -format "yyyy-MM-dd HH:mm:ss"
$Logtime=Get-Date -format "yyyyMMddHHmmss"
$LogtimeShort=Get-Date -format "yyyyMMdd"
$LogtimeShortMDY=Get-Date -format "MMddyyyy"
$runtime=Get-Date -format "yyyy-MM-dd HH:mm:ss"
$LogDay=Get-Date -format "yyyy_MM_dd"
$Logtime=Get-Date -format "yyyy_MM_dd_HH_mm_ss"
$LogHour=Get-Date -format "yyyy_MM_dd_HH"
$LogMinute=Get-Date -format "yyyy_MM_dd_HH_mm"

 
$ntrights="$CommonScriptDir\bin\ntrights.exe"  
$NetUser ="$CommonScriptDir\bin\NetUser.exe"  




if ( Get-PSSnapin -Registered | where {$_.name -eq 'SqlServerProviderSnapin100'} ) 
{ 
    if( !(Get-PSSnapin | where {$_.name -eq 'SqlServerProviderSnapin100'})) 
    {  
        Add-PSSnapin SqlServerProviderSnapin100 | Out-Null 
    } ;  
    if( !(Get-PSSnapin | where {$_.name -eq 'SqlServerCmdletSnapin100'})) 
    {  
        Add-PSSnapin SqlServerCmdletSnapin100 | Out-Null 
    } 
} 
else 
{ 
    if (Get-Module -ListAvailable | Where-Object { $_.name -eq "sqlps"})
    {  
	    if (!(Get-Module | Where-Object { $_.name -eq "sqlps"})) 
	    {  
	        Import-Module 'sqlps' –DisableNameChecking  | Out-Null 
	    } 
	}
	else
	{
		write-host "${runtime}: SQL Powershell Module is not installed on this server"
	}
} 




set-location "C:\" -PassThru | Out-Null 

[System.Reflection.Assembly]::LoadWithPartialName("Microsoft.SqlServer.SMO")  | out-null
[System.Reflection.Assembly]::LoadWithPartialName("Microsoft.SqlServer.SmoExtended") | out-null
[System.Reflection.Assembly]::LoadWithPartialName("Microsoft.SqlServer.ConnectionInfo") | out-null
[System.Reflection.Assembly]::LoadWithPartialName("Microsoft.SqlServer.SmoEnum") | out-null
[System.Reflection.Assembly]::LoadWithPartialName("System.Windows.Forms") | Out-Null




function ExpandError (
 $ErrorStack = $(throw "Pass error stack"),
 $FunctionParameters = $(throw "ParametersPassed is required")
  )
{

write-host "${runtime}: entered into expanderror" 
$m=$ErrorStack
$m | Format-List

$x=	Switch ($m.Exception.number)
	{ 
		53  { "Network connection issue" }  
		18456  { "login failed" }  
		default {"Not a captured Message" }
	}

$collectErrMessage = "`n Number: " + $m.Exception.Number
$collectErrMessage += "`n Message: " + $m.Exception.Message
$collectErrMessage += "`n Bound Parameters: " + $m.InvocationInfo.BoundParameters
$collectErrMessage += "`n Script Executed: " + $m.InvocationInfo.ScriptName
$collectErrMessage += "`n ErrorCode: " + $m.Exception.ErrorCode
$collectErrMessage += "`n Line Number: " + $m.InvocationInfo.ScriptLineNumber
$collectErrMessage += "`n Line Command: " + $m.InvocationInfo.Line
$collectErrMessage += "`n Function & Parameters Passed: " + $FunctionParameters
$collectErrMessage += "`n Captured Message: " + $x

write-host "${runtime}: Formatted error Message: "  $collectErrMessage
}



function ExecuteSQLFile (
  [string] $DBServer = $(throw "DB Server Name must be specified."),
  [string] $DatabaseName = $(throw "Database Name must be specified."),
  [string] $SQLFile = $(throw "SQLFile must be specified.")
  )
{
	$functionname="CommonCode_ExecuteQuery " 
	$ParametersPassed = "Function Name: " + $functionname + " Database server: " + $DBServer + ", Database Name: " + $DatabaseName + ", SQL File: " + $SQLFile
	#if ($debugflg -ge 2) {write-host "${runtime}: Function Name: " $functionname;	write-Host $ParametersPassed}
	$error.clear()
	
	write-host "${runtime}:  local db server " $local:DBServer
	
trap{ExpandError -ErrorStack $_ -FunctionParameters $ParametersPassed}
     $ReturnResultset=Invoke-Sqlcmd -ServerInstance $local:DBServer -database $local:DatabaseName -InputFile $SQLFile  -QueryTimeout 600000  -Verbose  -ErrorAction Stop 

	 return $ReturnResultset
}



function ExecuteQuery (
  [string] $DBServer = $(throw "DB Server Name must be specified."),
  [string] $DatabaseName = $(throw "Database Name must be specified."),
  [string] $QueryToExecute = $(throw "QueryToExecute must be specified.")
  )
{
	$functionname="CommonCode_ExecuteQuery " 
	$ParametersPassed = "Function Name: " + $functionname + " Database server: " + $DBServer + ", Database Name: " + $DatabaseName + ", Query To Execute: " + $QueryToExecute
	#if ($debugflg -ge 2) {write-host "${runtime}: Function Name: " $functionname;	write-Host $ParametersPassed}
	$error.clear()
	
trap{ExpandError -ErrorStack $_ -FunctionParameters $ParametersPassed}
		$ReturnResultset=Invoke-Sqlcmd -ServerInstance $DBServer -database $DatabaseName -Query $QueryToExecute -QueryTimeout 600000  -Verbose  
		if (!($?)) {ExpandError -ErrorStack $_ -FunctionParameters $ParametersPassed}
		return $ReturnResultset
}



function fnGrantSQLStartupAccountsRights ($Local:SQLStartupAccount)
{
Write-Host  `n
		try
	{
		$SeBatchLogonRight = $ntrights + " +r SeBatchLogonRight -u `"$Local:SQLStartupAccount`"" 
		invoke-expression $SeBatchLogonRight
		$SeLockMemoryPrivilege = $ntrights + " +r SeLockMemoryPrivilege -u `"$Local:SQLStartupAccount`""  
		invoke-expression $SeLockMemoryPrivilege
		$SeServiceLogonRight = $ntrights + " +r SeServiceLogonRight -u `"$Local:SQLStartupAccount`"" 
		invoke-expression $SeServiceLogonRight
		$MadeLocalAdministrator = "net localgroup administrators /add `"$Local:SQLStartupAccount`"" 
		$resultAdminExists=invoke-expression "net localgroup administrators"
		if (!($resultAdminExists -like $Local:SQLStartupAccount))
		{
			invoke-expression $MadeLocalAdministrator 
		}
	}
	catch
	{
		$global:flgError=1
		Write-ERROR "Error! while granting rights to sqlstartup account" `n
	}

Write-Host  `n

}



function fnConfigSqlMinMaxMemory  ($DBServer,$DatabaseName, $MinMem,$MaxMem)
{

write-host "${runtime}: DBServer $DBServer DatabaseName  $DatabaseName MinMem $MinMem MaxMem $MaxMem"


$cmdspconfigureDisable = 
"
	USE master;
    select @@SERVERNAME;
	EXEC sys.sp_configure N'min server memory (MB)', N'$MinMem';
	EXEC sys.sp_configure N'max server memory (MB)', N'$MaxMem';
	RECONFIGURE WITH OVERRIDE;
	EXEC sys.sp_configure N'min server memory (MB)';
	EXEC sys.sp_configure N'max server memory (MB)';
"

#	write-host "${runtime}: cmdspconfigureDisable : $cmdspconfigureDisable"

$cmdspconfigureEnable = 
"
	USE master;
    select @@SERVERNAME;
	EXEC sp_configure 'show advanced option', '1';
	RECONFIGURE WITH OVERRIDE;
	EXEC sys.sp_configure N'min server memory (MB)', N'$MinMem';
	RECONFIGURE WITH OVERRIDE;
	EXEC sys.sp_configure N'max server memory (MB)', N'$MaxMem';
	RECONFIGURE WITH OVERRIDE;
	EXEC sys.sp_configure N'min server memory (MB)';
	EXEC sys.sp_configure N'max server memory (MB)';
	EXEC sp_configure 'show advanced option', '0';
	RECONFIGURE WITH OVERRIDE;
"

#	write-host "${runtime}: cmdspconfigureEnable : $cmdspconfigureEnable"
 

	$QueryGetAdvanceOptionValue=
	"
	declare @ShowAdvancedOptionValue int

	declare @ShowAdvancedOptiontbl table
	(
	Name varchar(200),
	Minimum int,
	maximum int,
	config_value int,
	run_value int
	)
	insert into @ShowAdvancedOptiontbl
	EXEC sp_configure 'show advanced option'

	select @ShowAdvancedOptionValue = run_value from @ShowAdvancedOptiontbl

	select @ShowAdvancedOptionValue
	"

	write-host "${runtime}: QueryGetAdvanceOptionValue: $QueryGetAdvanceOptionValue"
	
	$GetAdvanceOptionValue = ExecuteQuery -DBServer $DBServer -DatabaseName "master" -QueryToExecute $QueryGetAdvanceOptionValue
	$GetAdvanceOptionValue=$GetAdvanceOptionValue.Column1
	#write-host "${runtime}: GetAdvanceOptionValue: " $GetAdvanceOptionValue

	if ($GetAdvanceOptionValue -ne 1 )
	{
		write-host "${runtime}: cmdspconfigureEnable: " $cmdspconfigureEnable 
		$retFunctionfnConfigSqlMinMaxMemory = ExecuteQuery -DBServer $DBServer -DatabaseName "master" -QueryToExecute $cmdspconfigureEnable
	}
	else
	{
		write-host "${runtime}: cmdspconfigureDisable: " $cmdspconfigureDisable 
		$retFunctionfnConfigSqlMinMaxMemory = ExecuteQuery -DBServer $DBServer -DatabaseName "master" -QueryToExecute $cmdspconfigureDisable
	}
}

function fnCreateLoginGrantRole  ($DBServer,$LoginName,$ServerRole,$LoginPassword)
{

	write-host "${runtime}: DBServer $DBServer LoginName $LoginName,ServerRole $ServerRole,LoginPassword $LoginPassword"

	$QueryCreateLoginGrantRole=
	"
	USE [master];
	if not exists(select 1 from master..syslogins where name = '$LoginName')
	CREATE LOGIN [$LoginName] FROM WINDOWS WITH DEFAULT_DATABASE=[master];
	EXEC master..sp_addsrvrolemember @loginame = N'$LoginName', @rolename = N'sysadmin';
	"

	write-host "${runtime}: QueryCreateLoginGrantRole: $QueryCreateLoginGrantRole"
	
	$GetAdvanceOptionValue = ExecuteQuery -DBServer $DBServer -DatabaseName "master" -QueryToExecute $QueryCreateLoginGrantRole
}


function fnLoadSQLPSModule
{


$fnsuccess=0
		if (Get-Module -ListAvailable | Where-Object { $_.name -eq "sqlps"})
	    {  
            Write-output "sqlps module is available"
		    if (!(Get-Module | Where-Object { $_.name -eq "sqlps"})) 
		    {  
                Write-output "sqlps module is not loaded"    
		        Import-Module 'sqlps' –DisableNameChecking 
				$fnsuccess=1
		    } 
            else
            {
                Write-output "sqlps module is already loaded"                        
                $fnsuccess=1
            }
		}
		else
		{
			write-host "${runtime}: SQL Powershell Module is not installed on this server"

            Get-Module -ListAvailable | Where-Object { $_.name -eq "sql"}
			if ( Get-PSSnapin -Registered | where {$_.name -eq 'SqlServerProviderSnapin100'} ) 
			{ 
			    if( !(Get-PSSnapin | where {$_.name -eq 'SqlServerProviderSnapin100'})) 
			    {  
			        Add-PSSnapin SqlServerProviderSnapin100 | Out-Null 
			    } ;  
			    if( !(Get-PSSnapin | where {$_.name -eq 'SqlServerCmdletSnapin100'})) 
			    {  
			        Add-PSSnapin SqlServerCmdletSnapin100 | Out-Null 
			    } 
				$fnsuccess=1
			} 
			else
			{
				try
				{
					Add-PSSnapin SqlServerProviderSnapin100 | Out-Null 
			        Add-PSSnapin SqlServerCmdletSnapin100 | Out-Null 
					$fnsuccess=1
				}
				catch {
					write-host "${runtime}: SQL module was not found thus post installation steps are not completed, please manyally implement them"
					$fnsuccess=0
				
				}
			}
		}
	return $fnsuccess
}




function fnAddTempFiles ($DBServer,$CPUCount, $SQLTEMPDBDataDIR)
{

	write-host "${runtime}: DBServer $DBServer CPUCount $CPUCount"

	$QueryGetTempDataFilesCount=
	"
	declare @NoOfTempDataFiles int,@TempDataDefaultFileSize int,@qIncreaseTempDataDefaultFileSize nvarchar(4000)
	select @NoOfTempDataFiles = count(*) from tempdb..sysfiles where groupid=1
	select @NoOfTempDataFiles
	"
	write-host "${runtime}: QueryGetTempDataFilesCount: $QueryGetTempDataFilesCount"

	$GetTempDataFilesCount = ExecuteQuery -DBServer $DBServer -DatabaseName "master" -QueryToExecute $QueryGetTempDataFilesCount
	$GetTempDataFilesCount=$GetTempDataFilesCount.Column1
	write-host "${runtime}: GetTempDataFilesCount: $GetTempDataFilesCount" 


	$QueryTempDataDefaultFileSize=
	"
	declare @TempDataDefaultFileSize int,@qIncreaseTempDataDefaultFileSize nvarchar(4000)

	select @TempDataDefaultFileSize= size from tempdb..sysfiles where fileid=1
	select @TempDataDefaultFileSize  as 'SizeBeforeUpdate'  

	if @TempDataDefaultFileSize=131072 or @TempDataDefaultFileSize=1024
	USE [master];ALTER DATABASE [tempdb] MODIFY FILE ( NAME = N'tempdev', SIZE = 2GB)

	select @TempDataDefaultFileSize= size from tempdb..sysfiles where fileid=1
	select @TempDataDefaultFileSize  as 'SizeafterUpdate'  
	"
	write-host "${runtime}: QueryTempDataDefaultFileSize : $QueryTempDataDefaultFileSize"

	ExecuteQuery -DBServer $DBServer -DatabaseName "master" -QueryToExecute $QueryTempDataDefaultFileSize

	$QueryTempLogDefaultFileSize=
	"
	declare @TempLogDefaultFileSize int

	select @TempLogDefaultFileSize= size from tempdb..sysfiles where fileid=2
	select @TempLogDefaultFileSize  as 'TempLogSizeBeforeUpdate'  

	if @TempLogDefaultFileSize=131072 or @TempLogDefaultFileSize=1024
	USE [master];ALTER DATABASE [tempdb] MODIFY FILE ( NAME = N'templog', SIZE = 2GB)

	select @TempLogDefaultFileSize= size from tempdb..sysfiles where fileid=2
	select @TempLogDefaultFileSize  as 'TempLogSizeAfterUpdate'  
	"
	write-host "${runtime}: QueryTempLogDefaultFileSize : $QueryTempLogDefaultFileSize"

	ExecuteQuery -DBServer $DBServer -DatabaseName "master" -QueryToExecute $QueryTempLogDefaultFileSize


	$i = $GetTempDataFilesCount+1
	while ($i -le $CPUCount) 
	{
		Write-Host $i
		$qAddTempDataDefaultFileSize="
		ALTER DATABASE [tempdb] ADD FILE ( NAME = N'tempdev$i', FILENAME = N'$SQLTEMPDBDataDIR\tempdev$i.ndf' , SIZE = 2GB , FILEGROWTH = 10%)
		"
		$qAddTempDataDefaultFileSize
		ExecuteQuery -DBServer $DBServer -DatabaseName "master" -QueryToExecute $qAddTempDataDefaultFileSize
		$i++
	}
}



function fnEnableCompression ($DBSERVER)
{

write-host "${runtime}: DBServer $DBServer"


$cmdCompression_spconfigureDisable = 
"
	USE master;
    select @@SERVERNAME;
	EXEC sys.sp_configure N'backup compression default', N'1'
	RECONFIGURE WITH OVERRIDE;
	EXEC sys.sp_configure N'backup compression default';
"

#	write-host "${runtime}: cmdspconfigureDisable : $cmdspconfigureDisable"

$cmdCompression_spconfigureEnable = 
"
	USE master;
    select @@SERVERNAME;
	EXEC sp_configure 'show advanced option', '1';
	RECONFIGURE WITH OVERRIDE;
	EXEC sys.sp_configure N'backup compression default', N'1'
	RECONFIGURE WITH OVERRIDE;
	EXEC sys.sp_configure N'backup compression default'
	EXEC sp_configure 'show advanced option', '0';
	RECONFIGURE WITH OVERRIDE;
"

#	write-host "${runtime}: cmdspconfigureEnable : $cmdspconfigureEnable"
 

	$QueryGetAdvanceOptionValue=
	"
		declare @ShowAdvancedOptionValue int

		declare @ShowAdvancedOptiontbl table
		(
		Name varchar(200),
		Minimum int,
		maximum int,
		config_value int,
		run_value int
		)
		insert into @ShowAdvancedOptiontbl
		EXEC sp_configure 'show advanced option'

		select @ShowAdvancedOptionValue = run_value from @ShowAdvancedOptiontbl

		select @ShowAdvancedOptionValue
	"
	write-host "${runtime}: QueryGetAdvanceOptionValue: $QueryGetAdvanceOptionValue"
	
	$GetAdvanceOptionValue = ExecuteQuery -DBServer $DBServer -DatabaseName "master" -QueryToExecute $QueryGetAdvanceOptionValue
	$GetAdvanceOptionValue=$GetAdvanceOptionValue.Column1
	write-host "${runtime}: GetAdvanceOptionValue: " $GetAdvanceOptionValue

	if ($GetAdvanceOptionValue -ne 1 )
	{
		write-host "${runtime}: cmdCompression_spconfigureEnable: " $cmdCompression_spconfigureEnable 
		$retFunctionfnConfigSqlMinMaxMemory = ExecuteQuery -DBServer $DBServer -DatabaseName "master" -QueryToExecute $cmdCompression_spconfigureEnable
	}
	else
	{
		write-host "${runtime}: cmdCompression_spconfigureDisable: " $cmdCompression_spconfigureDisable 
		$retFunctionfnConfigSqlMinMaxMemory = ExecuteQuery -DBServer $DBServer -DatabaseName "master" -QueryToExecute $cmdCompression_spconfigureDisable
	}
}


# --- INSTALL-UPDATE --- #
function install-update {
    $session = New-Object -ComObject Microsoft.Update.Session
    $searcher = $session.CreateUpdateSearcher()

    $result = $searcher.Search("IsInstalled=0 and Type='Software' and ISHidden=0")
    
    if ($result.Updates.Count -eq 0) {
         Write-Host "No updates to install"
    }
    else {
        $result.Updates | select Title
    }

    $downloads = New-Object -ComObject Microsoft.Update.UpdateColl

    foreach ($update in $result.Updates){
         $downloads.Add($update)
    }
     
    $downloader = $session.CreateUpdateDownLoader()
    $downloader.Updates = $downloads
    $downloader.Download()

    $installs = New-Object -ComObject Microsoft.Update.UpdateColl
    foreach ($update in $result.Updates){
         if ($update.IsDownloaded){
               $installs.Add($update)
         }
    }

    $installer = $session.CreateUpdateInstaller()
    $installer.Updates = $installs
    $installresult = $installer.Install()
    $installresult

}



function fnRefreshEnvvariables {   
    $locations = 'HKLM:\SYSTEM\CurrentControlSet\Control\Session Manager\Environment',
                 'HKCU:\Environment'

    $locations | ForEach-Object {   
        $k = Get-Item $_
        $k.GetValueNames() | ForEach-Object {
            $name  = $_
            $value = $k.GetValue($_)
            Set-Item -Path Env:\$name -Value $value
        }
    }
}

function Disable-IEESC
{
$AdminKey = “HKLM:\SOFTWARE\Microsoft\Active Setup\Installed Components\{A509B1A7-37EF-4b3f-8CFC-4F3A74704073}”
$UserKey = “HKLM:\SOFTWARE\Microsoft\Active Setup\Installed Components\{A509B1A8-37EF-4b3f-8CFC-4F3A74704073}”
Set-ItemProperty -Path $AdminKey -Name “IsInstalled” -Value 0
Set-ItemProperty -Path $UserKey -Name “IsInstalled” -Value 0
Write-Host “IE Enhanced Security Configuration (ESC) has been disabled.” -ForegroundColor Green
}

function Disable-UAC
{
#Set-ItemProperty -Path "HKLM:\Software\Microsoft\Windows\CurrentVersion\Policies\System" -Name "EnableLUA" -Value "0"

$SystemKey = “HKLM:\Software\Microsoft\Windows\CurrentVersion\Policies\System”
$UACAleadySet=Get-ItemProperty -Path $SystemKey -Name "EnableLUA"  -ErrorAction Continue
$UACAleadySet = $UACAleadySet.EnableLUA
Set-ItemProperty -Path $SystemKey -Name "EnableLUA" -Value 0  -Force
if ($UACAleadySet -eq 1) 
{
    if (get-Process -Name "Explorer" -ErrorAction SilentlyContinue) 
        {
            Stop-Process -Name Explorer -Force
            Start-Process Explorer
        }
}
Write-Host “UAC has been disabled.” -ForegroundColor Green
}

function Disable-Firewall
{
netsh advfirewall set allprofiles state off
Write-Host “Firewall has been disabled.” -ForegroundColor Green
}

