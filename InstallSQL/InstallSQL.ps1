param (
    [string]$SQLStartupAccount = "sqlfeatures\svcSQLfeatures",
    [string]$SQLStartupAccountPassword = "Tester1!",
    [string]$SAPassword = "SAtemp2014",
    [string]$Product = "SQERA_V2",
    [string]$SQLSYSADMINACCOUNTS = "sqlfeatures\SQLDBA",
    [string]$SQLBinariesLocation = ""

    )

#region commonCode
# Execute this to ensure Powershell has execution rights
#Set-ExecutionPolicy Unrestricted -Force
#Set-ExecutionPolicy bypass
#Import-Module ServerManager 
#Add-WindowsFeature PowerShell-ISE
#+-------------------------------------------------------------------+    
#| = : = : = : = : = : = : = : = : = : = : = : = : = : = : = : = : = |    
#|{>/-------------------------------------------------------------\<}| 
#|: | Script Name: InstallSQL.ps1                              		| 
#|: | Author:  Prakash Heda                                          | 
#|: | Email:   Pheda@advent.com	 Blog:www.sqlfeatures.com   		 |
#|: | Purpose: Install Automated SQL installation based on products	|
#|: | 							 	 								|
#|: |                    Date: 05-16-2012         					 |
#| :|     /^(o.o)^\         Version: 1.0                             |
#|{>\-------------------------------------------------------------/<}|  
#| = : = : = : = : = : = : = : = : = : = : = : = : = : = : = : = : = |  
#+-------------------------------------------------------------------+  

#+-------------Common Code started-----------------------------------+    
CLS
#(Get-Variable MyInvocation -Scope 0).Value
"Script executing: "+ $MyInvocation.MyCommand.Path
$ParentScript = $MyInvocation
$CommonScriptDir = join-path -path (split-path -parent (split-path -parent $ParentScript.MyCommand.Path)) -childpath "CommonScripts" 
$commoncodeLocation=$CommonScriptDir + "\CommonCodeNew.ps1"
Import-Module $commoncodeLocation
$commoncodevariables=$CommonScriptDir + "\CommonVariables.ps1"
Import-Module $commoncodevariables
#-------------------------------------------------
#echo GET Server Name. if cluster, use clustername. else use computername
#-------------------------------------------------

#+-------------Common Code end---------------------------------------+    
#+-------------Functions---------------------------------------------+    
#+-------------Functions end---------------------------------------------+    
Write-Host "
-------------------------------------------------------------------
ATTENTION:  This script will install SQL Server, before start please make sure VM snapshot is taken
#-------------------------------------------------------------------
" -foregroundcolor "magenta"

#endregion 

write-host  " SQLStartupAccount = $SQLStartupAccount Passwords: $SQLStartupAccountPassword and SApassword: $SAPassword Product: $Product DB Group:  $SQLSYSADMINACCOUNTS "

if ($SQLSYSADMINACCOUNTS.Length -eq 0 ) 
{throw "DB team group account must be specified."}


#ValidateUser is sysadmin
$installationAccount = [Security.Principal.WindowsIdentity]::GetCurrent();     
$flgAdmin=(New-Object Security.Principal.WindowsPrincipal $installationAccount).IsInRole([Security.Principal.WindowsBuiltinRole]::Administrator)   
if (!($flgAdmin)) {throw "$installationAccount :is not Administrator, login as administrator and restart script"}
# Disable IE security, UAC and firewall
Disable-IEESC
Disable-UAC
Disable-Firewall

if ([System.Version](Get-WmiObject win32_operatingsystem).version -gt  [System.Version]"6.1.7601")
{
    # Install Key windows components
    if (get-WindowsFeature -Name Failover-Clustering){Add-WindowsFeature -Name Failover-Clustering –IncludeManagementTools}
    if (get-WindowsFeature -Name Telnet-Client){Add-WindowsFeature -Name Telnet-Client }
    if (get-WindowsFeature -Name Net-Framework-Core){Add-WindowsFeature -Name Net-Framework-Core }
}


