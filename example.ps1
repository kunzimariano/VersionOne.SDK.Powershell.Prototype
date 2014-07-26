Import-Module .\VersionOne.SDK.Powershell.psm1 -args "https://www14.v1host.com/v1sdktesting", "admin", "admin"	

# Using aliases:
$s = (vmeta).Story; $s | vquery 37741 | vselect $s.Name, $s.ID, $s.CreateDate | vfetch

# Same thing, but with long function names:
$s = (Get-V1Metamodel).Story; $s | Start-V1Query 37741 | Invoke-V1Select $s.Name, $s.ID, $s.CreateDate | Invoke-V1Fetch
