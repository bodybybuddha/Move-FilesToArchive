<#
.SYNOPSIS
    Script to archive files after a set period of time.
 
.DESCRIPTION
    Script to archive files after a set period of time.  Designed to be executed as a Scheduled Task.  All configuration is controlled by using an XML file.  The XML location and name is required to execute the script.  Please see README.MD for additional information.
	
	This script works best if you set the working directory to the same location as the script.  
	
.PARAMETER ConfigFile
   Location of the Configuration file for a particular job.  By parametizing this option, you can create many scheduled tasks that uses the same script - but with different configuration files.

.INPUTS
 
.OUTPUTS

.EXAMPLE

	Move-FilesToArchive -ConfigFile App01-Archive.Settings.xml
	
	The command above will execute the script using the App01-Archive.Settings.xml.
 
.NOTES
 Version:        2.0
  Author:         John Taylor
  Creation Date:  11/09/2017
  Purpose/Change: Clean up the different versions of this file.

  Version:        1.9
  Author:         John Taylor
  Creation Date:  11/06/2017
  Purpose/Change: Forced to give full location of settings XML. Clean up Delete routine
  
  Version:        1.8
  Author:         John Taylor
  Creation Date:  03/20/2017
  Purpose/Change: Added ability to log root name.
  
  Version:        1.7
  Author:         John Taylor
  Creation Date:  03/08/2017
  Purpose/Change: Added ability to simply delete files.
  
  Version:        1.6
  Author:         John Taylor
  Creation Date:  03/08/2017
  Purpose/Change: Improved method to determine where to find libraries
  
  Version:        1.5
  Author:         John Taylor
  Creation Date:  03/08/2017
  Purpose/Change: Consolidated script's config xml into individual job config xml for simplicity.
  
  Version:        1.0
  Author:         John Taylor
  Creation Date:  03/07/2017
  Purpose/Change: Initial Script

#Requires �Version 3  
#>

[CmdletBinding()]
#-----------------------------------------------------------[Parameters]-----------------------------------------------------------
Param (
	[Parameter(Mandatory=$True,Position=0)]
		$ConfigFile
    )
 
#---------------------------------------------------------[Initialisations]--------------------------------------------------------
 
#Set Error Action to Silently Continue
$ErrorActionPreference = "SilentlyContinue"
 
#Dot Source required Function Libraries
if(-not (Get-Variable -Name 'PSScriptRoot' -Scope 'Script')) {
    $Script:PSScriptRoot = Split-Path -Path $MyInvocation.MyCommand.Definition -Parent -ErrorAction SilentlyContinue
}

import-module (Join-Path $PSScriptRoot libraries\MultiLogv1.psm1)
. (Join-Path $PSScriptRoot libraries\Zip_Functions)

#----------------------------------------------------------[Declarations]----------------------------------------------------------
 
#Script Version
$sScriptVersion = "2.0"
$sScriptName = "Move-FilesToArchive"
$sExitCode = 0

##########################
## Script Config file option 
##########################

$sScriptStartDir = Split-Path -Parent $MyInvocation.MyCommand.Path
 
Try{    
	[xml]$gConfigSettings = get-content $ConfigFile
    
    if($gConfigSettings -eq $Null){
        $sErrorEncountered = $True
	    $ErrMessage = "Error getting script configuration file $($ConfigFile): Error line $($_.InvocationInfo.ScriptLineNumber):$($_.InvocationInfo.OffsetInLine) - $($_.Exception)"
	    Add-Content -Path "$(Split-Path -Parent $MyInvocation.MyCommand.Path)\criticalerror.log" -Value $ErrMessage 
	    Exit -1
    } 

} Catch {
	$sErrorEncountered = $True
	$ErrMessage = "Error getting configuration file $($ConfigFile): Error line $($_.InvocationInfo.ScriptLineNumber):$($_.InvocationInfo.OffsetInLine) - $($_.Exception)"
	Add-Content -Path "$(Split-Path -Parent $MyInvocation.MyCommand.Path)\criticalerror.log" -Value $ErrMessage 
	Exit -1
} 

###########################################################################
#Log File Info
$sLogPath = $gConfigSettings.Settings.ScriptConfig.LogDir
if(!(Test-Path -Path $slogPath -PathType Container)){
	New-Item -Path $slogPath -ItemType Directory -Force 
}

$sLogRootName = $gConfigSettings.Settings.ScriptConfig.LogRootName
$sLogName = $sLogRootName + ".log"
$sLogFile = $sLogPath + "\" + $sLogName
$sTranscriptFile = $sLogPath + "\Transcript-" + $sLogName 

$LogObj = Initialize-Log -ExecutingScriptName $sScriptName -LogType 'CIRCULAR' -LogFileName $sLogFile

###########################################################################

#-----------------------------------------------------------[Functions]------------------------------------------------------------

