![PowerShell](https://img.shields.io/badge/powershell-5391FE?style=flat&logo=powershell&logoColor=white)&nbsp;&nbsp;&nbsp;[![License: GPL v3](https://img.shields.io/badge/License-GPLv3-green)](https://www.gnu.org/licenses/gpl-3.0)

# Delegate GPO Permissions
A declarative way to implement dynamic groups in Active Directory.

## Installation
The installation only consists of copying the script files into a desired folder, configure the enclosed Config.json file and possibly creating a Windows Scheduled Tasks. 

## Description
This repository contains a simple solution to delegate the permissions to create and manage Active Directory GPOs and WMI-Filters to other groups. The solution utilizes the Creator/Owner right, which is applied to every GPO-Container and the associated default AD group "Group Policy Creator Owners". Every member of this group can create GPOs and automatically becomes the owner of those GPOs. The problem is that other group members cannot access these GPOs. This is where the script comes in. It scans the GPO objects container at regular intervals, identifies the GPOs where a group member is the owner and replaces this trustee with the group to which the user belongs. The procedure is identical for WMI filters.








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

