#
README - Azure AD Nested Security Group Inventory Script
=========================================================

Overview:
---------
This PowerShell script inventories nested Azure Active Directory (Azure AD / Entra ID) groups. It reads a list of group GUIDs from a CSV file and recursively expands group membership and ownership hierarchies for **Security Groups** and **Mail-enabled Security Groups** only. The output includes metadata like group names, UPNs, group types, nesting levels, and relationship types.

Features:
---------
- Connects to Azure AD using the AzureAD module
- Recursively expands members and owners for Security Groups and Mail-enabled Security Groups
- Classifies group types (e.g., Security Group, Mail-enabled)
- Captures member and owner UPNs with nesting depth
- Outputs results to a CSV for documentation or migration planning
- Automatically installs and imports required modules

Requirements:
-------------
- PowerShell 5.1 or PowerShell Core
- AzureAD module (`Install-Module AzureAD`)
- Azure AD permissions to read group and member info

Usage:
------
1. Create a CSV file named `UniqueSecurityGroupGUIDs.csv` in the script directory.
   It must have one column: `GroupGUID`

   Example:
   GroupGUID
   a1111111-1111-1111-1111-111111111111
   b2222222-2222-2222-2222-222222222222

2. Run the script:
   .\Export-NestedAADGroups.ps1

3. The output file `Nested_AD_Groups_Details.csv` will be created in the same folder.

Output Fields:
--------------
- Level:              Depth of the group within the hierarchy
- GroupGUID:          The Azure AD Object ID of the group
- ParentGUID:         The Object ID of the parent group (if nested)
- GroupName:          The display name of the group
- GroupType:          Type of the group (e.g., Security Group, Mail-enabled Security Group)
- MembersCount:       Number of direct user members
- Members:            Semicolon-separated list of user UPNs
- OwnersCount:        Number of direct user owners
- Owners:             Semicolon-separated list of owner UPNs
- MembershipType:     Indicates whether the group was included as a Member or Owner

Notes:
------
- Only **Security Groups** and **Mail-enabled Security Groups** are expanded recursively.
- Module `AzureAD` is installed and imported if not already present.
- Script disconnects from Azure AD after completion.

Author:
-------
SubjectData  
Last Updated: April 9, 2025
#>
