<#PSScriptInfo

.TYPE Controller

.VERSION 1.0.1

.TEMPLATEVERSION 1

.PLATFORM 5.1

.GUID 97739678-0D5D-4F4E-A038-CD308F5A10E8

.AUTHOR Christoph Rust (External KrizKodez)

.CONTRIBUTORS

.COMPANYNAME KrizKodez

.TAGS
    Delegation
    Group Policy
    GPO

.EXTERNALMODULEDEPENDENCIES
    ActiveDirectory, Microsoft Module
    GroupPolicy, Microsoft Module

.REQUIREDSCRIPTS
 
.EXTERNALSCRIPTDEPENDENCIES
    ActiveDirectory, CN=Policies,CN=System,<Domain>, Descendant objects, Modify Permissions
    ActiveDirectory, CN=SOM,CN=WMIPolicy,CN=System,<Domain>, Descendant objects, Modify Owner

.REQUIREDBINARIES

.DESCRIPTION
    The script enumerates all GPOs and WMI filters and replaces creator/owner permission for a user account
    through a permission for the delegation group in which the user is a member.    

.RELEASENOTES
    2024-06-04, 0.1.0, Christoph Rust, Initial release
    2024-07-18, 1.0.0, Christoph Rust, Productive release
    2024-10-04, 1.0.1, Christoph Rust, Change of some code formattings.

#>

<#
.Synopsis
    Replace user account trustees through a defined delegation group trustee.        

.Description
    The script enumerates all GPOs and WMI filters and replaces permission for a user account through
    a permission for the delegation group in which the user is a member.

.Inputs
    System.String 
    The path of a JSON config file to be used.

    You cannot pipe input to this cmdlet.

.Outputs
    None

.Notes
    The script does not have a rich public interface because the main application
    is the usage with a scheduled task.
    It supports the -WhatIf switch to test which changes it would apply, the command line parameter
    has priority over the configuration file setting.

    The following parameters could be configured in the configuration JSON file:
        Whatif:     true | false   Decide if the script should write in the AD.
        Groups:     Array of hashtables with groups to be processed, Key is the SID and Value the samAccountName of the group.        
        LogPath:    Path of a directory to save the log data.
    
    In two cases an user account permission will not be replaced:
        + The user is not member of any of the defined delegation groups.
        + The user is member of more than one of the defined delegation groups.
    
.Example

.Link
    https://github.com/KrizKodez/DelegateGPOPermissions

.Parameter Configfile
    The path of the JSON config file to be used.
    By default the script searches a side-by-side file with the name 'Config.json'.

#>

# PARAMETERS
[CmdletBinding(SupportsShouldProcess)]
param ([string]$Configfile="Config.json")

# INCLUDE LIBRARIES
    # PRIVATE
    # NA

    # PUBLIC
    # NA

# PARAMETER CHECK
    # Build the Config object from the config file.
    $Content = Get-Content -Path $Configfile -Raw -ErrorAction Stop
    $Config  = ConvertFrom-Json -InputObject $Content -ErrorAction Stop
    # Ensure that the LogPath is existing.
    if (-not (Test-Path -Path $Config.LogPath -PathType Container)) { Write-Error -Message "LogPath ($($Config.LogPath)) not found." -ErrorAction Stop }

# PREREQUISITES 
Import-Module ActiveDirectory -ErrorAction Stop
Import-Module GroupPolicy -ErrorAction Stop