Function PreflightCheck{
#  1 - check givens
#     Does the directory that holds log files exist?
#     Does the directory to hold the Archive version exist?
	Try{
		
		#check for directory
		if(!(Test-Path -Path $gConfigSettings.Settings.Archive.SourceDirectory -PathType Container)){
			
			$ErrMessage = "Was not able to find source directory: $($gConfigSettings.Settings.Archive.SourceDirectory)"
			Write-LogEntry -LogObject $LogObj -EventID 1001 -MessageType "ERROR" -Message $ErrMessage
			
			return $false
			
		} else {
		
			if($gConfigSettings.Settings.Archive.ArchiveType -NE "DELETE"){
				#Check for Archive directory
				if(!(Test-Path -Path $gConfigSettings.Settings.Archive.ArchiveDirectory -PathType Container)){
					$Message = "Was not able to find Archive directory: $($gConfigSettings.Settings.Archive.SourceDirectory).  Attempting to create directory."
					Write-LogEntry -LogObject $LogObj -EventID 1002 -MessageType "INFORMATION" -Message $Message
					Try {
						New-Item -Path $gConfigSettings.Settings.Archive.ArchiveDirectory -ItemType Directory -Force 
						
						$Message = "Archive Directory Created."
						Write-LogEntry -LogObject $LogObj -EventID 1002 -MessageType "INFORMATION" -Message $Message
						return $true
						
					} catch {
						$ErrMessage = "Error in Preflight - Couldn't create Archive Directory. Error line $($_.InvocationInfo.ScriptLineNumber):$($_.InvocationInfo.OffsetInLine) - $($_.Exception)"
						Write-LogEntry -LogObject $LogObj -EventID 102 -MessageType "ERROR" -Message $ErrMessage			
						
						return $false				
					}
				} else {
					$Message = "Archive Directory Found."
					Write-LogEntry -LogObject $LogObj -EventID 1002 -MessageType "INFORMATION" -Message $Message
					return $true			
				}			
			} else {
				$Message = "Archive Mode: DELETE."
				Write-LogEntry -LogObject $LogObj -EventID 1002 -MessageType "INFORMATION" -Message $Message
				return $true			
			}			
		}			
	} catch {
			$ErrMessage = "Error in Preflight. Error line $($_.InvocationInfo.ScriptLineNumber):$($_.InvocationInfo.OffsetInLine) - $($_.Exception)"
			Write-LogEntry -LogObject $LogObj -EventID 101 -MessageType "ERROR" -Message $ErrMessage			
			return $false	
	}
	
	$Message = "Logic error in preflight check."
	Write-LogEntry -LogObject $LogObj -EventID 102 -MessageType "ERROR" -Message $Message
	return $false  # should not end up here... but ...
	
}  # end of PreflightCheck

Function ProcessArchives{
	$Message = "Starting the archive processs"
	Write-LogEntry -LogObject $LogObj -EventID 2001 -MessageType "INFORMATION" -Message $Message
	$flgError = $false
	
	# we plan on getting all of the files older than the target number days in the config file
	# we will then go through that collection on a daily basis and process each day as its own batch
	
	# Get-ChildItem C:\Script\Move-FilesToArchive\Static_Logs | where{$_.CreationTime -le (get-date).AddDays(-10)} | group {$_.CreationTime.ToString("yyyy-MM-dd")}
	
	[int]$NumOfDays2Keep = $gConfigSettings.Settings.Archive.NumOfDaysOfUnArchivedFiles
	if($NumofDays2Keep -gt 0){ $NumofDays2Keep=($NumOfDays2Keep)*(-1)}  #Ensure this is a negative number
	
	$theCollection = Get-ChildItem $gConfigSettings.Settings.Archive.SourceDirectory | where{$_.CreationTime -le (get-date).Adddays($NumOfDays2Keep)} | group {$_.CreationTime.ToString("yyyy-MM-dd")}
	
	# Go through each day in the collection: 
	foreach($DayColl in $theCollection){
	
		if($gConfigSettings.Settings.Archive.ArchiveType -eq "ZIP"){ # Zip & Move the Files
		
			Try{
				
				$targetZipFile = "$($gConfigSettings.Settings.Archive.ArchiveDirectory)\$($gConfigSettings.Settings.Archive.BaseArchiveFileName)$($DayColl.Name).zip"
				
				$Message = "Compressing $($DayColl.Name) files to $($targetZipfile)"
				Write-LogEntry -LogObject $LogObj -EventID 2001 -MessageType "INFORMATION" -Message $Message
			
				$CollOfFilenames = ($DayColl.group).fullname
				$CollOfFilenames | Add-Zip -zipfilename $targetZipFile
				$CollOfFilenames | Remove-Item		
				 
				
			} catch {
				
				$ErrMessage = "Error in zipping files. Verify all files were zipped and moved for $($DayColl.Name). Error line $($_.InvocationInfo.ScriptLineNumber):$($_.InvocationInfo.OffsetInLine) - $($_.Exception)"
				Write-LogEntry -LogObject $LogObj -EventID 201 -MessageType "ERROR" -Message $ErrMessage			
				$flgError = $True				
			}
		
		
		} #End of Zip
		elseif($gConfigSettings.Settings.Archive.ArchiveType -eq "DELETE") {  # delete the Files
			
			Try{
			
				$Message = "Removing $($DayColl.Name) files."
				Write-LogEntry -LogObject $LogObj -EventID 2001 -MessageType "INFORMATION" -Message $Message
				
				$CollOfFilenames = ($DayColl.group).fullname
				foreach($entry in $CollOfFilenames){
				
					$entry | Remove-Item 
					
					$Message = "Removing $($entry)."
					Write-LogEntry -LogObject $LogObj -EventID 2001 -MessageType "INFORMATION" -Message $Message
					
				} 
			
			} catch {
				
				$ErrMessage = "Error in removing files. Verify all files were removed for $($DayColl.Name). Error line $($_.InvocationInfo.ScriptLineNumber):$($_.InvocationInfo.OffsetInLine) - $($_.Exception)"
				Write-LogEntry -LogObject $LogObj -EventID 202 -MessageType "ERROR" -Message $ErrMessage			
				$flgError = $True				
				
			}
		
		} #End of Delete
		Else{  # Move the Files
		
			Try{
			
				$Message = "Moving $($DayColl.Name) files to $($gConfigSettings.Settings.Archive.ArchiveDirectory)"
				Write-LogEntry -LogObject $LogObj -EventID 2001 -MessageType "INFORMATION" -Message $Message
				
				$CollOfFilenames = ($DayColl.group).fullname
				$CollOfFilenames | Move-Item -Destination $gConfigSettings.Settings.Archive.ArchiveDirectory											 
			
			} catch {
				
				$ErrMessage = "Error in moving files. Verify all files were moved for $($DayColl.Name). Error line $($_.InvocationInfo.ScriptLineNumber):$($_.InvocationInfo.OffsetInLine) - $($_.Exception)"
				Write-LogEntry -LogObject $LogObj -EventID 202 -MessageType "ERROR" -Message $ErrMessage			
				$flgError = $True				
				
			}
		
		
		} # End of Move
			
	}  #End of Foreach Day 

	$Message = "Completed the archive processs"
	Write-LogEntry -LogObject $LogObj -EventID 2001 -MessageType "INFORMATION" -Message $Message
	
	if($flgError){return $false} else {return $true}
} # End of ProcessArchives function

