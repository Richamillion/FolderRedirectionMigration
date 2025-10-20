# Step 2
Import-Module ActiveDirectory

while ($true) {
    Write-Host "Folder Redirection Step 2!"

    # Prompt for AD username
    do {
        $fdUserName = Read-Host "Enter the AD username (type 'exit' or use 'Ctrl-C' to quit)"
        if ($fdUserName -eq "exit") {
            Write-Host "Exiting script." -ForegroundColor Magenta
            break 2
        }
        try {
            $fdUser = Get-ADUser -Identity $fdUserName -Properties HomeDirectory
            $validUser = $true
        } catch {
            Write-Host "User '$fdUserName' not found in AD. Please try again." -ForegroundColor Yellow
            $validUser = $false
        }
    } until ($validUser)

    $sourcePath = "path1\$fdUserName"
    $destPath   = "path2\$fdUserName"


    # Check local path exists
    if (-not (Test-Path $sourcePath)) {
        Write-Host "Local path '$sourcePath' does not exist. Please verify the home directory files/folders for $fdUserName exist." -ForegroundColor Red
        continue
    }

    # Check if folder redirection destination path exists
    if (-not (Test-Path $destPath)) {
        Write-Host "Destination path '$destPath' does not exist. Please verify $fdUserName has logged into a computer after successfully running Step 1." -ForegroundColor Red
        continue
    }

      # Prompt to confirm migration
    $copy = Read-Host "All paths exist. Proceed with file migration for $fdUserName? (Y/N)"
    if ($copy -notmatch '^[Yy]$') {
        Write-Host "Robocopy cancelled for $fdUserName." -ForegroundColor Yellow
        continue
    }

    # Define Robocopy options
    $robocopyOptions = @("/S", "/COPY:DATSOU", "/R:3", "/W:5", "/XO", "/XN")
    $folders = @("Desktop", "Documents", "Downloads")
    $success = $true

    # Migrate key folders
    foreach ($folder in $folders) {
        $src = Join-Path $sourcePath $folder
        $dst = Join-Path $destPath $folder

        if (Test-Path $src ) {
            if (Test-Path $dst) {
                Robocopy $src $dst $robocopyOptions
                if ($LASTEXITCODE -gt 3) {
                    Write-Host "Robocopy failed for $fdUserName\$folder. Exit code: $LASTEXITCODE" -ForegroundColor Red
                    $success = $false
                }
            } else {
                Write-Host "Destination folder '$dst' not found. Skipping $folder." -ForegroundColor Yellow
            }
        } else {
            Write-Host "Source folder '$src' not found. Skipping $folder." -ForegroundColor Yellow
        }
    }

    # Migrate everything else (excluding Desktop, Documents, Downloads)
    Robocopy $sourcePath "$destPath\Documents" $robocopyOptions /XD `
        "$sourcePath\Desktop" `
        "$sourcePath\Documents" `
        "$sourcePath\Downloads" `
        "$sourcePath\Profile.V6"

    if ($LASTEXITCODE -gt 3) {
        Write-Host "Robocopy failed for remaining files. Exit code: $LASTEXITCODE" -ForegroundColor Red
        $success = $false
    }

    # Final status
    if ($success) {
        Write-Host "Migration completed successfully for $fdUserName." -ForegroundColor Green
    } else {
        Write-Host "Migration completed with errors for $fdUserName." -ForegroundColor Yellow
    }

    Write-Host "Script ready for next user, reloading..."
}