# DECLARATIONS AND DEFINITIONS
    # VARIABLES
    # Mapping of a user account to the group that replaces it.
    $DelegationGroupOf = @{} # Key is a user(samAccountName), Value is the delegation group(samAccoutName) which replaces the user.
    
    # Stores all users samAccountName which are a member of more than one of the defined delegation groups.
    # This users cannot be replaced. 
    $NotReplaceableUsers = @()

    # Collect the actual SID/samAccountName Key/Value pairs of the delegation groups configured in Config.json
    # We update at the end of the script the configuration date because the group names could have been changed.
    $GroupUpdates = @()

    # Mapping of the actual samAccountName of the delegation groups to its SID.
    $SidOfDelegationGroup = @{}
   
    # All log data.
    $Results = @()
    
    # Time and date for the log data.
    $Time  = Get-Date -Format 'HH:MM:ss'
    $Today = Get-Date -Format 'yyyyMMdd'

    $DomainDistinguishedName = (Get-ADDomain).DistinguishedName
    $DomainNetBIOSName       = (Get-ADDomain).NetBIOSName

    # CONSTANTS
    New-Variable -Name RUNTIME_LOG_NAME -Value DelegateGPOPermission -Option Constant -WhatIf:$false
    New-Variable -Name DN_WMI_FILTER_CONTAINER -Value "CN=SOM,CN=WMIPolicy,CN=System,$DomainDistinguishedName" -Option Constant -WhatIf:$false


# CONTROLLER MAIN CODE

# Set the WhatIfPreference from the Config file.
$WhatIfPreference = $Config.WhatIf

# Collect all users of all configured groups and check if users are member in multiple groups.
foreach ($Group in $Config.Groups) 
{
    $DelegationGroup  = Get-ADGroup -Identity $Group.SID -Property Members -ErrorAction Stop
    $GroupUpdates    += @{SID = $Group.SID; Name = $DelegationGroup.samAccountName}
    $SidOfDelegationGroup.Add($DelegationGroup.samAccountName,$Group.SID)
    
    foreach ($Member in $DelegationGroup.Members)
    {
        $User = Get-ADUser -Identity $Member | Select-Object -ExpandProperty samAccountName
        if ($DelegationGroupOf.ContainsKey($User))
        {
            $Results             += "Error: User ($User) is member of multiple delegation groups ($($DelegationGroupOf[$User]),$($DelegationGroup.samAccountName))."
            $NotReplaceableUsers += $User
        }
        else { $DelegationGroupOf.Add($User,$DelegationGroup.samAccountName) }
    }
}

# Process all GPOs.
$GPOs = Get-GPO -All -ErrorAction Stop
foreach ($GPO in $GPOs)
{
    # Collect all permitted user and group trustee names on this GPO.
    # The trustee name is the samAccountName only.
    $UserTrustees  = @()
    $GroupTrustees = @()
    $Permissions   = Get-GPPermission -Name $GPO.DisplayName -All
    foreach ($Permission in $Permissions)
    {
        switch ($Permission.Trustee.SIDType)
        {
            User  { $UserTrustees  += $Permission.Trustee.Name }
            Group { $GroupTrustees += $Permission.Trustee.Name }
        }
    }

    # Run through all users and try to replace the user with its delegation Group.
    foreach ($Trustee in $UserTrustees)
    {
        if (-not $DelegationGroupOf.ContainsKey($Trustee)) { continue }
        if ($NotReplaceableUsers -contains $Trustee) 
        {
            $Results = "${Time}:Error: User ($Trustee) could not delegate a Group on GPO ($($GPO.DisplayName)) because its membership is ambiguous."
            continue
        }

        # Delete the user permissions...
        if ($PSCmdlet.ShouldProcess($GPO.DisplayName,"Delete Trustee ($Trustee)"))
        {
            try
            { 
                $Parameters = @{
                                Name            = $GPO.DisplayName
                                TargetType      = "User"
                                TargetName      = $Trutee
                                PermissionLevel = "None"
                               }
                $null     = Set-GPPermission @Parameters -Replace -Whatif:$false -ErrorAction Stop
                $Results += "${Time}:INFO: Deleted Trustee ($Trustee) from GPO ($($GPO.DisplayName))."
            }
            catch { $Results += "${Time}:ERROR: Could not delete Trustee ($Trustee) from GPO ($($GPO.DisplayName)): $_." }
        }
        else { $Results += "${Time}:WHATIF: Delete Trustee ($Trustee) from GPO ($($GPO.DisplayName))." }

        # ...and replace it with its delegation group permissions.
        $DelegationGroup = $DelegationGroupOf[$Trustee]
        if ($GroupTrustees -contains $DelegationGroup) { continue }
        if ($PSCmdlet.ShouldProcess($GPO.DisplayName,"Set Trustee ($DelegationGroup)"))
        {
            try
            { 
                $Parameters = @{
                                Name            = $GPO.DisplayName
                                TargetType      = "Group"
                                TargetName      = $DelegationGroup
                                PermissionLevel = "GpoEditDeleteModifySecurity"
                               }
                $null     = Set-GPPermission @Parameters -Whatif:$false -ErrorAction Stop
                $Results += "${Time}:INFO: Set Trustee ($DelegationGroup) on GPO ($($GPO.DisplayName))."
            }
            catch { $Results += "${Time}:ERROR: Could not set Trustee ($DelegationGroup): $_." }
        }
        else { $Results += "${Time}:WHATIF: Set Trustee ($DelegationGroup) on GPO ($($GPO.DisplayName))." }

    }# End of foreach all Trustees.
    
}# End of foreach all GPOs.