#-----------------------------------------------------------[Execution]------------------------------------------------------------
 
Start-Log -LogObject $LogObj
Write-LogEntry -LogObject $LogObj -EventID 1 -MessageType "INFORMATION" -Message "Started Script: $($sScriptName) Version: $($sScriptVersion)" 

#If verbose switch is given write the myinvocation variable to the log
if ($PSCmdlet.MyInvocation.BoundParameters["Verbose"].IsPresent){
	Write-LogEntry -LogObject $LogObj -MessageType "INFORMATION" -EventID 1 -Message "-------- Script executed with the following --------" 
	Write-LogEntry -LogObject $LogObj -MessageType "INFORMATION" -EventID 1 -Message $myinvocation 
	Write-LogEntry -LogObject $LogObj -MessageType "INFORMATION" -EventID 1 -Message "----------------------------------------------------" 
	Write-LogEntry -LogObject $LogObj -MessageType "INFORMATION" -EventID 1 -Message "Starting Transcript" -DT 
	Write-LogEntry -LogObject $LogObj -MessageType "INFORMATION" -EventID 1 -Message "----------------------------------------------------"  
	
	Start-Transcript -path $sTranscriptFile
}

#### Start Coding Here ####

#  1 - check givens
#     Does the directory that holds log files exist?
#     Does the directory to hold the Archive version exist?
#
#  2 - Get the collection of files to be archived
#	  Cycle through the collection and by date do the following:
#		a) If zipping - zip the collection to the archive directory
#		b) if not zipping - move the collection to the archive directory
#		c) New Option - delete files
#
#  3 - If all good, remove the archived files

If(PreflightCheck){
	
	$Message = "Source Directory: $($gConfigSettings.Settings.Archive.SourceDirectory)"
	Write-LogEntry -LogObject $LogObj -EventID 2001 -MessageType "INFORMATION" -Message $Message
	
	$Message = "Archive Directory: $($gConfigSettings.Settings.Archive.ArchiveDirectory)"
	Write-LogEntry -LogObject $LogObj -EventID 2001 -MessageType "INFORMATION" -Message $Message
	
	$Message = "Archive Type: $($gConfigSettings.Settings.Archive.ArchiveType)"
	Write-LogEntry -LogObject $LogObj -EventID 2001 -MessageType "INFORMATION" -Message $Message
	
	if(!(ProcessArchives)){
		$sExitCode = 1002
	}
	
} else {
	$sExitCode = 1001
}

Write-LogEntry -LogObject $LogObj -EventID 1 -MessageType "INFORMATION" -Message "Completed Script." 

#Finish up the script - close out the log
if ($PSCmdlet.MyInvocation.BoundParameters["Verbose"].IsPresent){
	Stop-Transcript
}

Stop-Log -LogObject $LogObj
Exit $sExitCode