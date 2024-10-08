#

# read username
$username=$env:username
$username='whertzing'

# read base of Dropbox
$DropboxBase = 'C:\Dropbox\'
# relative paths to subirs
$DocumentsRelPath =  $username + '\'
$FavoritesRelPath = $username + ' Favorites'
$MusicRelPath = 'Music'
$PhotosRelPath = 'Photos'
$VideosRelPath = 'Videos'
$DownloadsRelPath = 'Downloads'
# SavedGames

# List targets of shell extensions
$ShellExtRegKeyBase='HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\User Shell Folders'
#'REG_EXPAMD_SZ'

# Desired settings
$ShellExtKeyList = @{
'Documents'=('Personal',"$DropboxBase$DocumentsRelPath");'Favorites'=('Favorites',"$DropboxBase$FavoritesRelPath")
'Music'=('My Music',"$DropboxBase$MusicRelPath");'Photos'=('My Pictures',"$DropboxBase$PhotosRelPath")
'Videos'=('My Video',"$DropboxBase$VideosRelPath")
'Downloads'=('{374DE290-123F-4565-9164-39C4925E467B}',"$DropboxBase$DownloadsRelPath");
# SavedGames
}

# current settings
$cur = get-itemproperty -Path ($ShellExtRegKeyBase ) -Exclude PS*Path,PSDrive,PSChildName,PSProvider -name (($ShellExtKeyList.Values)|%{$_[0]})

# Diff settings
$hasdiff = @{}
Write-output "`r`n Shell Extensions desired and actual are `r`n"
$ShellExtKeyList.Keys | ForEach-Object{
  $key=$_
  write-output ("{0} Desired:{1} Actual:{2}" -f $key,($ShellExtKeyList[$key][1]),($cur.($ShellExtKeyList[$key][0])))
  if (($ShellExtKeyList[$key][1]) -ne ($cur.($ShellExtKeyList[$key][0]))) {$hasdiff[$key] = $True}
}

# prepare change commands
$ccmd = @{}
  if ($hasdiff.Count -gt 0) {
    $hasdiff.Keys | %{$key=$_;
    $ccmd[$key] = "Set-ItemProperty -path '$ShellExtRegKeyBase' -name '" + ($ShellExtKeyList[$key][0]) + "' -value '" + ($ShellExtKeyList[$key][1]) + "'"
  }
}
#
## Display changes
#ipmo showui;
#$UsersChoice = New-Dockpanel -Name 'DPControl' -Resource @{
#	  ########################################
#	  # The Resource dictionary is used to store default settings, start-up parameter arguments,
#	  #  scriptblocks for event handlers, application strings, and data for bound controls
#	  #  data for bound controls is usually initialized in the main windows On_Loaded event
#	  #  handler
#	  ##############################
#		##############################
#	  # Resource Strings # ToDo: Make this use a satellite assembly (hah-hah!)
#	  AppStrings = @{
#			btn_Cancel_str = 'Cancel'
#			btn_OK_str = 'OK'
#		}
#		AppScripts = @{
#			Set_UIOutput = {Param($outputdata);write-debug ("Set_UIOutput function starting. this = {0}" -f $this.Name)
#		    $Output = @{};$Output.('Selection') = $outputdata;
#		    $Output = @{'Selection' = $outputdata};
#				Set-UIValue DPControl -Passthru | Close-Control
#
#			}
#			WindowCloseHandlerAction = {write-debug ("WindowCloseHandlerAction starting window: {0}" -f $this)
#				$Host.EnterNestedPrompt();
#	      # Any unsaved work?
#	      # Ask the user if they want to save #ToDo with a 2-minute timeout
#	      # Get the answer #ToDO or a timeout
#	      # Save if requested #ToDo on timeout - save to a recovery file
#	      # Notify all Commanded entities that the Commanding process is closing
#	      # Sleep N seconds for acknowledgement(ref )
#	      # Release the Commanding Service Hosts
#	      # Release the Commanded Proxys (or client channels)
#	      # Release the Commanded MSMQueues
#	      # Release the internal queue Timers
#	      # Release the internal queues
#	      # Release the Commanded DLL locks
#	    # end of WindowCloseHandlerAction
#	    }
#		}
#	} -LastChildFill {
#		UniformGrid -Name grd_buttons  -Columns 2  -Dock Bottom {
#			Button $AppStrings.btn_Cancel_str -Name btn_Cancel -Margin "5" -VerticalAlignment "Center" -Column 0  -On_Click ({$Window.close()})
#			Button $AppStrings.btn_OK_str -Name btn_OK  -Margin "5" -VerticalAlignment "Center" -Column 1
#		} -On_Loaded {write-debug ("grd_buttons On_Loaded Event handler starting grd_button: {0}" -f $grd_buttons)
#		  # Add an event handler to each button
#		  Add-EventHandler $btn_OK Click {$this.$AppScripts.Set_UIOutput($AppStrings.btn_OK_str) ;$Window.Close()}
#		  Add-EventHandler $btn_Cancel Click {$AppScripts.Set_UIOutput($AppStrings.btn_Cancel_str) ; $Window.Close()}
#		}
#	} -On_Loaded {
#	Add-EventHandler $Window Closing $AppScripts.WindowCloseHandlerAction
#	}-Show
#


Write-output "`r`n Change commands will be `r`n"
Write-output $ccmd


# confirm changes

# make changes

#$ccmd.Values | %{iex $_}

