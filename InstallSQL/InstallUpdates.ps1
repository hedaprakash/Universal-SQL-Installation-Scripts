# --- INSTALL-UPDATE --- #
function install-update {
    $session = New-Object -ComObject Microsoft.Update.Session
    $searcher = $session.CreateUpdateSearcher()

    $result = $searcher.Search("IsInstalled=0 and Type='Software' and ISHidden=0")
    
    if ($result.Updates.Count -eq 0) {
         Write-Host "No updates to install"
         return 1
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

install-update