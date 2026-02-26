Callisto Scripts Repository
================

This repository contains a number of scripts that I have written or enhanced to setup/configure my dev machine. These are provided for free to the community under an MIT License.

# Debloat Windows 10

## Execution

Enable execution of PowerShell scripts:

    PS> Set-ExecutionPolicy Unrestricted -Scope CurrentUser

Unblock PowerShell scripts and modules within this directory:

    PS> ls -Recurse *.ps*1 | Unblock-File

## Usage

Scripts can be run individually, pick what you need.

1. Install all available updates for your system.
2. Edit the scripts to fit your need.
3. Run the scripts you want to apply from a PowerShell with administrator privileges.
4. `PS > Restart-Computer`
5. Run `disable-windows-defender.ps1` one more time if you ran it in step 3
6. `PS > Restart-Computer`

### Lots of stuff was copied from:
- [W4RH4WK/Debloat-Windows-10](https://github.com/W4RH4WK/Debloat-Windows-10)
- [ruudmens/LazyAdmin](https://github.com/ruudmens/LazyAdmin)

# Auto-winget.
A scheduled task is configured to run on certain MsiInstaller events from the eventlog (i.e. whenever a program is installed). The posh script clones the `winget` branch of this repository, runs `winget export -o winget.json` and then commits & pushes.


### Local Security Policy (secpol.msc)
    Security Settings > Local Policies > User Rights Assignment > Log on as batch job

<div style="display:flex;flex-flow:row wrap;justify-content:space-between;">
<img src="static/start-secpol.png" width="450"/>
<img src="static/logon-as-batch.png" width="450"/>
</div>
## Liability

**All scripts are provided as-is and you use them at your own risk.**

## Contribute

I would be happy to extend the collection of scripts. Just open an issue or
send me a pull request.




## License

    "THE BEER-WARE LICENSE" (Revision 42):

    As long as you retain this notice you can do whatever you want with this
    stuff. If we meet someday, and you think this stuff is worth it, you can
    buy us a beer in return.

    This project is distributed in the hope that it will be useful, but WITHOUT
    ANY WARRANTY; without even the implied warranty of MERCHANTABILITY or
    FITNESS FOR A PARTICULAR PURPOSE.