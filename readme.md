# Move-FilesToArchive #

This script file will delete, move, zip, or move and zip, files older than a specified date.  This script is meant to be used in a scheduled task and has been designed to minimize the number of parameters needed to be used to execute the script.



## Features: ##

- **XML Config File for each "job"**: A XML configuration file can be created for each time of "job" configured to use this script.  This makes it very useful to have one script, but it can be run multiple times with different configuration files to perform clean up of multiple directories.


## How to Use ##

- Simply copy the script and all the sub directories in the repo to your target machine.
- Create another XML configuration file for the "job" you want performed.  You can find an example XML file in the _Default_XML_Files folder.
- Create a scheduled task with the appropriate settings and run!

## Parameters & Defaults ##

The script only has one parameter:

- **ConfigFile** - This is the full path to the XML file that contains the configuration for a particular "job".

###Logging###

The script uses the MultiLogv1 module for logging purposes.  The log is setup as the default **circular** logging format.  By default, it will create log files that are 1mb big before circulating the log files.

The location of the log files can be configured in the XML file for the job. The ROOT name of the log file can also be changed.  Highly recommended if you use multiple instances of this script file against the same application.  For instance, one name for daily logs and another for weekly logs.

## Default XML Files ##

Using this section to document the default settings of the XML job file.  You can find default versions of this file in the _Default_XML_Files folder of the repo.

## Schedule Task Recommendations ##

Here are the recommended settings for using the script as a scheduled task:

**Application:** C:\Windows\System32\WindowsPowerShell\v1.0\powershell.exe

**Parameters:** -noninteractive -command "& 'D:\ScheduledTasks\Move-FilesToArchive\Move-FilesToArchive.ps1'  'D:\ScheduledTasks\ADExport\ArchiveConfig\ADExportCleanWeekly.Settings.xml'"

The parameter above should be changed for the particular instance you are setting up.  In the example above, the script is located in the D:\ScheduledTasks\Move-FilesToArchive\ folder and the configuration file is D:\ScheduledTasks\ADExport\ArchiveConfig\ADExportCleanWeekly.Settings.xml.  Please note the combination of quotes and double-quotes in the example.


### Job XML Configuration File ###

	<?xml version="1.0"?>
	<Settings>
		<ScriptConfig>
			<LogDir>"location of application's script file"/logs</LogDir>
			<LogRootName>Move-FilesToArchive</LogRootName>
		</ScriptConfig>
		<Archive>
			<DirectoryInfo>For directories below, leave off the end backslash.</DirectoryInfo>
			<SourceDirectory>C:\Script\Move-FilesToArchive\App_Logs</SourceDirectory>
			<ArchiveDirectory>C:\Script\Move-FilesToArchive\Log_Archive</ArchiveDirectory>
			<NumOfDaysOfUnArchivedFiles>7</NumOfDaysOfUnArchivedFiles>
			<ArchiveTypeInfo>The ArchiveType can be: ZIP, MOVE, DELETE</ArchiveTypeInfo>
			<ArchiveType>ZIP</ArchiveType>
			<BaseArchiveFileName>LogArchive_</BaseArchiveFileName>
		</Archive>
	</Settings>