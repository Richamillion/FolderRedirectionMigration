# Step 1
Import-Module ActiveDirectory
while ($true) {
    Write-Host "Folder Redirection Step 1!"
    # Prompt for AD username
    do {
        $fdUserName = Read-Host "Enter the AD username (type 'exit' or use 'Ctrl-C' to quit)"
        if ($fdUserName -eq "exit") {
            Write-Host "Exiting script." -ForegroundColor Magenta
            break 2  # Exit the outer while loop
        }
        try {
            $fdUser = Get-ADUser -Identity $fdUserName -Properties HomeDirectory
            $validUser = $true
        } catch {
            Write-Host "User '$fdUserName' not found in AD. Please try again." -ForegroundColor Yellow
            $validUser = $false
        }
    } until ($validUser)

    # Define group
    $groupName = "FolderRedirectionUsers"
    # Check if user is already a member
    $isMember = Get-ADGroupMember -Identity $groupName | Where-Object { $_.SamAccountName -eq $fdUser.SamAccountName }
    # Remove user from legacy DEM groups
    $legacyGroups = @("legacyGroup2", "legacyGroup1")

    if ($isMember) {
        Write-Host "$fdUserName is already a member of $groupName. Checking groups and Home Directory..." -ForegroundColor Green
        # Check legacy DEM groups
        foreach ($group in $legacyGroups) {
            try {
                $isInGroup = Get-ADGroupMember -Identity $group | Where-Object { $_.SamAccountName -eq $fdUser.SamAccountName }
                if ($isInGroup) {
                    Remove-ADGroupMember -Identity $group -Members $fdUser.SamAccountName -Confirm:$false
                    Write-Host "Removed $fdUserName from $group." -ForegroundColor Green
                } else {
                    Write-Host "$fdUserName is not a member of $group. No action needed." -ForegroundColor Green
                }
            } catch {
                Write-Host "Error checking or removing $fdUserName from $group : $_" -ForegroundColor Red
            }
        }
        # Check home directory
        if ($null -ne $fdUser.HomeDirectory) {
            try {
                Set-ADUser -Identity $fdUser.SamAccountName -HomeDirectory $null
                Write-Host "Cleared HomeDirectory for $fdUserName." -ForegroundColor Green
            } catch {
                Write-Host "Failed to clear user's HomeDirectory: $_" -ForegroundColor Red
            }
        } else {
            Write-Host "HomeDirectory is already cleared!" -ForegroundColor Green
        }
    } else {
        # Add user to FolderRedirectionUsers group
        try {
            Add-ADGroupMember -Identity $groupName -Members $fdUser.SamAccountName
            Write-Host "Added $fdUserName to $groupName group." -ForegroundColor Green
        } catch {
            Write-Host "Failed to add user to group: $_" -ForegroundColor Red
        }
        # Check legacy DEM groups
        foreach ($group in $legacyGroups) {
            try {
                $isInGroup = Get-ADGroupMember -Identity $group | Where-Object { $_.SamAccountName -eq $fdUser.SamAccountName }
                if ($isInGroup) {
                    Remove-ADGroupMember -Identity $group -Members $fdUser.SamAccountName -Confirm:$false
                    Write-Host "Removed $fdUserName from $group." -ForegroundColor Green
                } else {
                    Write-Host "$fdUserName is not a member of $group. No action needed." -ForegroundColor Green
                }
            } catch {
                Write-Host "Error checking or removing $fdUserName from $group : $_" -ForegroundColor Red
            }
        }
        # Check home directory
        if ($null -ne $fdUser.HomeDirectory) {
            try {
                Set-ADUser -Identity $fdUser.SamAccountName -HomeDirectory $null
                Write-Host "Cleared HomeDirectory for $fdUserName." -ForegroundColor Green
            } catch {
                Write-Host "Failed to clear user's HomeDirectory: $_" -ForegroundColor Red
            }
        } else {
            Write-Host "HomeDirectory is already cleared!" -ForegroundColor Green
        }
    }

    # Get all connected smb sessions
    $userWorkstations = @()
    try {
        $Sessions = net session
    } catch {
        Write-Host "Failed to query connected sessions on this server: $_" -ForegroundColor Red
        return
    }

    # Get matching sessions for user and grab workstation names
    if ($Sessions) {
        foreach ($Session in $Sessions) {
                if ($Session -match $fdUserName) {
                    $workstation = ($Session -split '\s+')[0] -replace '^\\\\', ''
                    $userWorkstations += $workstation 
                }
        }
    }

    # List matching workstation names
    if ($userWorkstations.Count -gt 0) {
        $uniqueWorkstations = $userWorkstations | Sort-Object -Unique
        $wsList = $uniqueWorkstations -join ", "
        Write-Host "$fdUserName is connected on the following workstations: $wsList" -ForegroundColor Green
        # Prompt for reboot
        $reboot = Read-Host "Do you want to reboot $wsList now? (Y/N)"
        if ($reboot -match '^[Yy]$') {
            foreach ($targetWS in $uniqueWorkstations) {
                try{
                    Write-Host "Rebooting $targetWS..." -ForegroundColor Green
                    shutdown.exe -m $targetWS -r
                    Write-Host "Step 1 complete. Please continue with Step 2 by running step2.ps1 when the user is logged back into the computer." -ForegroundColor Magenta
                } catch {
                    Write-Host "Unable to send reboot commands to $targetWS : $_" -ForegroundColor Red
                }
            }
        } else {
            Write-Host "Reboot cancelled." -ForegroundColor Yellow
        }
    } else {
        Write-Host "$fdUserName is not connected to any shares on this server, manual reboot required." -ForegroundColor Yellow
    }

    Write-Host "Script is ready for next user, reloading..."
}