# Disable IPV6
if (!(get-ItemProperty “HKLM:\SYSTEM\CurrentControlSet\Services\Tcpip6\Parameters\” -Name  “DisabledComponents” -ErrorAction SilentlyContinue  ) )
{New-ItemProperty “HKLM:\SYSTEM\CurrentControlSet\Services\Tcpip6\Parameters\” -Name  “DisabledComponents” -Value  0xffffffff -PropertyType “DWord”  -ErrorAction Continue}



#Get No Of CPU On the server
    $colItems = Get-WmiObject -class "Win32_Processor" -namespace "root/CIMV2" 
    $NOfLogicalCPU = 0
    foreach ($objcpu in $colItems)
    {$NOfLogicalCPU = $NOfLogicalCPU + $objcpu.NumberOfLogicalProcessors}
    


#Get Rem on the server
    $mem = Get-WmiObject -Class Win32_ComputerSystem  
    $HostPhysicalMemoryGB=$($mem.TotalPhysicalMemory/1Mb) 
    $HostPhysicalMemoryGB=[math]::floor($HostPhysicalMemoryGB)
#Determine Min Max Ram
    if ($HostPhysicalMemoryGB -le 4100) {$SQLMaxMinMemoryGB = 3000}
    elseif ($HostPhysicalMemoryGB -le 16000) {$SQLMaxMinMemoryGB = $HostPhysicalMemoryGB-2000}
    else {$SQLMaxMinMemoryGB = $HostPhysicalMemoryGB-4000}

#Determine which user is running sql installation script
$installationAccount=($installationAccount | select name).name

write-host "`nTotal CPU: $NOfLogicalCPU Total Memory: $HostPhysicalMemoryGB account Installing SQL Server: $installationAccount"   

	
#Get list of available products
$ExportFileName=$ScriptNameWithoutExt + ".xml"
$installfilepath=$ScriptDir + "\" + $ScriptNameWithoutExt + ".xml"
$InstallSQLMasterLoaded = Import-CliXML  $installfilepath

$sqlSetupPath=(split-path -parent  (split-path -parent (split-path -parent $ParentScript.MyCommand.Path)) )

$SQLPID=join-path -path $sqlSetupPath -childpath  "SQLPID.xml"
$LoadSQLPID = Import-CliXML  $SQLPID


#Print Products supported
$InstallSQLMasterLoaded | select ID,Product,SQLVersion | format-table -AutoSize | Out-String

#Filter the Product
$RsToInstallRet=$InstallSQLMasterLoaded | Where-Object {$_.Product -eq $Product}

#Validate If product is found
$RsToInstallRetCount = (($RsToInstallRet) | group-object count).Count

	if ($RsToInstallRetCount -ne 1 )
	{
		write-error ("Error! there are several install records or no records match, check parameters passed. Count:"  + $RsToInstallRet.count )
        exit
	}
#ReplacePID BeforePrinting
$RsToInstallRet | Out-String | write-host
$SQLLicense=$LoadSQLPID | Where-Object {$_.SQLBinaries -eq $RsToInstallRet.SQLBinaries} | Select-Object -ExpandProperty PID

#Get SQL Binary Location

if ($SQLBinariesLocation.Length -eq 0)
{
    $SQLBinariesLocation = join-path -path (split-path -parent (split-path -parent $CommonScriptDir) ) -childpath "SQLBinaries" 
}


#Create necessary Directories

