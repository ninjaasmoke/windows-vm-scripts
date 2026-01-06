# kill the workers

taskkill /f /im tiworker.exe
taskkill /f /im trustedinstaller.exe

# stop others
net stop wuauserv
net stop bits
net stop usosvc
net stop cryptsvc
net stop dosvc
sc stop trustedinstaller


# STOP auto update
sc config wuauserv start= disabled
sc config usosvc start= disabled
sc config bits start= disabled
sc config dosvc start= disabled


# DISABLE auto update - WILL REBOOT
sc stop wuauserv
sc stop bits
sc stop usosvc
sc stop dosvc
sc stop WaaSMedicSvc
sc stop cryptsvc

sc config wuauserv start= disabled
sc config bits start= disabled
sc config usosvc start= disabled
sc config dosvc start= disabled
sc config WaaSMedicSvc start= disabled
sc config cryptsvc start= disabled

schtasks /change /tn "\Microsoft\Windows\UpdateOrchestrator\Reboot" /disable
schtasks /change /tn "\Microsoft\Windows\UpdateOrchestrator\Schedule Scan" /disable
schtasks /change /tn "\Microsoft\Windows\UpdateOrchestrator\USO_UxBroker" /disable
schtasks /change /tn "\Microsoft\Windows\WindowsUpdate\Automatic App Update" /disable
schtasks /change /tn "\Microsoft\Windows\WindowsUpdate\Scheduled Start" /disable

reg add "HKLM\SYSTEM\CurrentControlSet\Services\WaaSMedicSvc" /v Start /t REG_DWORD /d 4 /f

netsh advfirewall firewall add rule name="Block Windows Update" dir=out action=block service=wuauserv

shutdown /r /t 0

# REENABLE updates
sc config wuauserv start= demand
sc config bits start= demand
sc config usosvc start= demand
sc config dosvc start= demand
sc config WaaSMedicSvc start= demand
net start wuauserv