# Now we process all WMI-Filter.
# In the case of WMI-Filters we are replacing the owner of the object because the GPO module does not support WMI-Filters
# and all WMI-Filters inherit the CREATOR OWNER permissions.
$WMIFilters = Get-ADObject -Filter {objectClass -eq 'msWMI-Som'} -SearchBase $DN_WMI_FILTER_CONTAINER -Properties msWMI-Author,msWMI-Name -ErrorAction Stop
foreach ($WMIFilter in $WMIFilters)
{
    $ACL = Get-Acl -Path "AD:$($WMIFilter.DistinguishedName)"
    
    # Get the actual owner of the WMI-Filter...
    $CurrentOwner = $ACL.Owner -replace "$DomainNetBIOSName\\",''
        
    # ...and check if the current owner...
    if ($DelegationGroupOf.Values -contains $CurrentOwner)  { continue }    # ...is already a delegation group,...
    if (-not $DelegationGroupOf.ContainsKey($CurrentOwner)) { continue }    # ...should not be replaced,...
    if ($NotReplaceableUsers -contains $CurrentOwner)                       # ...or cannot be replaced with a delegation group.
    {
        $Results = "${Time}:Error: User ($CurentOwner) could delegate a group on WMI-Filter ($($WMIFilter.'msWMI-Name')) because its membership is ambiguous."
        continue
    }

    # Change owner on the WMI Filter to delegation group.
    if ($PSCmdlet.ShouldProcess($WMIFilter.'msWMI-Name',"Change Owner."))
    {
        try
        { 
            $NewOwner = Get-ADGroup -Identity $DelegationGroupOf[$CurrentOwner] -ErrorAction Stop
            $ACL.SetOwner($NewOwner.SID)
            Set-ACL -Path "AD:$($WMIFilter.DistinguishedName)" -AclObject $ACL -Whatif:$false -ErrorAction Stop
            $Results += "${Time}:INFO: Replace owner ($CurrentOwner) by ($($DelegationGroupOf[$CurrentOwner])) on WMI-Filter ($($WMIFilter.'msWMI-Name'))."
        }
        catch
        {
            $Results += "${Time}:ERROR: Could not replace owner ($CurrentOwner) on WMI-Filter ($($WMIFilter.'msWMI-Name')): $_."
            continue
        }
    }
    else { $Results += "${Time}:WHATIF: Replaced owner ($CurrentOwner) by ($($DelegationGroupOf[$CurrentOwner])) on WMI-Filter ($($WMIFilter.'msWMI-Name'))." }
   
}# End of foreach all WMI Filter.


# Update the group names in the configuration file.
$Config.Groups = $GroupUpdates
$Config | ConvertTo-Json -Depth 10 | Out-File -FilePath $Configfile -WhatIf:$false

# Write the log if needed.
if ($Config.LogPath -and $Results)
{ $Results | Out-File -FilePath "$($Config.LogPath)\${RUNTIME_LOG_NAME}_$Today.txt" -Append -WhatIf:$false }

# END MAIN CODE

# EXCEPTION HANDLING
trap
{
    $Today = Get-Date -Format 'yyyyMMdd'
    "Error: $($_.Exception.Message)" | Out-File -FilePath "$PSScriptRoot\Error_$Today.txt" -Append -WhatIf:$false
    break
}



