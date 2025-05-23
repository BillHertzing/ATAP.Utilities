<#
Not ready for prime t8me, but, eventually will be a simple in-process webserver running a dotnet Core Kestrel web server

Attribution: [powershell-web-server.ps1](https://gist.github.com/19WAS85/5424431)
#>


Function Invoke-Webserver {
  #region FunctionParameters
  [CmdletBinding(SupportsShouldProcess = $true)]
  param (
    # ToDo: two or more parameter sets, to deal with both Path and LiteralPath
    [parameter(ValueFromPipeline = $True, ValueFromPipelineByPropertyName = $True)][string[]] $Prefixes
    , [parameter(Mandatory = $false)][string] $WWWRoot
  )
  #endregion FunctionParameters
  #region FunctionBeginBlock
  ########################################
  BEGIN {
    Write-Verbose -Message "Starting $($MyInvocation.MyCommand)"

    $Settings = @{
      Prefixes = @('http://localhost:1010/')
      WWWRoot  = Join-Path Get-Location 'www'

    }

    # Things to be initialized after settings are processed
    if ($Prefixes) { $Settings.Prefixes = $Prefixes }
    if ($WWWRoot) { $Settings.WWWRoot = $WWWRoot }

    $SettingsAsString = $settings.Keys | ForEach-Object { $key = $_; $key.ToString() + ' : ' + $Settings[$key].ToString() }
    Write-Verbose -Message "BEGIN: Initial Settings: $SettingsAsString"
  }

  PROCESS {}

  END {

    # This is a super **SIMPLE** example of how to create a very basic powershell webserver
    # 2019-05-18 UPDATE — Created by me and and evaluated by @jakobii and the comunity.

    # Http Server
    $http = [System.Net.HttpListener]::new()

    # Hostname and port to listen on
    foreach ($p in $Settings.Prefixes) {
      $http.Prefixes.Add($p)
    }

    # Start the Http Server
    $http.Start()


    # Log ready message to terminal
    if ($http.IsListening) {
      Write-Verbose ' HTTP Server Ready!  ' -f 'black' -b 'gre'
      Write-Verbose "now try going to $($http.Prefixes[0])" -f 'y'
      Write-Verbose "then try going to $($http.Prefixes)other/path" -f 'y'
    }


    # infinite loop
    # Used to listen for requests
    while ($http.IsListening) {

      # Get Request Url
      # When a request is made in a web browser the GetContext() method will return a request object
      # Our route examples below will use the request object properties to decide how to respond
      $context = $http.GetContext()


      # ROUTE EXAMPLE 1
      # http://127.0.0.1/
      if ($context.Request.HttpMethod -eq 'GET' -and $context.Request.RawUrl -eq '/') {

        # We can log the request to the terminal
        Write-Host "$($context.Request.UserHostAddress)  =>  $($context.Request.Url)" -f 'mag'

        # the html/data you want to send to the browser
        # you could replace this with: [string]$html = Get-Content "C:\some\path\index.html" -Raw
        [string]$html = '<h1>A Powershell Webserver</h1><p>home page</p>'

        #resposed to the request
        $buffer = [System.Text.Encoding]::UTF8.GetBytes($html) # convert html to bytes
        $context.Response.ContentLength64 = $buffer.Length
        $context.Response.OutputStream.Write($buffer, 0, $buffer.Length) #stream to browser
        $context.Response.OutputStream.Close() # close the response

      }

      # ROUTE EXAMPLE 2
      # http://127.0.0.1/some/form'
      if ($context.Request.HttpMethod -eq 'GET' -and $context.Request.RawUrl -eq '/some/form') {

        # We can log the request to the terminal
        Write-Host "$($context.Request.UserHostAddress)  =>  $($context.Request.Url)" -f 'mag'

        [string]$html = "
        <h1>A Powershell Webserver</h1>
        <form action='/some/post' method='post'>
            <p>A Basic Form</p>
            <p>fullname</p>
            <input type='text' name='fullname'>
            <p>message</p>
            <textarea rows='4' cols='50' name='message'></textarea>
            <br>
            <input type='submit' value='Submit'>
        </form>
        "

        #resposed to the request
        $buffer = [System.Text.Encoding]::UTF8.GetBytes($html)
        $context.Response.ContentLength64 = $buffer.Length
        $context.Response.OutputStream.Write($buffer, 0, $buffer.Length)
        $context.Response.OutputStream.Close()
      }

      # ROUTE EXAMPLE 3
      # http://127.0.0.1/some/post'
      if ($context.Request.HttpMethod -eq 'POST' -and $context.Request.RawUrl -eq '/some/post') {

        # decode the form post
        # html form members need 'name' attributes as in the example!
        $FormContent = [System.IO.StreamReader]::new($context.Request.InputStream).ReadToEnd()

        # We can log the request to the terminal
        Write-Host "$($context.Request.UserHostAddress)  =>  $($context.Request.Url)" -f 'mag'
        Write-Host $FormContent -f 'Green'

        # the html/data
        [string]$html = '<h1>A Powershell Webserver</h1><p>Post Successful!</p>'

        #resposed to the request
        $buffer = [System.Text.Encoding]::UTF8.GetBytes($html)
        $context.Response.ContentLength64 = $buffer.Length
        $context.Response.OutputStream.Write($buffer, 0, $buffer.Length)
        $context.Response.OutputStream.Close()
      }


      # powershell will continue looping and listen for new requests...

    }

    # Note:
    # To end the loop you have to kill the powershell terminal. ctrl-c wont work :/
  }
}
