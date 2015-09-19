cls
$installfilepath="F:\SQLSetup\Demo\InstallSQL\InstallSQL.xml"

$SQLPID="F:\SQLSetup\SQLPID.xml"

$InstallSQLMasterLoaded = Import-CliXML  $installfilepath

$RsToInstallRet=$InstallSQLMasterLoaded 

$RsToInstallRet | select Product,SQLVersion,SQLBinaries,CU

