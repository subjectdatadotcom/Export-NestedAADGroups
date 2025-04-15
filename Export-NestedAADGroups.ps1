<#
.SYNOPSIS
Retrieves detailed nested Azure AD security group hierarchy, including members and owners, for a list of specified groups—now supporting both security and mail-enabled security groups.

.DESCRIPTION
This script connects to Azure AD and reads a list of unique security group GUIDs from a CSV file. It recursively inventories each group's members and owners, including nested groups. The script identifies group types (Security, Mail-enabled Security, Microsoft 365 Groups, etc.), captures member and ownership hierarchies, and outputs the full structure with nesting levels and relationships.

As of the latest update, recursion includes both standard Security Groups and Mail-enabled Security Groups to reflect real-world group nesting scenarios more accurately. Microsoft 365 Groups and Distribution Lists are reported but not expanded.

The script handles module setup, error management, and disconnection, while producing a detailed CSV for auditing or migration prep.

.EXAMPLE
.\Export-NestedAADGroups.ps1

Reads `UniqueSecurityGroupGUIDs.csv` from the script directory and writes a full nested group inventory report to `Nested_AD_Groups_Details.csv`.

.NOTES
Author: SubjectData  
Required Modules: AzureAD, AzureAD.Standard.Preview (for full compatibility)  
Scope: Azure AD / Entra ID  
Last Updated: 2025-04-09  
#>



# Azure AD Nested Security Group Inventory Script

$startTime = Get-Date
Write-Host "Script started at: $startTime"

# Module setup
$AzureADModule = "AzureAD"
if (-not(Get-Module -Name $AzureADModule -ListAvailable)) {
    Install-Module -Name $AzureADModule -Force
}
Import-Module $AzureADModule -Force

# Connect to Azure AD
$null = Connect-AzureAD

# Input CSV file containing unique group GUIDs
$myDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$XLloc = "$myDir\"
$inputCsv = Join-Path $XLloc "UniqueSecurityGroupGUIDs.csv"
$outputCsv = Join-Path $XLloc "Nested_AD_Groups_Details.csv"

$UniqueGroupsData = Import-Csv -Path $inputCsv

function Expand-GroupHierarchy {
    param (
        [string]$GroupId,
        [int]$Level = 1,
        [string]$ParentGUID = ""
    )

    $results = @()

    try {
        $group = Get-AzureADGroup -ObjectId $GroupId
        if (-not $group) { return }

        # Get group type
        $groupTypeInfo = Get-AzureADMSGroup -Id $GroupId
        $groupType = if ($groupTypeInfo.GroupTypes -contains "Unified") {
            if ($groupTypeInfo.MailEnabled) { "Microsoft 365 Group" } else { "Mail-enabled Microsoft 365 Group" }
        } elseif ($groupTypeInfo.MailEnabled -and $groupTypeInfo.SecurityEnabled) {
            "Mail-enabled Security Group"
        } elseif ($groupTypeInfo.SecurityEnabled) {
            "Security Group"
        } elseif ($groupTypeInfo.MailEnabled) {
            "Distribution List"
        } else {
            "Unknown"
        }

        # Get members & owners
        $membersRaw = Get-AzureADGroupMember -ObjectId $GroupId -All $true
        $ownersRaw  = Get-AzureADGroupOwner -ObjectId $GroupId -All $true

        # Separate users and nested groups
        $userMembers = $membersRaw | Where-Object { $_.ObjectType -eq "User" }
        $nestedGroups = $membersRaw | Where-Object { $_.ObjectType -eq "Group" }

        $userOwners = $ownersRaw | Where-Object { $_.ObjectType -eq "User" }
        $groupOwners = $ownersRaw | Where-Object { $_.ObjectType -eq "Group" }

        # Current group summary row
        $groupInfo = [PSCustomObject]@{
            Level         = $Level
            MembersCount  = $userMembers.Count
            GroupGUID     = $GroupId
            ParentGUID    = $ParentGUID
            Owners        = ($userOwners | Select-Object -ExpandProperty UserPrincipalName) -join "; "
            GroupName     = $group.DisplayName
            GroupType     = $groupType
            Members       = ($userMembers | Select-Object -ExpandProperty UserPrincipalName) -join "; "
            OwnersCount   = $userOwners.Count
        }
        $groupInfo | Add-Member -MemberType NoteProperty -Name "MembershipType" -Value "" -Force


        $results += $groupInfo

        # Recurse if Security Group
        if ($groupType -in @("Security Group", "Mail-enabled Security Group"))  {
        # if ($groupType -eq "Security Group") {
            foreach ($nestedGroup in $nestedGroups) {
                $nestedResult = Expand-GroupHierarchy -GroupId $nestedGroup.ObjectId -Level ($Level + 1) -ParentGUID $GroupId
                foreach ($r in $nestedResult) {
                    if (-not $r.PSObject.Properties["MembershipType"]) {
                        $r | Add-Member -MemberType NoteProperty -Name "MembershipType" -Value "Member"
                    } else {
                        $r.MembershipType = "Member"
                    }
                }
                $results += $nestedResult
            }


            foreach ($groupOwner in $groupOwners) {
                $nestedResult = Expand-GroupHierarchy -GroupId $groupOwner.ObjectId -Level ($Level + 1) -ParentGUID $GroupId
                foreach ($r in $nestedResult) {
                    if (-not $r.PSObject.Properties["MembershipType"]) {
                        $r | Add-Member -MemberType NoteProperty -Name "MembershipType" -Value "Owner"
                    } else {
                        $r.MembershipType = "Owner"
                    }
                }
                $results += $nestedResult
            }

        }

        <#
        # Recurse if Security Group
        if ($groupType -eq "Security Group") {
            foreach ($nestedGroup in $nestedGroups) {
                $results += Expand-GroupHierarchy -GroupId $nestedGroup.ObjectId -Level ($Level + 1) -ParentGUID $GroupId
            }
            foreach ($groupOwner in $groupOwners) {
                $results += Expand-GroupHierarchy -GroupId $groupOwner.ObjectId -Level ($Level + 1) -ParentGUID $GroupId
            }
        }
        #>

    } catch {
        Write-Warning "Error expanding group $GroupId"
    }

    return $results
}

$GroupDetails = @()

foreach ($GroupGuid in $UniqueGroupsData) {
    try {
        Write-Host "Expanding group $($GroupGuid.GroupGUID)..." -ForegroundColor Cyan
        $expanded = Expand-GroupHierarchy -GroupId $GroupGuid.GroupGUID -Level 1 -ParentGUID ""
        if ($expanded -and ($expanded -is [System.Collections.IEnumerable]) -and ($expanded.Count -gt 0)) {
            $GroupDetails += $expanded
        }
        elseif ($expanded -and ($expanded -isnot [System.Collections.IEnumerable])) {
            $GroupDetails += ,$expanded  # Wrap single object in an array
        }
        else {
            Write-Warning "No data returned for $($GroupGuid.GroupName)"
        }
    } catch {
        Write-Warning "Failed to expand group $($GroupGuid.GroupGUID)"
    }
}

# Export results
$GroupDetails | Export-Csv -Path $outputCsv -NoTypeInformation

$endTime = Get-Date
Write-Host "Script ended at: $endTime"
Write-Host "Total execution time: $($endTime - $startTime)"

# Disconnect from AzureAD
Disconnect-AzureAD
