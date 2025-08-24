
/* Get the list of sqlserver service accounts associated with each instance on a server machine */
/* Attribution: https://dba.stackexchange.com/questions/223653/how-to-find-out-the-service-accounts-for-each-of-my-instances-in-the-current-ser */
Set nocount on
Set xact_abort on

BEGIN TRY
            Declare @registrypath varchar(200)
            , @namedinstanceind char(1)
            , @instancename varchar(128) 
            , @sqlserversvcaccount varchar(128)
            , @sqlagentsvcaccount varchar(128)
            , @dtcsvcaccount varchar(128)
            , @sqlsearchsvcaccount varchar(128)
            , @sqlserverstartup varchar(128)
            , @sqlagentstartup varchar(128)
            , @dtcstartup varchar(128)
            , @sqlsearchstartup varchar(128)

            if object_id('tempdb..#registryentry') is not null
               drop table #registryentry

            if object_id('tempdb..#GetInstances') is not null
               drop table #GetInstances 

            if object_id('tempdb..#Radhe') is not null
               drop table #Radhe 


            create table #GetInstances  ( Value nvarchar(100),InstanceNames nvarchar(100),Data nvarchar(100))
            create table #registryentry (value varchar(50), data varchar(50))
            create table #Radhe         (machinename nvarchar(128)
                                        , instancename varchar(128)
                                        , sqlserversvcaccount varchar(128)
                                        , sqlagentsvcaccount varchar(128)
                                        , dtcsvcaccount varchar(128)
                                        , sqlsearchsvcaccount varchar(128)
                                        , sqlserverstartup varchar(128)
                                        , sqlagentstartup varchar(128)
                                        , dtcstartup varchar(128)
                                        , sqlsearchstartup varchar(128))

            Insert into #GetInstances
            EXECUTE xp_regread
              @rootkey = 'HKEY_LOCAL_MACHINE',
              @key = 'SOFTWARE\Microsoft\Microsoft SQL Server',
              @value_name = 'InstalledInstances'

            --Select InstanceNames from @GetInstances 
            --Select * 
            --from #GetInstances 


            DECLARE the_ins CURSOR STATIC LOCAL FORWARD_ONLY READ_ONLY 
            FOR
            SELECT s.InstanceNames
            from #GetInstances s


            OPEN the_ins;
            FETCH NEXT FROM the_ins INTO @instancename;

            WHILE @@FETCH_STATUS = 0
            BEGIN
            ----------------------------------------------------------------

                                    If @instancename = 'MSSQLSERVER'
                                            set @namedinstanceind = 'n'
                                    Else
                                    Begin
                                            set @namedinstanceind = 'y'
                                    End

                                    -- sql server 
                                    Set @registrypath = 'system\currentcontrolset\services\'
                                    If @namedinstanceind = 'n'
                                        set @registrypath = @registrypath + 'mssqlserver'
                                    Else
                                        set @registrypath = @registrypath + 'mssql$' + @instancename

                                    Insert #registryentry 
                                    Exec master..xp_regread 'hkey_local_machine' , @registrypath,'objectname'
                                    Select @sqlserversvcaccount = data from #registryentry
                                    Delete from #registryentry


                                    Insert #registryentry 
                                    Exec master..xp_regread 'hkey_local_machine' , @registrypath,'start'
                                    Select @sqlserverstartup = data from #registryentry
                                    Delete from #registryentry

                                    -- sql agent
                                    Set @registrypath = 'system\currentcontrolset\services\'
                                    If @namedinstanceind = 'n'
                                    set @registrypath = @registrypath + 'sqlserveragent'
                                    Else
                                    set @registrypath = @registrypath + 'sqlagent$' + @instancename

                                    Insert #registryentry 
                                    Exec master..xp_regread 'hkey_local_machine' , @registrypath,'objectname'
                                    Select @sqlagentsvcaccount = data from #registryentry
                                    Delete from #registryentry


                                    Insert #registryentry 
                                    Exec master..xp_regread 'hkey_local_machine' , @registrypath,'start'
                                    Select @sqlagentstartup = data from #registryentry
                                    Delete from #registryentry

                                    -- distributed transaction coordinator
                                    Set @registrypath = 'system\currentcontrolset\services\msdtc'
                                    Insert #registryentry 
                                    Exec master..xp_regread 'hkey_local_machine' , @registrypath,'objectname'
                                    Select @dtcsvcaccount = data from #registryentry
                                    Delete from #registryentry


                                    Insert #registryentry 
                                    Exec master..xp_regread 'hkey_local_machine' , @registrypath,'start'
                                    Select @dtcstartup = data from #registryentry
                                    Delete from #registryentry


                                    -- search (sql server )
                                    Set @registrypath = 'system\currentcontrolset\services\mssearch'
                                    Insert #registryentry 
                                    Exec master..xp_regread 'hkey_local_machine' , @registrypath,'objectname'
                                    Select @sqlsearchsvcaccount = data from #registryentry
                                    Delete from #registryentry
                                    Insert #registryentry 
                                    Exec master..xp_regread 'hkey_local_machine' , @registrypath,'start'
                                    Select @sqlsearchstartup = data from #registryentry
                                    Delete from #registryentry

            ----------------------------------------------------------------
                                    insert into #Radhe
                                    Select cast( serverproperty ('machinename') as nvarchar(128) ) as machinename
                                    , @instancename as instancename
                                    , @sqlserversvcaccount as sqlserversvcaccount
                                    , @sqlagentsvcaccount as sqlagentsvcaccount
                                    , @dtcsvcaccount as dtcsvcaccount
                                    , @sqlsearchsvcaccount as sqlsearchsvcaccount
                                    , @sqlserverstartup as sqlserverstartup
                                    , @sqlagentstartup as sqlagentstartup
                                    , @dtcstartup as dtcstartup
                                    , @sqlsearchstartup as sqlsearchstartup 


                FETCH NEXT FROM the_ins INTO @instancename; 

            END

            CLOSE the_ins;
            DEALLOCATE the_ins;


            select * from #Radhe