foreach ($RetResultSet in $RsToInstallRet) 
{

    $SQLVersion=$RsToInstallRet.SQLVersion
    $DotNet4Location= $RsToInstallRet.DotNet4Location
    if (!((($DotNet4Location|measure).count -eq 0) -or ($DotNet4Location -eq "")))  {$DotNet4Location= join-path -path $SQLBinariesLocation -childpath  $RsToInstallRet.DotNet4Location}
    $RetResultSet.SQLBinaries = join-path -path $SQLBinariesLocation -childpath  $RsToInstallRet.SQLBinaries 

	write-host "Now creating required folders"
	write-host ""
	try
	{

		if(!(test-path $RetResultSet.INSTANCEDIR)){[IO.Directory]::CreateDirectory($RetResultSet.INSTANCEDIR)}
		if(!(test-path $RetResultSet.SQLBACKUPDIR)){[IO.Directory]::CreateDirectory($RetResultSet.SQLBACKUPDIR)}	
		if(!(test-path $RetResultSet.SQLUSERDBDIR)){[IO.Directory]::CreateDirectory($RetResultSet.SQLUSERDBDIR)}	
		if(!(test-path $RetResultSet.SQLUSERDBLOGDIR)){[IO.Directory]::CreateDirectory($RetResultSet.SQLUSERDBLOGDIR)}	
		if(!(test-path $RetResultSet.SQLTEMPDBDIR)){[IO.Directory]::CreateDirectory($RetResultSet.SQLTEMPDBDIR)}	
		if(!(test-path $RetResultSet.SQLTEMPDBLOGDIR)){[IO.Directory]::CreateDirectory($RetResultSet.SQLTEMPDBLOGDIR)}	

        #If SQL 2012 or 2014 than use update source
        if (($SQLVersion -eq "SQL2014")	-or 	($SQLVersion -eq "SQL2012")	)
        {
		        if(!(test-path $RetResultSet.CLTRESULTDIR)){[IO.Directory]::CreateDirectory($RetResultSet.CLTRESULTDIR)}	
		        if(!(test-path $RetResultSet.CLTWORKINGDIR)){[IO.Directory]::CreateDirectory($RetResultSet.CLTWORKINGDIR)}	
		        if(!(test-path $RetResultSet.FilestreamFolder)){[IO.Directory]::CreateDirectory($RetResultSet.FilestreamFolder)}	
        }	
		if(!(test-path $RetResultSet.SQLBinaries)){ write-host "SQL Binaries location is not accesible:" $RetResultSet.SQLBinaries}
	}


	Catch
	{
		Write-Host "Error! while creating folders" -foregroundcolor "magenta" `n
	}


	try
	{
		if(!(
			(test-path $RetResultSet.SQLBinaries) `
			-and (test-path $RetResultSet.SQLBACKUPDIR) `
			-and (test-path $RetResultSet.SQLUSERDBDIR)`
			-and (test-path $RetResultSet.SQLUSERDBLOGDIR)`
			-and (test-path $RetResultSet.SQLTEMPDBDIR)`
			-and (test-path $RetResultSet.SQLTEMPDBLOGDIR)`
			-and (test-path $RetResultSet.SQLBinaries)
			))
			{
				Write-Host "Folder did not get created sucessfully" -foregroundcolor "magenta"
				if(!(test-path $RetResultSet.INSTANCEDIR)){write-host "INSTANCEDIR folder does not exist " $RetResultSet.INSTANCEDIR `n}
				if(!(test-path $RetResultSet.SQLBACKUPDIR)){write-host "SQLBACKUPDIR folder does not exist " $RetResultSet.SQLBACKUPDIR`n}
				if(!(test-path $RetResultSet.SQLUSERDBDIR)){write-host "SQLUSERDBDIR folder does not exist " $RetResultSet.SQLUSERDBDIR`n}
				if(!(test-path $RetResultSet.SQLUSERDBLOGDIR)){write-host "SQLUSERDBLOGDIR folder does not exist " $RetResultSet.SQLUSERDBLOGDIR`n}
				if(!(test-path $RetResultSet.SQLTEMPDBDIR)){write-host "SQLTEMPDBDIR folder does not exist " $RetResultSet.SQLTEMPDBDIR`n}
				if(!(test-path $RetResultSet.SQLTEMPDBLOGDIR)){write-host "SQLTEMPDBLOGDIR folder does not exist " $RetResultSet.SQLTEMPDBLOGDIR`n}
				if(!(test-path $RetResultSet.SQLBinaries)){write-host "SQLBinaries folder does not exist " $RetResultSet.SQLBinaries`n}
				exit
			}
	    else
	        {
				write-host -ForegroundColor Magenta "All required folder sucessfully created" `n
	        }
	}
	Catch
	{
		Write-Host "Error! while checking folder created successfully" -foregroundcolor "magenta" `n

	}



	fnGrantSQLStartupAccountsRights $SQLStartupAccount
    fnGrantSQLStartupAccountsRights $SQLSYSADMINACCOUNTS

