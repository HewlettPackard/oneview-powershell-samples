## How to Automate an HP OneView Appliance Backup with PowerShell

This document will walk you through on how to setup a Scheduled Task within Windows to help automate the backup of an HP OneView Appliance.

<ol>
 <li>First, open the Task Schedule MMC console, and select Create Basic Task</li>
 <li>Provide a Task Name, and include a description if you need.</li>
 <li>Specify the backup task execution interval/trigger.</li>
 <li>Leave the default <pre>Start a Program</pre> selected, then paste the following into the <pre>Program/Script</pre> field:</li>

</ol>

```
%WinDir%\System32\WindowsPowerShell\v1.0\powershell.exe -command "& C:\HPOneView_Backup\appliance_backup.ps1 C:\HPOneView_Backup" C:\HPOneView_Backup
```

***

**NOTE:** _Replace ```C:\HPOneView_Backup``` with the directory location where you wish to store and execute the Appliance_Backup.ps1 script and where the appliance backup file will be saved to._
***

<ol start="5">
  <li>When prompted, select Yes to continue. </li>
  <li>Click Finish to complete the configuration of the new Scheduled Task. </li>
</ol>

Alternatively, you can download the OneView_Appliance_Backup.xml exported Scheduled Task and Import it into the Task Scheduler console.