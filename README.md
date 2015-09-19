# Universal SQL Installation
SQL Server Universal Instalation Scripts

Presentation link: http://sqlfeatures.com/2015/09/17/305/

Supported configurations:

• Infrastructure:
	Amazon AWS EC2/
	Windows Azure/
	VMware/
	Hyper-V/
	Physical servers

• OS Versions: 
	Windows 2008 R2/
	Windows 2012/
	Windows 2012 R2

• SQL Version
	SQL Server 2008 R2/
	SQL Server 2012/
	SQL Server 2014/
	SQL Server 2016

• SQL Editions
	Standard/
	Enterprise/
	Developer

• Any combination of SQL server service pack and cumulative updates with Hot fixes



Pre-Requisite: VM configuration

	•W2012/R2 standard
	
	•E drive with 50GB (install sql here)
	
	•F drive 20GB  (Filestream, optional to create if product required)
	
	•UAC disabled
	
	•Update patches
	
	•Added to domain
	
	•Grant PowerShell unrestricted and bypass execution rights
	
	•Disable automatic patch update



SQL Server installation steps

Note: User account which initiate installation should be local admin for standalone installations, domain admin for Cluster and AlwaysON configuration
1.Run powershell as administrator
2.Execute below command

Command: powershell <Fileshare>\InstallSQL.ps1 

Parameter 1: <SQL Service startup account> #sqlfeatures\svcSQLfeatures

Parameter 2: <SQL Service startup account Password> #qqqEqq1! <<Minimum 8 digit toupgh password>>

Parameter 3: <SA Password> #SAtemp2014

Parameter 4: <Product Code> #AMD_2015

Parameter 5: <SQL Sysadmin group> #sqlfeatures\sqldba (group responsible for support)

Example: \\<fileshare>\Scripts\InstallSQL\InstallSQL.ps1 sqlfeatures\svcSQLfeatures Tester1! SAtemp2014 SQL_2008_STD sqlfeatures\sqldba