# for SQL 2008 update sqlsupport from latest hotfix separately

if ($RetResultSet.SP) {	$SQLSPDIR =join-path -path $SQLBinariesLocation -childpath  $RsToInstallRet.SP}
if ($RetResultSet.CU) {	$SQLCUDIR =join-path -path $SQLBinariesLocation -childpath  $RsToInstallRet.CU}

if ($SQLVersion -eq "SQL2008")
{
if ($RetResultSet.CU) 
    {	$sqlsupportPath =join-path -path $SQLCUDIR -childpath  "\x64\setup\1033\sqlsupport.msi"}
else
    {	$sqlsupportPath =join-path -path $SQLSPDIR -childpath  "\x64\setup\1033\sqlsupport.msi"}

    $sqlsupportPath  += " /quiet /norestart"
    $sqlsupportPath  
    Invoke-Expression $sqlsupportPath   
    Start-Sleep -s 120
}	


	
	$SQLBACKUPDIR =$RetResultSet.SQLBACKUPDIR
	$SQLUSERDBLOGDIR =$RetResultSet.SQLUSERDBLOGDIR
	$SQLTEMPDBLOGDIR =$RetResultSet.SQLTEMPDBLOGDIR
	$SQLUSERDBDIR =$RetResultSet.SQLUSERDBDIR
	$SQLTEMPDBDIR =$RetResultSet.SQLTEMPDBDIR
	$INSTANCEDIR =$RetResultSet.INSTANCEDIR
	$SAPWD=$SQLSAPassword
	$SQLBinaries=$RetResultSet.SQLBinaries
	$SQLFEATURES=$RetResultSet.SQLComponents
    $SQLCollation=$RetResultSet.SQLCollation


    $message = "
	SQL Instalation ready to proceed please confirm below details: `n
    Product:  $Product
    Env Template:  $RsToInstallRet.EnvTemplate `n
	All folders created, sql user account has granted necessary access  `n
	Server Name: $DBSERVER
	Total CPU: $NOfLogicalCPU
	Total Physical memory: $HostPhysicalMemoryGB MB `n
	Max Min Memory: $SQLMaxMinMemoryGB
	SQL Binaries Location=$SQLBinaries `n
	SQL SP DIR=$SQLSPDIR `n
	SQL CU DIR=$SQLCUDIR `n
	SQLStartupAccount: $SQLStartupAccount `n
	SQL SYS ADMIN ACCOUNTS/ Installation account = $installationAccount
	FEATURES: $SQLFEATURES
	INSTANCE DIR=$INSTANCEDIR
	SQL BACKUP DIR=$SQLBACKUPDIR
	SQL USER DB DIR=$SQLUSERDBDIR
	SQL USER DB LOG DIR=$SQLUSERDBLOGDIR
	SQL TEMP DB DIR=$SQLTEMPDBDIR
	SQL TEMPDB LOG DIR=$SQLTEMPDBLOGDIR
	"    
	write-host $message 


		
		$INSTANCENAME = $RetResultSet.INSTANCENAME
		# Build string with command-line arguments for SQL Server installer 
		$arguments = " /SECURITYMODE=SQL /FILESTREAMLEVEL=3 /FILESTREAMSHARENAME=AdvCloudFS" 
		$arguments += "   /QUIET=True /ACTION=install "
		$arguments += "  /INSTANCENAME=$INSTANCENAME /INDICATEPROGRESS=True " 
		$arguments += " /SQLSVCACCOUNT=`"$SQLStartupAccount`"" 
		$arguments += " /SQLSVCACCOUNT=`"$SQLStartupAccount`"" 
		$arguments += " /RSSVCACCOUNT=`"$SQLStartupAccount`"" 
		$arguments += " /AGTSVCACCOUNT=`"$SQLStartupAccount`"" 
		$arguments += " /ISSVCACCOUNT=`"$SQLStartupAccount`"" 
		$arguments += " /AGTSVCSTARTUPTYPE=Automatic "

#If SQL 2012 or 2014 than use update source
if ((($SQLVersion -eq "SQL2014")	-or 	($SQLVersion -eq "SQL2012")	-or 	($SQLVersion -eq "SQL2016")	) -and ($SQLCUDIR.Length -ne 0 ))
{
		$arguments += "  /UPDATESOURCE= $SQLCUDIR"  
		$arguments += "  /UpdateEnabled=True" 

}		
elseif ((($SQLVersion -eq "SQL2014")	-or 	($SQLVersion -eq "SQL2012")	-or 	($SQLVersion -eq "SQL2016")	) -and ($SQLCUDIR.Length -eq 0 ))
{
        $arguments += "  /UpdateEnabled=false" 
}


if ($SQLVersion -ne "SQL2008")
{
		$arguments += "   /IACCEPTSQLSERVERLICENSETERMS " 
}		


#If SQL 2008R2 than use CUSOURCE and PCUSOURCE for CU and SP updates
if (($SQLVersion -eq "SQL2008R2") -or ($SQLVersion -eq "SQL2008"))
{
        if($SQLCUDIR.length -ne 0)
        {
            $arguments += " /CUSOURCE=`"$SQLCUDIR`"" 
        }

        if($SQLSPDIR.length -ne 0)
        {
		        $arguments += " /PCUSOURCE=`"$SQLSPDIR`"" 
        }
}		



		
		$arguments += " /SQLSYSADMINACCOUNTS=`"$installationAccount`"" 
		$arguments += " /INSTANCEDIR=`"$INSTANCEDIR`"" 
		$arguments += " /SQLBACKUPDIR=`"$SQLBACKUPDIR`"" 
		$arguments += " /SQLUSERDBLOGDIR=`"$SQLUSERDBLOGDIR`"" 
		$arguments += " /SQLTEMPDBLOGDIR=`"$SQLTEMPDBLOGDIR`"" 
		$arguments += " /SQLUSERDBDIR=`"$SQLUSERDBDIR`"" 
		$arguments += " /SQLTEMPDBDIR=`"$SQLTEMPDBDIR`"" 
		$arguments += " /FEATURES=`"$SQLFEATURES`"" 


		if (($SQLCollation | measure).count -ne 0)
        {
		$arguments += " /SQLCOLLATION=`"$SQLCollation`"" 
        }

		$cmd = "./Setup.exe "
		$cmd += $arguments

		write-host "Command before adding passowrds...: " $cmd `n `n
        Start-Sleep -S 1

		$Passwords = " /SQLSVCPASSWORD=`"$SQLStartupAccountPassword`"" 
		$Passwords += " /RSSVCPASSWORD=`"$SQLStartupAccountPassword`"" 
		$Passwords += " /AGTSVCPASSWORD=`"$SQLStartupAccountPassword`"" 
		$Passwords += " /ISSVCPASSWORD=`"$SQLStartupAccountPassword`"" 
		$Passwords += " /SAPWD=`"$SAPassword`"" 
        if (!((($SQLLicense| measure).count -eq 0) -or  ($SQLLicense -eq ""))) {$Passwords += "  /PID=$SQLLicense  "}

		
		$cmd += $Passwords
	    set-location $RetResultSet.SQLBinaries  -PassThru 
        #$cmd

#Initiating SQL Install
	    Invoke-Expression $cmd
		
	    set-location $ScriptDir -PassThru 

    if ($Product -ne "SSRS")
    {
	    $service = Get-WmiObject -Class Win32_Service -Filter "Name='MSSQLSERVER'"
    }
    else 
    {
	    $service = Get-WmiObject -Class Win32_Service -Filter "Name='ReportServer'"
    }


	    if (!($service.Name))
	    {
            Write-Host "SQL Service not found" -foregroundcolor "magenta"
            # Get setup failure message from summary.txt file
            switch ($SQLVersion) 
                { 
                    "SQL2016" {[string]$SQLVerNo="130"} 
                    "SQL2014" {[string]$SQLVerNo="120"} 
                    "SQL2012" {[string]$SQLVerNo="110"} 
                    "SQL2008R2" {[string]$SQLVerNo="100"} 
                    "SQL2008" {[string]$SQLVerNo="100"} 
                    default {[string]$SQLVerNo="90"}
                }

            #$SQLInstallationSummary="$env:programfiles\Microsoft SQL Server\$SQLVerNo\Setup Bootstrap\Log\20150402_145238\Summary*.txt"
            $SQLInstallationSummary="$env:programfiles\Microsoft SQL Server\$SQLVerNo\Setup Bootstrap\Log\Summary.txt"

            if(!(test-path $SQLInstallationSummary)) {write-host -ForegroundColor Red "Summary file does not exists, setup failed for some basic reason, pleaes check this file location $SQLInstallationSummary"; exit}


            $SQLSetupErrorMessage=gc $SQLInstallationSummary | ? { ($_ | Select-String "Exit message:")}  
            if ($SQLSetupErrorMessage) {write-host ($SQLSetupErrorMessage.Replace("Exit message:","") + "`n `n" + "For detiled error message check `n$SQLInstallationSummary`n") -foregroundcolor "magenta"; exit}
            else {write-host "Could not find SQL setup summary log file" -foregroundcolor "magenta"}
        }
	    else
	    {Write-Host "SQL Service found, installation completed" -foregroundcolor "magenta"}

}

# refresh env variables so SQL module can be loaded
 fnRefreshEnvvariables 

# Configuring post SQL settings
if ($service.Name)
{
    if(fnLoadSQLPSModule)
    {
	    try
	    {
		    write-host "Printing Yes GetInstallRetValue=1, starting sql post configuration"
		    fnConfigSqlMinMaxMemory  -DBServer $DBSERVER  -DatabaseName "master" -MinMem $SQLMaxMinMemoryGB -MaxMem $SQLMaxMinMemoryGB
		    fnCreateLoginGrantRole	-DBServer $DBSERVER -LoginName $SQLStartupAccount -ServerRole "sysadmin"
		    fnCreateLoginGrantRole	-DBServer $DBSERVER -LoginName $SQLSYSADMINACCOUNTS -ServerRole "sysadmin"
		    fnAddTempFiles -DBSERVER $DBSERVER -CPUCount $NOfLogicalCPU -SQLTEMPDBDataDIR "$SQLTEMPDBDIR"
		    fnEnableCompression -DBSERVER $DBSERVER 
            setspn.exe -A ("MSSQLSvc/" + $DBSERVER + "." + $env:userdnsdomain  + ":1433") $SQLStartupAccount
	    }
	    catch
	    {
		    Write-Host "SQL post configuration steps failed:" -foregroundcolor "magenta"`n `n
	    }
    }
    else
    {
	    Write-error "SQL module not found, sql installation failed, please check logs..."
    }

#Installing DotNet4 if configured in install xml
    if (($DotNet4Location|measure).count -ne 0)
    {

		    Try
		    {
			    
                if ([System.Version](Get-WmiObject win32_operatingsystem).version -lt  [System.Version]"6.2.9100")
                {
                    $cmdDotNet4 = $DotNet4Location + "\dotNetFx40_Full_x86_x64 /passive /norestart"
			        write-host "Installing DotNet 4:  $cmdDotNet4 " `n `n
		            set-location $RetResultSet.DotNet4Location  -PassThru 
		            Invoke-Expression $cmdDotNet4
		            set-location $ScriptDir -PassThru 
                }                    
		    }
		    Catch
		    {
			    write-host "Installation DotNet 4 failed:  $cmdDotNet4 " `n `n
			    write-host "Please do manual installation " `n `n
		    }

    }


#Installing windows updates to ensure windows has all latest patches
    try
    {
	    write-host "starting windows updates"
        install-update			
    }
    catch
    {
	    Write-Host "starting windows updates steps failed:" -foregroundcolor "magenta"`n `n
    }

}