##############
# Totally stole this code!!
# Look here for source: https://blogs.msdn.microsoft.com/jerrydixon/2014/08/08/zipping-a-single-file-with-powershell/
##
# Really old stuff - just wanted to find a way of executing zips without very recent versions of powershell, .net, etc
# Also didn't want to install an application like 7zip
##

## 
# I did change the input of add-zip to get basically strings of information rather than a file. Was useful in my use case at the time.
##############

function New-Zip
{
	param([string]$zipfilename)
	set-content $zipfilename ("PK" + [char]5 + [char]6 + ("$([char]0)" * 18))
	(dir $zipfilename).IsReadOnly = $false
}

function Add-Zip
{
	param([string]$zipfilename)

	if(-not (test-path($zipfilename)))
	{
		set-content $zipfilename ("PK" + [char]5 + [char]6 + ("$([char]0)" * 18))
		(dir $zipfilename).IsReadOnly = $false	
	}
	
	$shellApplication = new-object -com shell.application
	$zipPackage = $shellApplication.NameSpace($zipfilename)
	
	foreach($file in $input) 
	{ 
            $zipPackage.CopyHere($file)
            Start-sleep -milliseconds 500
	}
}

function Get-Zip
{
	param([string]$zipfilename)
	if(test-path($zipfilename))
	{
		$shellApplication = new-object -com shell.application
		$zipPackage = $shellApplication.NameSpace($zipfilename)
		$zipPackage.Items() | Select Path
	}
}

function Extract-Zip
{
	param([string]$zipfilename, [string] $destination)

	if(test-path($zipfilename))
	{	
		$shellApplication = new-object -com shell.application
		$zipPackage = $shellApplication.NameSpace($zipfilename)
		$destinationFolder = $shellApplication.NameSpace($destination)
		$destinationFolder.CopyHere($zipPackage.Items())
	}
}

