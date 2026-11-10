<#
.SYNOPSIS
    Creates Active Directory users in bulk from a CSV file.

.DESCRIPTION
    Reads users.csv, creates each user in the OU for their department
    (creating the OU if needed), skips users that already exist, and
    forces a password change at first logon. Results are logged to a file.

.EXAMPLE
    .\New-BulkADUsers.ps1 -CsvPath .\users.csv
#>

param(
    [Parameter(Mandatory)]
    [string]$CsvPath,

    [string]$LogPath = ".\BulkUserCreation_$(Get-Date -Format 'yyyyMMdd_HHmmss').log"
)

Import-Module ActiveDirectory

# Domain info pulled automatically so the script works in any lab domain
$Domain   = Get-ADDomain
$DomainDN = $Domain.DistinguishedName      # e.g. DC=lab,DC=local
$UPNSuffix = $Domain.DNSRoot               # e.g. lab.local

# Prompt for the initial password so it never gets saved in the script or CSV
$InitialPassword = Read-Host "Enter initial password for new users" -AsSecureString

function Write-Log {
    param([string]$Message)
    $line = "$(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')  $Message"
    Write-Host $line
    Add-Content -Path $LogPath -Value $line
}

$Users = Import-Csv -Path $CsvPath
$Created = 0; $Skipped = 0; $Failed = 0

foreach ($User in $Users) {
    # Username format: first initial + last name, lowercase (jsmith)
    $Username = ($User.FirstName.Substring(0,1) + $User.LastName).ToLower()
    $OUPath   = "OU=$($User.Department),$DomainDN"

    # Create the department OU if it doesn't exist yet
    if (-not (Get-ADOrganizationalUnit -Filter "DistinguishedName -eq '$OUPath'" -ErrorAction SilentlyContinue)) {
        New-ADOrganizationalUnit -Name $User.Department -Path $DomainDN -ProtectedFromAccidentalDeletion $true
        Write-Log "Created OU: $($User.Department)"
    }

    # Skip if the user already exists
    if (Get-ADUser -Filter "SamAccountName -eq '$Username'" -ErrorAction SilentlyContinue) {
        Write-Log "SKIPPED: $Username already exists"
        $Skipped++
        continue
    }

    try {
        New-ADUser `
            -Name              "$($User.FirstName) $($User.LastName)" `
            -GivenName         $User.FirstName `
            -Surname           $User.LastName `
            -SamAccountName    $Username `
            -UserPrincipalName "$Username@$UPNSuffix" `
            -Title             $User.Title `
            -Department        $User.Department `
            -Path              $OUPath `
            -AccountPassword   $InitialPassword `
            -ChangePasswordAtLogon $true `
            -Enabled           $true

        Write-Log "CREATED: $Username in $OUPath"
        $Created++
    }
    catch {
        Write-Log "FAILED: $Username - $($_.Exception.Message)"
        $Failed++
    }
}

Write-Log "Done. Created: $Created | Skipped: $Skipped | Failed: $Failed"