END TRY

BEGIN CATCH

            ------------------------------------------- 
            BEGIN TRY
                --clean it up    
                CLOSE THE_DBS;
                DEALLOCATE THE_DBS;
            END TRY
            BEGIN CATCH
                --do nothing
            END CATCH
            ------------------------------------------- 

    DECLARE @ERRORMESSAGE    NVARCHAR(512),
            @ERRORSEVERITY   INT,
            @ERRORNUMBER     INT,
            @ERRORSTATE      INT,
            @ERRORPROCEDURE  SYSNAME,
            @ERRORLINE       INT,
            @XASTATE         INT

    SELECT
            @ERRORMESSAGE     = ERROR_MESSAGE(),
            @ERRORSEVERITY    = ERROR_SEVERITY(),
            @ERRORNUMBER      = ERROR_NUMBER(),
            @ERRORSTATE       = ERROR_STATE(),
            @ERRORPROCEDURE   = ERROR_PROCEDURE(),
            @ERRORLINE        = ERROR_LINE()

    SET @ERRORMESSAGE = 
    (
    SELECT                    CHAR(13) +
      'Message:'         +    SPACE(1) + @ErrorMessage                           + SPACE(2) + CHAR(13) +
      'Error:'           +    SPACE(1) + CONVERT(NVARCHAR(50),@ErrorNumber)      + SPACE(1) + CHAR(13) +
      'Severity:'        +    SPACE(1) + CONVERT(NVARCHAR(50),@ErrorSeverity)    + SPACE(1) + CHAR(13) +
      'State:'           +    SPACE(1) + CONVERT(NVARCHAR(50),@ErrorState)       + SPACE(1) + CHAR(13) +
      'Routine_Name:'    +    SPACE(1) + COALESCE(@ErrorProcedure,'')            + SPACE(1) + CHAR(13) +
      'Line:'            +    SPACE(1) + CONVERT(NVARCHAR(50),@ErrorLine)        + SPACE(1) + CHAR(13) +
      'Executed As:'     +    SPACE(1) + SYSTEM_USER + SPACE(1)                             + CHAR(13) +
      'Database:'        +    SPACE(1) + DB_NAME() + SPACE(1)                               + CHAR(13) +
      'OSTime:'          +    SPACE(1) + CONVERT(NVARCHAR(25),CURRENT_TIMESTAMP,121)        + CHAR(13) 
    )

    --We can also save the error details to a table for later reference here.
    RAISERROR (@ERRORMESSAGE,16,1)

END CATCH
