![PowerShell](https://img.shields.io/badge/powershell-5391FE?style=flat&logo=powershell&logoColor=white)&nbsp;&nbsp;&nbsp;[![License: GPL v3](https://img.shields.io/badge/License-GPLv3-green)](https://www.gnu.org/licenses/gpl-3.0)

# Delegate GPO Permissions
The most simple way to allow other groups the creation and managing of their own Active Directory GPOs.

## Installation
The installation only consists of copying the script files into a desired folder, configure the enclosed Config.json file and possibly creating a Windows Scheduled Tasks. 

## Description
This repository contains a simple solution to delegate the permissions to create and manage Active Directory GPOs and WMI-Filters to other groups. The solution utilizes the Creator/Owner right, which is applied to every GPO-Container and the associated default AD group "Group Policy Creator Owners". Every member of this group can create GPOs and automatically becomes the owner of those GPOs. The problem is that other group members cannot access these GPOs. This is where the script comes in. It scans the GPO objects container at regular intervals, identifies the GPOs where a group member is the owner and replaces this trustee with the group to which the user belongs. The procedure is identical for WMI filters.

The following picturer show an example configuration of the script and what the script is doing:

<img width="650" height="312" alt="Configuration" src="https://github.com/user-attachments/assets/1aaf044e-27f4-4d68-a01f-91d6dfc91cf1" />

In the 'Groups' array we have for each group a hashtable consisting of the objectSID and the name of the group. We are using the SID to avoid problems in the case of a group renaming. The name property is only for the administrator to know which group the SID identifies. With the 'WhatIf' parameter set to TRUE you could perform a test run.

The test scenario uses two groups (ClientAdmisn and ServerAdmins) which should be allowed to create and manage their own GPOs. Both groups are members of the AD default group "Group Policy Creator Owners". This membership allows the members to create new GPOs in the GPO Objects-Container.

<img width="408" height="481" alt="Goup Policy Creator Owners-Group" src="https://github.com/user-attachments/assets/0f1d8510-e2cd-4c7b-be2c-af37b8be8e13" />

The next picture shows the result if user ClientAdminA which is a member of the group ClientAdmins has been created the new GPO "Test by ClientAdminA":

<img width="640" height="260" alt="Delegation settings new GPO by ClientAdminA" src="https://github.com/user-attachments/assets/58014ea9-27ef-4c15-b6af-5caf6d83a677" />

After the script has be run it show the following output in the log:

<img width="697" height="261" alt="Script Log Output" src="https://github.com/user-attachments/assets/e93eef8f-2f93-4351-a53b-ca9cb0d5ad80" />

It informs about what GPO has been manipulated and which trustee has been replaced with the corresponding group. The result is then that the group of the ClientAdminA has been placed in the ACL of the GPO:

<img width="638" height="244" alt="Delegation settings after the script" src="https://github.com/user-attachments/assets/cd6c7f7c-4c83-453f-941d-8e72f7e22f35" />

Only creating GPOs is not enough so we must also give the group the needed 'Link GPOs' permission on all OU which should be managed by this group:

<img width="941" height="602" alt="Delegation settings to allow GPO Linking" src="https://github.com/user-attachments/assets/5b5ba39a-f2ff-44ee-8a1f-19d53ff12ceb" />

## Contributing
All PowerShell developers or Active Directory experts are very welcome to help and make the code better, more readable or contribute new ideas. 

## License
This project is licensed under the terms of the GPL V3 license. Please see the included LICENCE file gor more details.

## Release History

### Version 1.0.1 (2024/10/04)
Code formatting to comply with the PES-Standard.
### Version 1.0.0 (2024/07/18)
This version has been tested and should be working.
### Version 0.1.0 (2024/06/04)
First release, testing has been done but bugs may still exist.


