Param
(
	[string]$MyPassword	
)				

$SystemRoot = $env:SystemRoot
$Log_File = "$SystemRoot\Debug\Dell_BIOS_Settings.log" 
If(test-path $Log_File)
	{
		remove-item $Log_File -force
	}
new-item $Log_File -type file -force

Function Write_Log
	{
	param(
	$Message_Type, 
	$Message
	)
		$MyDate = "[{0:MM/dd/yy} {0:HH:mm:ss}]" -f (Get-Date)  
		Add-Content $Log_File  "$MyDate - $Message_Type : $Message"  
	} 

Function Get-DellBIOSProvider
{
    [CmdletBinding()]
    param()		
	If (!(Get-Module DellBIOSProvider -listavailable)) 
		{
			Install-Module DellBIOSProvider -ErrorAction SilentlyContinue
			Write_Log -Message_Type "INFO" -Message "DellBIOSProvider has been installed"  			
		}
	Else
		{
			Import-Module DellBIOSProvider -ErrorAction SilentlyContinue
			Write_Log -Message_Type "INFO" -Message "DellBIOSProvider has been imported"  			
		}
}

  
Write_Log -Message_Type "INFO" -Message "The 'Set BIOS settings for Dell' process starts"  

Get-DellBIOSProvider 
  
$Exported_CSV = ".\BIOS_Settings.csv"																																			
$Get_CSV_Content = Import-CSV $Exported_CSV  -Delimiter ";"				

$IsPasswordSet = (Get-Item -Path DellSmbios:\Security\IsAdminPasswordSet).currentvalue 

If($IsPasswordSet -eq $true)						
	{
		Write_Log -Message_Type "INFO" -Message "A password is configured"  
		If($MyPassword -eq "")
			{
				Write_Log -Message_Type "WARNING" -Message "No password has been sent to the script"  	
				Break
			}
	}
	
$Dell_BIOS = get-childitem -path DellSmbios:\ | foreach {
get-childitem -path @("DellSmbios:\" + $_.Category)  | select-object attribute, currentvalue, possiblevalues, PSChildName}   

ForEach($New_Setting in $Get_CSV_Content)
	{ 
		$Setting_To_Set = $New_Setting.Setting 
		$Setting_NewValue_To_Set = $New_Setting.Value 
		
		Add-Content $Log_File  "" 
		Write_Log -Message_Type "INFO" -Message "Change to do: $Setting_To_Set > $Setting_NewValue_To_Set"  
		
		ForEach($Current_Setting in $Dell_BIOS | Where {$_.attribute -eq $Setting_To_Set})
			{ 
				$Attribute = $Current_Setting.attribute
				$Setting_Cat = $Current_Setting.PSChildName
				$Setting_Current_Value = $Current_Setting.CurrentValue

				If (($IsPasswordSet -eq $true))
					{   
						$Password_To_Use = $MyPassword
						Try
							{
								& Set-Item -Path Dellsmbios:\$Setting_Cat\$Attribute -Value $Setting_NewValue_To_Set -Password $Password_To_Use
								Write_Log -Message_Type "SUCCESS" -Message "New value for $Attribute is $Setting_Current_Value"  						
							}
						Catch
							{
								Write_Log -Message_Type "ERROR" -Message "Can not change setting $Attribute (Return code $Change_Return_Code)"  																		
							}
					}
				Else
					{
						Try
							{
								& Set-Item -Path Dellsmbios:\$Setting_Cat\$Attribute -Value $Setting_NewValue_To_Set  
								Write_Log -Message_Type "SUCCESS" -Message "New value for $Attribute is $Setting_Current_Value"  						
							}
						Catch
							{
								Write_Log -Message_Type "ERROR" -Message "Can not change setting $Attribute (Return code $Change_Return_Code)"  																		
							}						
					}        
			}  
	}  