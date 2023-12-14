#  (c) Wherescape Inc 2020. WhereScape Inc permits you to copy this Module solely for use with the RED software, and to modify this Module 
#  for the purposes of using that modified Module with the RED software, but does not permit copying or modification for any other purpose.            
#==============================================================================
# Module Name      :    WslPowershellCommon
# DBMS Name        :    Generic for all databases
# Description      :    Generic powershell functions module used by many
#                       different templates, scripts and database specific
#                       modules
# Author           :    WhereScape Inc
#==============================================================================
# Notes / History
#  TK:  1.0.0   2017-05-17   First Version
#  JML: 3.0.0   2018-10-29   Extended odbc timeout functionality to Get-OdbcDumpSource
#  JML: 3.0.1   2018-11-05   Added escaping logic for enclosing char in Get-OdbcDumpSource
#  TK:  3.0.2   2018-11-07   Added logic to prevent ODBC command timeouts in api calls
#  JML: 3.0.3   2018-11-07   Fix for escaping logic issue in Get-OdbcDumpSource
#  TK:  3.0.4   2018-11-08   Fix exception thrown by Get-OdbcDumpSource when escape character is not set
#  JML: 3.0.5   2018-11-09   Changes in Get-OdbcDumpSource to support UTF-16
#  JML: 3.0.6   2018-12-10   Corrected paramater declaration in WsWrkError to have correct datatype
#  GH:  3.0.7   2019-01-14   Allowing for null character in GetDataToFile
#  JML: 3.0.8   2019-03-12   Changes to use common module on 64bit machines
#  JML: 3.0.9   2019-03-25   Slight change how 32-bitness is handled
#  PM:  3.1.0   2020-08-18   Catch error "Arithmetic operation resulted in an overflow" and continue with -ve max int returned to flag operator that the row count can't be relied on for this task
#  MME: 3.1.1   2021-03-04   Fully qualified procedure calls to work with PG metadata. Added Export objects to Get-ExtendedProperty function.
#
#==============================================================================

<#
.DESCRIPTION
Wrapper function for the Ws_Connect_Replace API procedure.
For more information about usage or return values, refer to the Callable Routines API section of the user guide.
.EXAMPLE 
Ws_Connect_Replace -SourceConnection "Sales2" -TargetConnection "Sales"
#>
function Ws_Connect_Replace {
    param (
        $SourceConnection = [DBNull]::Value,
        $TargetConnection = [DBNull]::Value
    )

    $sql = "{ call ${env:WSL_META_SCHEMA}Ws_Connect_Replace (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?) }"
    
    $redOdbc = New-Object System.Data.Odbc.OdbcConnection
    $redOdbc.ConnectionString = "DSN=${env:WSL_META_DSN}"
    if( ! [string]::IsNullOrEmpty(${env:WSL_META_USER})) { $redOdbc.ConnectionString += ";UID=${env:WSL_META_USER}" }
    if( ! [string]::IsNullOrEmpty(${env:WSL_META_PWD}))  { $redOdbc.ConnectionString += ";PWD=${env:WSL_META_PWD}" }
    
    $command = New-Object System.Data.Odbc.OdbcCommand($sql,$redOdbc)
    $command.CommandTimeout = 0
    $command.CommandType = "StoredProcedure"
    $param = [System.Data.Odbc.OdbcParameter]
    [void]$command.Parameters.Add($(New-Object $param("@p_sequence","Int",0,"Input",$true,0,0,"","Current",${env:WSL_SEQUENCE})))
    [void]$command.Parameters.Add($(New-Object $param("@p_job_name","Varchar",64,"Input",$true,0,0,"","Current",${env:WSL_JOB_NAME})))
    [void]$command.Parameters.Add($(New-Object $param("@p_task_name","Varchar",64,"Input",$true,0,0,"","Current",${env:WSL_TASK_NAME})))
    [void]$command.Parameters.Add($(New-Object $param("@p_job_id","Int",0,"Input",$true,0,0,"","Current",${env:WSL_JOB_KEY})))
    [void]$command.Parameters.Add($(New-Object $param("@p_task_id","Int",0,"Input",$true,0,0,"","Current",${env:WSL_TASK_KEY})))
    [void]$command.Parameters.Add($(New-Object $param("@p_action","Varchar",64,"Input",$true,0,0,"","Current","REPLACE")))
    [void]$command.Parameters.Add($(New-Object $param("@p_source","Varchar",64,"Input",$true,0,0,"","Current",$SourceConnection)))
    [void]$command.Parameters.Add($(New-Object $param("@p_target","Varchar",64,"Input",$true,0,0,"","Current",$TargetConnection)))
    [void]$command.Parameters.Add($(New-Object $param("@p_return_code","Varchar",1,"Output",$true,0,0,"","Current",[DBNull]::Value)))
    [void]$command.Parameters.Add($(New-Object $param("@p_return_msg","Varchar",256,"Output",$true,0,0,"","Current",[DBNull]::Value)))
    [void]$command.Parameters.Add($(New-Object $param("@p_result","Int",0,"Output",$true,0,0,"","Current",[DBNull]::Value)))

    $redOdbc.Open()
    [void]$command.ExecuteNonQuery()
    $redOdbc.Close()

    return , $command.Parameters["@p_return_code"].Value, $command.Parameters["@p_return_msg"].Value, $command.Parameters["@p_result"].Value
}

<#
.DESCRIPTION
Wrapper function for the Ws_Job_Abort API procedure.
For more information about usage or return values, refer to the Callable Routines API section of the user guide.
.EXAMPLE 
Ws_Job_Abort -JobName "DailyUpdate" -JobMsg "Job aborted by Ws_Job_Abort API."
#>
function Ws_Job_Abort {
    param (
        $JobName = [DBNull]::Value,
        $Sequence = [DBNull]::Value,
        $JobMsg = [DBNull]::Value
    )

    $sql = "{ call ${env:WSL_META_SCHEMA}Ws_Job_Abort (?, ?, ?) }"

    $redOdbc = New-Object System.Data.Odbc.OdbcConnection
    $redOdbc.ConnectionString = "DSN=${env:WSL_META_DSN}"
    if( ! [string]::IsNullOrEmpty(${env:WSL_META_USER})) { $redOdbc.ConnectionString += ";UID=${env:WSL_META_USER}" }
    if( ! [string]::IsNullOrEmpty(${env:WSL_META_PWD}))  { $redOdbc.ConnectionString += ";PWD=${env:WSL_META_PWD}" }
    
    $command = New-Object System.Data.Odbc.OdbcCommand($sql,$redOdbc)
    $command.CommandTimeout = 0
    $command.CommandType = "StoredProcedure"
    $param = [System.Data.Odbc.OdbcParameter]
    [void]$command.Parameters.Add($(New-Object $param("@p_job_name","Varchar",64,"Input",$true,0,0,"","Current",$JobName)))
    [void]$command.Parameters.Add($(New-Object $param("@p_job_sequence","Int",0,"Input",$true,0,0,"","Current",$Sequence)))
    [void]$command.Parameters.Add($(New-Object $param("@p_job_msg","Varchar",256,"Input",$true,0,0,"","Current",$JobMsg)))

    $redOdbc.Open()
    [void]$command.ExecuteNonQuery()
    $redOdbc.Close()
}

<#
.DESCRIPTION
Wrapper function for the Ws_Job_Clear_Archive API procedure.
For more information about usage or return values, refer to the Callable Routines API section of the user guide.
.EXAMPLE 
Ws_Job_Clear_Archive -DayCount 10 -Job "DailyUpdate"
Ws_Job_Clear_Archive -Options "TRUNCATE"
#>
function Ws_Job_Clear_Archive {
    param(
        $DayCount = [DBNull]::Value,
        $Job = [DBNull]::Value,
        $Options = [DBNull]::Value
    )

    $sql = "{ call ${env:WSL_META_SCHEMA}Ws_Job_Clear_Archive (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?) }"
    
    $redOdbc = New-Object System.Data.Odbc.OdbcConnection
    $redOdbc.ConnectionString = "DSN=${env:WSL_META_DSN}"
    if( ! [string]::IsNullOrEmpty(${env:WSL_META_USER})) { $redOdbc.ConnectionString += ";UID=${env:WSL_META_USER}" }
    if( ! [string]::IsNullOrEmpty(${env:WSL_META_PWD}))  { $redOdbc.ConnectionString += ";PWD=${env:WSL_META_PWD}" }
    
    $command = New-Object System.Data.Odbc.OdbcCommand($sql,$redOdbc)
    $command.CommandTimeout = 0
    $command.CommandType = "StoredProcedure"
    $param = [System.Data.Odbc.OdbcParameter]
    [void]$command.Parameters.Add($(New-Object $param("@p_sequence","Int",0,"Input",$true,0,0,"","Current",${env:WSL_SEQUENCE})))
    [void]$command.Parameters.Add($(New-Object $param("@p_job_name","Varchar",64,"Input",$true,0,0,"","Current",${env:WSL_JOB_NAME})))
    [void]$command.Parameters.Add($(New-Object $param("@p_task_name","Varchar",64,"Input",$true,0,0,"","Current",${env:WSL_TASK_NAME})))
    [void]$command.Parameters.Add($(New-Object $param("@p_job_id","Int",0,"Input",$true,0,0,"","Current",${env:WSL_JOB_KEY})))
    [void]$command.Parameters.Add($(New-Object $param("@p_task_id","Int",0,"Input",$true,0,0,"","Current",${env:WSL_TASK_KEY})))
    [void]$command.Parameters.Add($(New-Object $param("@p_day_count","Varchar",64,"Input",$true,0,0,"","Current",$DayCount)))
    [void]$command.Parameters.Add($(New-Object $param("@p_job","Varchar",64,"Input",$true,0,0,"","Current",$Job)))
    [void]$command.Parameters.Add($(New-Object $param("@p_options","Varchar",256,"Input",$true,0,0,"","Current",$Options)))
    [void]$command.Parameters.Add($(New-Object $param("@p_return_code","Varchar",1,"Output",$true,0,0,"","Current",[DBNull]::Value)))
    [void]$command.Parameters.Add($(New-Object $param("@p_return_msg","Varchar",256,"Output",$true,0,0,"","Current",[DBNull]::Value)))
    [void]$command.Parameters.Add($(New-Object $param("@p_result","Int",0,"Output",$true,0,0,"","Current",[DBNull]::Value)))

    $redOdbc.Open()
    [void]$command.ExecuteNonQuery()
    $redOdbc.Close()

    return , $command.Parameters["@p_return_code"].Value, $command.Parameters["@p_return_msg"].Value, $command.Parameters["@p_result"].Value
}

<#
.DESCRIPTION
Wrapper function for the Ws_Job_Clear_Logs API procedure.
For more information about usage or return values, refer to the Callable Routines API section of the user guide.
.EXAMPLE 
Ws_Job_Clear_Logs -JobToClean "DailyUpdate" -KeepCount 10
#>
function Ws_Job_Clear_Logs {
    param(
        $JobToClean = [DBNull]::Value,
        $KeepCount = [DBNull]::Value
    )

    $sql = "{ call ${env:WSL_META_SCHEMA}Ws_Job_Clear_Logs (?, ?, ?, ?, ?, ?, ?, ?, ?, ?) }"
    
    $redOdbc = New-Object System.Data.Odbc.OdbcConnection
    $redOdbc.ConnectionString = "DSN=${env:WSL_META_DSN}"
    if( ! [string]::IsNullOrEmpty(${env:WSL_META_USER})) { $redOdbc.ConnectionString += ";UID=${env:WSL_META_USER}" }
    if( ! [string]::IsNullOrEmpty(${env:WSL_META_PWD}))  { $redOdbc.ConnectionString += ";PWD=${env:WSL_META_PWD}" }
    
    $command = New-Object System.Data.Odbc.OdbcCommand($sql,$redOdbc)
    $command.CommandTimeout = 0
    $command.CommandType = "StoredProcedure"
    $param = [System.Data.Odbc.OdbcParameter]
    [void]$command.Parameters.Add($(New-Object $param("@p_sequence","Int",0,"Input",$true,0,0,"","Current",${env:WSL_SEQUENCE})))
    [void]$command.Parameters.Add($(New-Object $param("@p_job_name","Varchar",64,"Input",$true,0,0,"","Current",${env:WSL_JOB_NAME})))
    [void]$command.Parameters.Add($(New-Object $param("@p_task_name","Varchar",64,"Input",$true,0,0,"","Current",${env:WSL_TASK_NAME})))
    [void]$command.Parameters.Add($(New-Object $param("@p_job_id","Int",0,"Input",$true,0,0,"","Current",${env:WSL_JOB_KEY})))
    [void]$command.Parameters.Add($(New-Object $param("@p_task_id","Int",0,"Input",$true,0,0,"","Current",${env:WSL_TASK_KEY})))
    [void]$command.Parameters.Add($(New-Object $param("@p_job_to_clean","Varchar",64,"Input",$true,0,0,"","Current",$JobToClean)))
    [void]$command.Parameters.Add($(New-Object $param("@p_keep_count","Int",0,"Input",$true,0,0,"","Current",$KeepCount)))
    [void]$command.Parameters.Add($(New-Object $param("@p_return_code","Varchar",1,"Output",$true,0,0,"","Current",[DBNull]::Value)))
    [void]$command.Parameters.Add($(New-Object $param("@p_return_msg","Varchar",256,"Output",$true,0,0,"","Current",[DBNull]::Value)))
    [void]$command.Parameters.Add($(New-Object $param("@p_result","Int",0,"Output",$true,0,0,"","Current",[DBNull]::Value)))

    $redOdbc.Open()
    [void]$command.ExecuteNonQuery()
    $redOdbc.Close()

    return , $command.Parameters["@p_return_code"].Value, $command.Parameters["@p_return_msg"].Value, $command.Parameters["@p_result"].Value
}

<#
.DESCRIPTION
Wrapper function for the Ws_Job_Clear_Logs_By_Date API procedure.
For more information about usage or return values, refer to the Callable Routines API section of the user guide.
.EXAMPLE 
Ws_Job_Clear_Logs_By_Date -JobToClean "DailyUpdate" -DayCount 10
#>
function Ws_Job_Clear_Logs_By_Date {
    param(
        $JobToClean = [DBNull]::Value,
        $DayCount = [DBNull]::Value
    )

    $sql = "{ call ${env:WSL_META_SCHEMA}Ws_Job_Clear_Logs_By_Date (?, ?, ?, ?, ?, ?, ?, ?, ?, ?) }"
    
    $redOdbc = New-Object System.Data.Odbc.OdbcConnection
    $redOdbc.ConnectionString = "DSN=${env:WSL_META_DSN}"
    if( ! [string]::IsNullOrEmpty(${env:WSL_META_USER})) { $redOdbc.ConnectionString += ";UID=${env:WSL_META_USER}" }
    if( ! [string]::IsNullOrEmpty(${env:WSL_META_PWD}))  { $redOdbc.ConnectionString += ";PWD=${env:WSL_META_PWD}" }
    
    $command = New-Object System.Data.Odbc.OdbcCommand($sql,$redOdbc)
    $command.CommandTimeout = 0
    $command.CommandType = "StoredProcedure"
    $param = [System.Data.Odbc.OdbcParameter]
    [void]$command.Parameters.Add($(New-Object $param("@p_sequence","Int",0,"Input",$true,0,0,"","Current",${env:WSL_SEQUENCE})))
    [void]$command.Parameters.Add($(New-Object $param("@p_job_name","Varchar",64,"Input",$true,0,0,"","Current",${env:WSL_JOB_NAME})))
    [void]$command.Parameters.Add($(New-Object $param("@p_task_name","Varchar",64,"Input",$true,0,0,"","Current",${env:WSL_TASK_NAME})))
    [void]$command.Parameters.Add($(New-Object $param("@p_job_id","Int",0,"Input",$true,0,0,"","Current",${env:WSL_JOB_KEY})))
    [void]$command.Parameters.Add($(New-Object $param("@p_task_id","Int",0,"Input",$true,0,0,"","Current",${env:WSL_TASK_KEY})))
    [void]$command.Parameters.Add($(New-Object $param("@p_job_to_clean","Varchar",64,"Input",$true,0,0,"","Current",$JobToClean)))
    [void]$command.Parameters.Add($(New-Object $param("@p_day_count","Int",0,"Input",$true,0,0,"","Current",$DayCount)))
    [void]$command.Parameters.Add($(New-Object $param("@p_return_code","Varchar",1,"Output",$true,0,0,"","Current",[DBNull]::Value)))
    [void]$command.Parameters.Add($(New-Object $param("@p_return_msg","Varchar",256,"Output",$true,0,0,"","Current",[DBNull]::Value)))
    [void]$command.Parameters.Add($(New-Object $param("@p_result","Int",0,"Output",$true,0,0,"","Current",[DBNull]::Value)))

    $redOdbc.Open()
    [void]$command.ExecuteNonQuery()
    $redOdbc.Close()

    return , $command.Parameters["@p_return_code"].Value, $command.Parameters["@p_return_msg"].Value, $command.Parameters["@p_result"].Value
}

<#
.DESCRIPTION
Wrapper function for the Ws_Job_Create API procedure.
For more information about usage or return values, refer to the Callable Routines API section of the user guide.
.EXAMPLE 
Ws_Job_Create -TemplateJob "DailyUpdate" -NewJob "DailyUpdate_${env:WSL_SEQUENCE}" -State "ONCE" -Threads 5
#>
function Ws_Job_Create {
    param(
        $TemplateJob = [DBNull]::Value,
        $NewJob = [DBNull]::Value,
        $Description = [DBNull]::Value,
        $State = [DBNull]::Value,
        $Threads = [DBNull]::Value,
        $Scheduler = [DBNull]::Value,
        $Logs = [DBNull]::Value,
        $SuccessCmd = [DBNull]::Value,
        $FailureCmd = [DBNull]::Value
    )

    $sql = "{ call ${env:WSL_META_SCHEMA}Ws_Job_Create (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, ?, ?, ?) }"
    
    $redOdbc = New-Object System.Data.Odbc.OdbcConnection
    $redOdbc.ConnectionString = "DSN=${env:WSL_META_DSN}"
    if( ! [string]::IsNullOrEmpty(${env:WSL_META_USER})) { $redOdbc.ConnectionString += ";UID=${env:WSL_META_USER}" }
    if( ! [string]::IsNullOrEmpty(${env:WSL_META_PWD}))  { $redOdbc.ConnectionString += ";PWD=${env:WSL_META_PWD}" }
    
    $command = New-Object System.Data.Odbc.OdbcCommand($sql,$redOdbc)
    $command.CommandTimeout = 0
    $command.CommandType = "StoredProcedure"
    $param = [System.Data.Odbc.OdbcParameter]
    [void]$command.Parameters.Add($(New-Object $param("@p_sequence","Int",0,"Input",$true,0,0,"","Current",${env:WSL_SEQUENCE})))
    [void]$command.Parameters.Add($(New-Object $param("@p_job_name","Varchar",64,"Input",$true,0,0,"","Current",${env:WSL_JOB_NAME})))
    [void]$command.Parameters.Add($(New-Object $param("@p_task_name","Varchar",64,"Input",$true,0,0,"","Current",${env:WSL_TASK_NAME})))
    [void]$command.Parameters.Add($(New-Object $param("@p_job_id","Int",0,"Input",$true,0,0,"","Current",${env:WSL_JOB_KEY})))
    [void]$command.Parameters.Add($(New-Object $param("@p_task_id","Int",0,"Input",$true,0,0,"","Current",${env:WSL_TASK_KEY})))
    [void]$command.Parameters.Add($(New-Object $param("@p_template_job","Varchar",64,"Input",$true,0,0,"","Current",$TemplateJob)))
    [void]$command.Parameters.Add($(New-Object $param("@p_new_job","Varchar",64,"Input",$true,0,0,"","Current",$NewJob)))
    [void]$command.Parameters.Add($(New-Object $param("@p_description","Varchar",256,"Input",$true,0,0,"","Current",$Description)))
    [void]$command.Parameters.Add($(New-Object $param("@p_state","Varchar",64,"Input",$true,0,0,"","Current",$State)))
    [void]$command.Parameters.Add($(New-Object $param("@p_threads","Int",0,"Input",$true,0,0,"","Current",$Threads)))
    [void]$command.Parameters.Add($(New-Object $param("@p_scheduler","Varchar",64,"Input",$true,0,0,"","Current",$Scheduler)))
    [void]$command.Parameters.Add($(New-Object $param("@p_logs","Int",0,"Input",$true,0,0,"","Current",$Logs)))
    [void]$command.Parameters.Add($(New-Object $param("@p_okay","Varchar",256,"Input",$true,0,0,"","Current",$SuccessCmd)))
    [void]$command.Parameters.Add($(New-Object $param("@p_fail","Varchar",256,"Input",$true,0,0,"","Current",$FailureCmd)))
    [void]$command.Parameters.Add($(New-Object $param("@p_return_code","Varchar",1,"Output",$true,0,0,"","Current",[DBNull]::Value)))
    [void]$command.Parameters.Add($(New-Object $param("@p_return_msg","Varchar",256,"Output",$true,0,0,"","Current",[DBNull]::Value)))
    [void]$command.Parameters.Add($(New-Object $param("@p_result","Int",0,"Output",$true,0,0,"","Current",[DBNull]::Value)))

    $redOdbc.Open()
    [void]$command.ExecuteNonQuery()
    $redOdbc.Close()

    return , $command.Parameters["@p_return_code"].Value, $command.Parameters["@p_return_msg"].Value, $command.Parameters["@p_result"].Value
}

<#
.DESCRIPTION
Wrapper function for the Ws_Job_CreateWait API procedure.
For more information about usage or return values, refer to the Callable Routines API section of the user guide.
.EXAMPLE
Ws_Job_CreateWait -TemplateJob "DailyUpdate" -NewJob "DailyUpdate_${env:WSL_SEQUENCE}" -State "ONCE" -Threads 5 -ReleaseTime (Get-Date "2017-10-3").DateTime
#>
function Ws_Job_CreateWait {
    param(
        $TemplateJob = [DBNull]::Value,
        $NewJob = [DBNull]::Value,
        $Description = [DBNull]::Value,
        $State = [DBNull]::Value,
        $ReleaseTime = [DBNull]::Value,
        $Threads = [DBNull]::Value,
        $Scheduler = [DBNull]::Value,
        $Logs = [DBNull]::Value,
        $SuccessCmd = [DBNull]::Value,
        $FailureCmd = [DBNull]::Value
    )

    $sql = "{ call ${env:WSL_META_SCHEMA}Ws_Job_CreateWait (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, ?, ?, ?) }"
    
    $redOdbc = New-Object System.Data.Odbc.OdbcConnection
    $redOdbc.ConnectionString = "DSN=${env:WSL_META_DSN}"
    if( ! [string]::IsNullOrEmpty(${env:WSL_META_USER})) { $redOdbc.ConnectionString += ";UID=${env:WSL_META_USER}" }
    if( ! [string]::IsNullOrEmpty(${env:WSL_META_PWD}))  { $redOdbc.ConnectionString += ";PWD=${env:WSL_META_PWD}" }
    
    $command = New-Object System.Data.Odbc.OdbcCommand($sql,$redOdbc)
    $command.CommandTimeout = 0
    $command.CommandType = "StoredProcedure"
    $param = [System.Data.Odbc.OdbcParameter]
    [void]$command.Parameters.Add($(New-Object $param("@p_sequence","Int",0,"Input",$true,0,0,"","Current",${env:WSL_SEQUENCE})))
    [void]$command.Parameters.Add($(New-Object $param("@p_job_name","Varchar",64,"Input",$true,0,0,"","Current",${env:WSL_JOB_NAME})))
    [void]$command.Parameters.Add($(New-Object $param("@p_task_name","Varchar",64,"Input",$true,0,0,"","Current",${env:WSL_TASK_NAME})))
    [void]$command.Parameters.Add($(New-Object $param("@p_job_id","Int",0,"Input",$true,0,0,"","Current",${env:WSL_JOB_KEY})))
    [void]$command.Parameters.Add($(New-Object $param("@p_task_id","Int",0,"Input",$true,0,0,"","Current",${env:WSL_TASK_KEY})))
    [void]$command.Parameters.Add($(New-Object $param("@p_template_job","Varchar",64,"Input",$true,0,0,"","Current",$TemplateJob)))
    [void]$command.Parameters.Add($(New-Object $param("@p_new_job","Varchar",64,"Input",$true,0,0,"","Current",$NewJob)))
    [void]$command.Parameters.Add($(New-Object $param("@p_description","Varchar",256,"Input",$true,0,0,"","Current",$Description)))
    [void]$command.Parameters.Add($(New-Object $param("@p_state","Varchar",64,"Input",$true,0,0,"","Current",$State)))
    [void]$command.Parameters.Add($(New-Object $param("@p_state","Datetime",0,"Input",$true,0,0,"","Current",$ReleaseTime)))
    [void]$command.Parameters.Add($(New-Object $param("@p_threads","Int",0,"Input",$true,0,0,"","Current",$Threads)))
    [void]$command.Parameters.Add($(New-Object $param("@p_scheduler","Varchar",64,"Input",$true,0,0,"","Current",$Scheduler)))
    [void]$command.Parameters.Add($(New-Object $param("@p_logs","Int",0,"Input",$true,0,0,"","Current",$Logs)))
    [void]$command.Parameters.Add($(New-Object $param("@p_okay","Varchar",256,"Input",$true,0,0,"","Current",$SuccessCmd)))
    [void]$command.Parameters.Add($(New-Object $param("@p_fail","Varchar",256,"Input",$true,0,0,"","Current",$FailureCmd)))
    [void]$command.Parameters.Add($(New-Object $param("@p_return_code","Varchar",1,"Output",$true,0,0,"","Current",[DBNull]::Value)))
    [void]$command.Parameters.Add($(New-Object $param("@p_return_msg","Varchar",256,"Output",$true,0,0,"","Current",[DBNull]::Value)))
    [void]$command.Parameters.Add($(New-Object $param("@p_result","Int",0,"Output",$true,0,0,"","Current",[DBNull]::Value)))

    $redOdbc.Open()
    [void]$command.ExecuteNonQuery()
    $redOdbc.Close()

    return , $command.Parameters["@p_return_code"].Value, $command.Parameters["@p_return_msg"].Value, $command.Parameters["@p_result"].Value
}

<#
.DESCRIPTION
Wrapper function for the Ws_Job_Release API procedure.
For more information about usage or return values, refer to the Callable Routines API section of the user guide.
.EXAMPLE
Ws_Job_Release -ReleaseJob "DailyUpdate"
#>
function Ws_Job_Release {
    param(
        $ReleaseJob = [DBNull]::Value
    )

    $sql = "{ call ${env:WSL_META_SCHEMA}Ws_Job_Release (?, ?, ?, ?, ?, ?, ?, ?, ?) }"
    
    $redOdbc = New-Object System.Data.Odbc.OdbcConnection
    $redOdbc.ConnectionString = "DSN=${env:WSL_META_DSN}"
    if( ! [string]::IsNullOrEmpty(${env:WSL_META_USER})) { $redOdbc.ConnectionString += ";UID=${env:WSL_META_USER}" }
    if( ! [string]::IsNullOrEmpty(${env:WSL_META_PWD}))  { $redOdbc.ConnectionString += ";PWD=${env:WSL_META_PWD}" }
    
    $command = New-Object System.Data.Odbc.OdbcCommand($sql,$redOdbc)
    $command.CommandTimeout = 0
    $command.CommandType = "StoredProcedure"
    $param = [System.Data.Odbc.OdbcParameter]
    [void]$command.Parameters.Add($(New-Object $param("@p_sequence","Int",0,"Input",$true,0,0,"","Current",${env:WSL_SEQUENCE})))
    [void]$command.Parameters.Add($(New-Object $param("@p_job_name","Varchar",64,"Input",$true,0,0,"","Current",${env:WSL_JOB_NAME})))
    [void]$command.Parameters.Add($(New-Object $param("@p_task_name","Varchar",64,"Input",$true,0,0,"","Current",${env:WSL_TASK_NAME})))
    [void]$command.Parameters.Add($(New-Object $param("@p_job_id","Int",0,"Input",$true,0,0,"","Current",${env:WSL_JOB_KEY})))
    [void]$command.Parameters.Add($(New-Object $param("@p_task_id","Int",0,"Input",$true,0,0,"","Current",${env:WSL_TASK_KEY})))
    [void]$command.Parameters.Add($(New-Object $param("@p_release_job","Varchar",64,"Input",$true,0,0,"","Current",$ReleaseJob)))
    [void]$command.Parameters.Add($(New-Object $param("@p_return_code","Varchar",1,"Output",$true,0,0,"","Current",[DBNull]::Value)))
    [void]$command.Parameters.Add($(New-Object $param("@p_return_msg","Varchar",256,"Output",$true,0,0,"","Current",[DBNull]::Value)))
    [void]$command.Parameters.Add($(New-Object $param("@p_result","Int",0,"Output",$true,0,0,"","Current",[DBNull]::Value)))

    $redOdbc.Open()
    [void]$command.ExecuteNonQuery()
    $redOdbc.Close()

    return , $command.Parameters["@p_return_code"].Value, $command.Parameters["@p_return_msg"].Value, $command.Parameters["@p_result"].Value
}

<#
.DESCRIPTION
Wrapper function for the Ws_Job_Restart API procedure.
For more information about usage or return values, refer to the Callable Routines API section of the user guide.
.EXAMPLE
Ws_Job_Restart -RestartJob "DailyUpdate"
#>
function Ws_Job_Restart {
    param(
        $RestartJob = [DBNull]::Value
    )

    $sql = "{ call ${env:WSL_META_SCHEMA}Ws_Job_Restart (?, ?, ?, ?, ?, ?, ?, ?, ?) }"
    
    $redOdbc = New-Object System.Data.Odbc.OdbcConnection
    $redOdbc.ConnectionString = "DSN=${env:WSL_META_DSN}"
    if( ! [string]::IsNullOrEmpty(${env:WSL_META_USER})) { $redOdbc.ConnectionString += ";UID=${env:WSL_META_USER}" }
    if( ! [string]::IsNullOrEmpty(${env:WSL_META_PWD}))  { $redOdbc.ConnectionString += ";PWD=${env:WSL_META_PWD}" }
    
    $command = New-Object System.Data.Odbc.OdbcCommand($sql,$redOdbc)
    $command.CommandTimeout = 0
    $command.CommandType = "StoredProcedure"
    $param = [System.Data.Odbc.OdbcParameter]
    [void]$command.Parameters.Add($(New-Object $param("@p_sequence","Int",0,"Input",$true,0,0,"","Current",${env:WSL_SEQUENCE})))
    [void]$command.Parameters.Add($(New-Object $param("@p_job_name","Varchar",64,"Input",$true,0,0,"","Current",${env:WSL_JOB_NAME})))
    [void]$command.Parameters.Add($(New-Object $param("@p_task_name","Varchar",64,"Input",$true,0,0,"","Current",${env:WSL_TASK_NAME})))
    [void]$command.Parameters.Add($(New-Object $param("@p_job_id","Int",0,"Input",$true,0,0,"","Current",${env:WSL_JOB_KEY})))
    [void]$command.Parameters.Add($(New-Object $param("@p_task_id","Int",0,"Input",$true,0,0,"","Current",${env:WSL_TASK_KEY})))
    [void]$command.Parameters.Add($(New-Object $param("@p_release_job","Varchar",64,"Input",$true,0,0,"","Current",$RestartJob)))
    [void]$command.Parameters.Add($(New-Object $param("@p_return_code","Varchar",1,"Output",$true,0,0,"","Current",[DBNull]::Value)))
    [void]$command.Parameters.Add($(New-Object $param("@p_return_msg","Varchar",256,"Output",$true,0,0,"","Current",[DBNull]::Value)))
    [void]$command.Parameters.Add($(New-Object $param("@p_result","Int",0,"Output",$true,0,0,"","Current",[DBNull]::Value)))

    $redOdbc.Open()
    [void]$command.ExecuteNonQuery()
    $redOdbc.Close()

    return , $command.Parameters["@p_return_code"].Value, $command.Parameters["@p_return_msg"].Value, $command.Parameters["@p_result"].Value
}

<#
.DESCRIPTION
Wrapper function for the Ws_Job_Schedule API procedure.
For more information about usage or return values, refer to the Callable Routines API section of the user guide.
.EXAMPLE
Ws_Job_Schedule -ReleaseJob "DailyUpdate" -ReleaseTime (Get-Date "2017-10-3 19:30").DateTime
#>
function Ws_Job_Schedule {
    param(
        $ReleaseJob = [DBNull]::Value,
        $ReleaseTime = [DBNull]::Value
    )

    $sql = "{ call ${env:WSL_META_SCHEMA}Ws_Job_Schedule (?, ?, ?, ?, ?, ?, ?, ?, ?, ?) }"
    
    $redOdbc = New-Object System.Data.Odbc.OdbcConnection
    $redOdbc.ConnectionString = "DSN=${env:WSL_META_DSN}"
    if( ! [string]::IsNullOrEmpty(${env:WSL_META_USER})) { $redOdbc.ConnectionString += ";UID=${env:WSL_META_USER}" }
    if( ! [string]::IsNullOrEmpty(${env:WSL_META_PWD}))  { $redOdbc.ConnectionString += ";PWD=${env:WSL_META_PWD}" }
    
    $command = New-Object System.Data.Odbc.OdbcCommand($sql,$redOdbc)
    $command.CommandTimeout = 0
    $command.CommandType = "StoredProcedure"
    $param = [System.Data.Odbc.OdbcParameter]
    [void]$command.Parameters.Add($(New-Object $param("@p_sequence","Int",0,"Input",$true,0,0,"","Current",${env:WSL_SEQUENCE})))
    [void]$command.Parameters.Add($(New-Object $param("@p_job_name","Varchar",64,"Input",$true,0,0,"","Current",${env:WSL_JOB_NAME})))
    [void]$command.Parameters.Add($(New-Object $param("@p_task_name","Varchar",64,"Input",$true,0,0,"","Current",${env:WSL_TASK_NAME})))
    [void]$command.Parameters.Add($(New-Object $param("@p_job_id","Int",0,"Input",$true,0,0,"","Current",${env:WSL_JOB_KEY})))
    [void]$command.Parameters.Add($(New-Object $param("@p_task_id","Int",0,"Input",$true,0,0,"","Current",${env:WSL_TASK_KEY})))
    [void]$command.Parameters.Add($(New-Object $param("@p_release_job","Varchar",64,"Input",$true,0,0,"","Current",$ReleaseJob)))
    [void]$command.Parameters.Add($(New-Object $param("@p_release_job","Datetime",0,"Input",$true,0,0,"","Current",$ReleaseTime)))
    [void]$command.Parameters.Add($(New-Object $param("@p_return_code","Varchar",1,"Output",$true,0,0,"","Current",[DBNull]::Value)))
    [void]$command.Parameters.Add($(New-Object $param("@p_return_msg","Varchar",256,"Output",$true,0,0,"","Current",[DBNull]::Value)))
    [void]$command.Parameters.Add($(New-Object $param("@p_result","Int",0,"Output",$true,0,0,"","Current",[DBNull]::Value)))

    $redOdbc.Open()
    [void]$command.ExecuteNonQuery()
    $redOdbc.Close()

    return , $command.Parameters["@p_return_code"].Value, $command.Parameters["@p_return_msg"].Value, $command.Parameters["@p_result"].Value
}

<#
.DESCRIPTION
Wrapper function for the Ws_Job_Status API procedure.
For more information about usage or return values, refer to the Callable Routines API section of the user guide.
.EXAMPLE
Ws_Job_Status -CheckJob "DailyUpdate" -StartedInLastMins 120
Ws_Job_Status -CheckJob "DailyUpdate" -StartedAfterDt (Get-Date).AddHours(-2).DateTime
#>
function Ws_Job_Status {
    param(
        $CheckSequence = [DBNull]::Value,
        $CheckJob = [DBNull]::Value,
        $StartedInLastMins = [DBNull]::Value,
        $StartedAfterDt = [DBNull]::Value
    )

    $sql = "{ call ${env:WSL_META_SCHEMA}Ws_Job_Status (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?) }"
    
    $redOdbc = New-Object System.Data.Odbc.OdbcConnection
    $redOdbc.ConnectionString = "DSN=${env:WSL_META_DSN}"
    if( ! [string]::IsNullOrEmpty(${env:WSL_META_USER})) { $redOdbc.ConnectionString += ";UID=${env:WSL_META_USER}" }
    if( ! [string]::IsNullOrEmpty(${env:WSL_META_PWD}))  { $redOdbc.ConnectionString += ";PWD=${env:WSL_META_PWD}" }
    
    $command = New-Object System.Data.Odbc.OdbcCommand($sql,$redOdbc)
    $command.CommandTimeout = 0
    $command.CommandType = "StoredProcedure"
    $param = [System.Data.Odbc.OdbcParameter]
    [void]$command.Parameters.Add($(New-Object $param("@p_sequence","Int",0,"Input",$true,0,0,"","Current",${env:WSL_SEQUENCE})))
    [void]$command.Parameters.Add($(New-Object $param("@p_job_name","Varchar",64,"Input",$true,0,0,"","Current",${env:WSL_JOB_NAME})))
    [void]$command.Parameters.Add($(New-Object $param("@p_task_name","Varchar",64,"Input",$true,0,0,"","Current",${env:WSL_TASK_NAME})))
    [void]$command.Parameters.Add($(New-Object $param("@p_job_id","Int",0,"Input",$true,0,0,"","Current",${env:WSL_JOB_KEY})))
    [void]$command.Parameters.Add($(New-Object $param("@p_task_id","Int",0,"Input",$true,0,0,"","Current",${env:WSL_TASK_KEY})))
    [void]$command.Parameters.Add($(New-Object $param("@p_check_sequence","Int",0,"Input",$true,0,0,"","Current",$CheckSequence)))
    [void]$command.Parameters.Add($(New-Object $param("@p_check_job","Varchar",64,"Input",$true,0,0,"","Current",$CheckJob)))
    [void]$command.Parameters.Add($(New-Object $param("@p_started_in_last_mi","Int",0,"Input",$true,0,0,"","Current",$StartedInLastMins)))
    [void]$command.Parameters.Add($(New-Object $param("@p_started_after_dt","Datetime",0,"Input",$true,0,0,"","Current",$StartedAfterDt)))
    [void]$command.Parameters.Add($(New-Object $param("@p_return_code","Varchar",1,"Output",$true,0,0,"","Current",[DBNull]::Value)))
    [void]$command.Parameters.Add($(New-Object $param("@p_return_msg","Varchar",256,"Output",$true,0,0,"","Current",[DBNull]::Value)))
    [void]$command.Parameters.Add($(New-Object $param("@p_result","Int",0,"Output",$true,0,0,"","Current",[DBNull]::Value)))
    [void]$command.Parameters.Add($(New-Object $param("@p_job_status_simple","Varchar",1,"Output",$true,0,0,"","Current",[DBNull]::Value)))
    [void]$command.Parameters.Add($(New-Object $param("@p_job_status_standard","Varchar",1,"Output",$true,0,0,"","Current",[DBNull]::Value)))
    [void]$command.Parameters.Add($(New-Object $param("@p_job_status_enhanced","Varchar",1,"Output",$true,0,0,"","Current",[DBNull]::Value)))

    $redOdbc.Open()
    [void]$command.ExecuteNonQuery()
    $redOdbc.Close()

    return , $command.Parameters["@p_return_code"].Value, $command.Parameters["@p_return_msg"].Value, $command.Parameters["@p_result"].Value, 
        $command.Parameters["@p_job_status_simple"].Value, $command.Parameters["@p_job_status_standard"].Value, $command.Parameters["@p_job_status_enhanced"].Value
}

<#
.DESCRIPTION
Wrapper function for the Ws_Load_Change API procedure.
For more information about usage or return values, refer to the Callable Routines API section of the user guide.
.EXAMPLE
Ws_Load_Change -Action "SCHEMA" -Table "load_customers" -NewValue "site2"
Ws_Load_Change -Action "CONNECTION" -Table "load_customers" -NewValue "Sales2"
#>
function Ws_Load_Change {
    param (
        $Action = [DBNull]::Value,
        $Table = [DBNull]::Value,
        $NewValue = [DBNull]::Value
    )

    $sql = "{ call ${env:WSL_META_SCHEMA}Ws_Load_Change (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?) }"
    
    $redOdbc = New-Object System.Data.Odbc.OdbcConnection
    $redOdbc.ConnectionString = "DSN=${env:WSL_META_DSN}"
    if( ! [string]::IsNullOrEmpty(${env:WSL_META_USER})) { $redOdbc.ConnectionString += ";UID=${env:WSL_META_USER}" }
    if( ! [string]::IsNullOrEmpty(${env:WSL_META_PWD}))  { $redOdbc.ConnectionString += ";PWD=${env:WSL_META_PWD}" }
    
    $command = New-Object System.Data.Odbc.OdbcCommand($sql,$redOdbc)
    $command.CommandTimeout = 0
    $command.CommandType = "StoredProcedure"
    $param = [System.Data.Odbc.OdbcParameter]
    [void]$command.Parameters.Add($(New-Object $param("@p_sequence","Int",0,"Input",$true,0,0,"","Current",${env:WSL_SEQUENCE})))
    [void]$command.Parameters.Add($(New-Object $param("@p_job_name","Varchar",64,"Input",$true,0,0,"","Current",${env:WSL_JOB_NAME})))
    [void]$command.Parameters.Add($(New-Object $param("@p_task_name","Varchar",64,"Input",$true,0,0,"","Current",${env:WSL_TASK_NAME})))
    [void]$command.Parameters.Add($(New-Object $param("@p_job_id","Int",0,"Input",$true,0,0,"","Current",${env:WSL_JOB_KEY})))
    [void]$command.Parameters.Add($(New-Object $param("@p_task_id","Int",0,"Input",$true,0,0,"","Current",${env:WSL_TASK_KEY})))
    [void]$command.Parameters.Add($(New-Object $param("@p_action","Varchar",64,"Input",$true,0,0,"","Current",$Action)))
    [void]$command.Parameters.Add($(New-Object $param("@p_table","Varchar",64,"Input",$true,0,0,"","Current",$Table)))
    [void]$command.Parameters.Add($(New-Object $param("@p_new_value","Varchar",64,"Input",$true,0,0,"","Current",$NewValue)))
    [void]$command.Parameters.Add($(New-Object $param("@p_return_code","Varchar",1,"Output",$true,0,0,"","Current",[DBNull]::Value)))
    [void]$command.Parameters.Add($(New-Object $param("@p_return_msg","Varchar",256,"Output",$true,0,0,"","Current",[DBNull]::Value)))
    [void]$command.Parameters.Add($(New-Object $param("@p_result","Int",0,"Output",$true,0,0,"","Current",[DBNull]::Value)))

    $redOdbc.Open()
    [void]$command.ExecuteNonQuery()
    $redOdbc.Close()

    return , $command.Parameters["@p_return_code"].Value, $command.Parameters["@p_return_msg"].Value, $command.Parameters["@p_result"].Value
}

<#
.DESCRIPTION
Wrapper function for the Ws_Maintain_Indexes API procedure.
For more information about usage or return values, refer to the Callable Routines API section of the user guide.
.EXAMPLE
Ws_Maintain_Indexes -TableName "dim_date" -Option "BUILD ALL"
Ws_Maintain_Indexes -IndexName "dim_date_idx_0" -Option "DROP"
#>
function Ws_Maintain_Indexes {
    param (
        $TableName = [DBNull]::Value,
        $IndexName = [DBNull]::Value,
        $Option = [DBNull]::Value
    )

    $sql = "{ call ${env:WSL_META_SCHEMA}Ws_Maintain_Indexes (?, ?, ?, ?, ?, ?, NULL, ?, ?, ?) }"
    
    $redOdbc = New-Object System.Data.Odbc.OdbcConnection
    $redOdbc.ConnectionString = "DSN=${env:WSL_META_DSN}"
    if( ! [string]::IsNullOrEmpty(${env:WSL_META_USER})) { $redOdbc.ConnectionString += ";UID=${env:WSL_META_USER}" }
    if( ! [string]::IsNullOrEmpty(${env:WSL_META_PWD}))  { $redOdbc.ConnectionString += ";PWD=${env:WSL_META_PWD}" }
    
    $command = New-Object System.Data.Odbc.OdbcCommand($sql,$redOdbc)
    $command.CommandTimeout = 0
    $command.CommandType = "StoredProcedure"
    $param = [System.Data.Odbc.OdbcParameter]
    [void]$command.Parameters.Add($(New-Object $param("@p_sequence","Int",0,"Input",$true,0,0,"","Current",${env:WSL_SEQUENCE})))
    [void]$command.Parameters.Add($(New-Object $param("@p_job_name","Varchar",64,"Input",$true,0,0,"","Current",${env:WSL_JOB_NAME})))
    [void]$command.Parameters.Add($(New-Object $param("@p_task_name","Varchar",64,"Input",$true,0,0,"","Current",${env:WSL_TASK_NAME})))
    [void]$command.Parameters.Add($(New-Object $param("@p_job_id","Int",0,"Input",$true,0,0,"","Current",${env:WSL_JOB_KEY})))
    [void]$command.Parameters.Add($(New-Object $param("@p_task_id","Int",0,"Input",$true,0,0,"","Current",${env:WSL_TASK_KEY})))
    [void]$command.Parameters.Add($(New-Object $param("@p_table_name","Varchar",64,"Input",$true,0,0,"","Current",$TableName)))
    [void]$command.Parameters.Add($(New-Object $param("@p_index_name","Varchar",64,"Input",$true,0,0,"","Current",$IndexName)))
    [void]$command.Parameters.Add($(New-Object $param("@p_option","Varchar",64,"Input",$true,0,0,"","Current",$Option)))
    [void]$command.Parameters.Add($(New-Object $param("@p_result","Int",0,"Output",$true,0,0,"","Current",[DBNull]::Value)))

    $redOdbc.Open()
    [void]$command.ExecuteNonQuery()
    $redOdbc.Close()

    return , $command.Parameters["@p_result"].Value
}

<#
.DESCRIPTION
Wrapper function for the Ws_Version_Clear API procedure.
For more information about usage or return values, refer to the Callable Routines API section of the user guide.
.EXAMPLE
Ws_Version_Clear -DayCount 60
#>
function Ws_Version_Clear {
    param (
        $DayCount = [DBNull]::Value,
        $KeepCount = [DBNull]::Value
    )

    $sql = "{ call ${env:WSL_META_SCHEMA}Ws_Version_Clear (?, ?, ?, ?, ?, ?, ?, NULL, ?, ?, ?) }"
    
    $redOdbc = New-Object System.Data.Odbc.OdbcConnection
    $redOdbc.ConnectionString = "DSN=${env:WSL_META_DSN}"
    if( ! [string]::IsNullOrEmpty(${env:WSL_META_USER})) { $redOdbc.ConnectionString += ";UID=${env:WSL_META_USER}" }
    if( ! [string]::IsNullOrEmpty(${env:WSL_META_PWD}))  { $redOdbc.ConnectionString += ";PWD=${env:WSL_META_PWD}" }
    
    $command = New-Object System.Data.Odbc.OdbcCommand($sql,$redOdbc)
    $command.CommandTimeout = 0
    $command.CommandType = "StoredProcedure"
    $param = [System.Data.Odbc.OdbcParameter]
    [void]$command.Parameters.Add($(New-Object $param("@p_sequence","Int",0,"Input",$true,0,0,"","Current",${env:WSL_SEQUENCE})))
    [void]$command.Parameters.Add($(New-Object $param("@p_job_name","Varchar",64,"Input",$true,0,0,"","Current",${env:WSL_JOB_NAME})))
    [void]$command.Parameters.Add($(New-Object $param("@p_task_name","Varchar",64,"Input",$true,0,0,"","Current",${env:WSL_TASK_NAME})))
    [void]$command.Parameters.Add($(New-Object $param("@p_job_id","Int",0,"Input",$true,0,0,"","Current",${env:WSL_JOB_KEY})))
    [void]$command.Parameters.Add($(New-Object $param("@p_task_id","Int",0,"Input",$true,0,0,"","Current",${env:WSL_TASK_KEY})))
    [void]$command.Parameters.Add($(New-Object $param("@p_day_count","Int",0,"Input",$true,0,0,"","Current",$DayCount)))
    [void]$command.Parameters.Add($(New-Object $param("@p_keep_count","Int",0,"Input",$true,0,0,"","Current",$KeepCount)))
    [void]$command.Parameters.Add($(New-Object $param("@p_return_code","Varchar",1,"Output",$true,0,0,"","Current",[DBNull]::Value)))
    [void]$command.Parameters.Add($(New-Object $param("@p_return_msg","Varchar",256,"Output",$true,0,0,"","Current",[DBNull]::Value)))
    [void]$command.Parameters.Add($(New-Object $param("@p_result","Int",0,"Output",$true,0,0,"","Current",[DBNull]::Value)))

    $redOdbc.Open()
    [void]$command.ExecuteNonQuery()
    $redOdbc.Close()

    return , $command.Parameters["@p_return_code"].Value, $command.Parameters["@p_return_msg"].Value, $command.Parameters["@p_result"].Value
}

<#
.DESCRIPTION
Wrapper function for the WsParameterRead API procedure.
For more information about usage or return values, refer to the Callable Routines API section of the user guide.
.EXAMPLE
WsParameterRead -ParameterName "CURRENT_DAY"
#>
function WsParameterRead {
    param(
        $ParameterName = [DBNull]::Value
    )
    
    $sql = "{ call ${env:WSL_META_SCHEMA}WsParameterRead (?, ?, ?) }"
    
    $redOdbc = New-Object System.Data.Odbc.OdbcConnection
    $redOdbc.ConnectionString = "DSN=${env:WSL_META_DSN}"
    if( ! [string]::IsNullOrEmpty(${env:WSL_META_USER})) { $redOdbc.ConnectionString += ";UID=${env:WSL_META_USER}" }
    if( ! [string]::IsNullOrEmpty(${env:WSL_META_PWD}))  { $redOdbc.ConnectionString += ";PWD=${env:WSL_META_PWD}" }
    
    $command = New-Object System.Data.Odbc.OdbcCommand($sql,$redOdbc)
    $command.CommandTimeout = 0
    $command.CommandType = "StoredProcedure"
    $param = [System.Data.Odbc.OdbcParameter]
    [void]$command.Parameters.Add($(New-Object $param("@p_parameter","Varchar",64,"Input",$true,0,0,"","Current",$parameterName)))
    [void]$command.Parameters.Add($(New-Object $param("@p_value","Varchar",2000,"Output",$true,0,0,"","Current",[DBNull]::Value)))
    [void]$command.Parameters.Add($(New-Object $param("@p_comment","Varchar",256,"Output",$true,0,0,"","Current",[DBNull]::Value)))
    
    $redOdbc.Open()
    [void]$command.ExecuteNonQuery()
    $redOdbc.Close()
    
    return , $command.Parameters["@p_value"].Value, $command.Parameters["@p_comment"].Value
}

<#
.DESCRIPTION
Wrapper function for the WsParameterWrite API procedure.
For more information about usage or return values, refer to the Callable Routines API section of the user guide.
.EXAMPLE
WsParameterWrite -ParameterName "CURRENT_DAY" -ParameterValue "Monday" -ParameterComment "The current day of the week"
#>
function WsParameterWrite {
    param(
        $ParameterName    = [DBNull]::Value,
        $ParameterValue   = [DBNull]::Value,
        $ParameterComment = [DBNull]::Value
    )
    $sql = "{ ? = call ${env:WSL_META_SCHEMA}WsParameterWrite (?, ?, ?) }"
    
    $redOdbc = New-Object System.Data.Odbc.OdbcConnection
    $redOdbc.ConnectionString = "DSN=${env:WSL_META_DSN}"
    if( ! [string]::IsNullOrEmpty(${env:WSL_META_USER})) { $redOdbc.ConnectionString += ";UID=${env:WSL_META_USER}" }
    if( ! [string]::IsNullOrEmpty(${env:WSL_META_PWD}))  { $redOdbc.ConnectionString += ";PWD=${env:WSL_META_PWD}" }
    
    $command = New-Object System.Data.Odbc.OdbcCommand($sql,$redOdbc)
    $command.CommandTimeout = 0
    $command.CommandType = "StoredProcedure"
    $param = [System.Data.Odbc.OdbcParameter]
    [void]$command.Parameters.Add($(New-Object $param("@ReturnValue","Int",0,"ReturnValue",$true,0,0,"","Current",[DBNull]::Value)))
    [void]$command.Parameters.Add($(New-Object $param("@p_parameter","Varchar",64,"Input",$true,0,0,"","Current",$parameterName)))
    [void]$command.Parameters.Add($(New-Object $param("@p_value","Varchar",2000,"Input",$true,0,0,"","Current",$parameterValue)))
    [void]$command.Parameters.Add($(New-Object $param("@p_comment","Varchar",256,"Input",$true,0,0,"","Current",$parameterComment)))
    
    $redOdbc.Open()
    [void]$command.ExecuteNonQuery()
    $redOdbc.Close()
    
    return , $command.Parameters["@ReturnValue"].Value
}

<#
.DESCRIPTION
Wrapper function for the WsWrkAudit API procedure.
For more information about usage or return values, refer to the Callable Routines API section of the user guide.
.EXAMPLE
WsWrkAudit -Message "This is an audit log INFO message created by calling WsWrkAudit"
WsWrkAudit -StatusCode "E" -Message "This is an audit log ERROR message created by calling WsWrkAudit"
#>
function WsWrkAudit {
    param (
        $StatusCode = 'I',
        $Message    = [DBNull]::Value,
        $DBCode     = [DBNull]::Value,
        $DBMessage  = [DBNull]::Value
    )

    $sql = "{ ? = call ${env:WSL_META_SCHEMA}WsWrkAudit (?, ?, ?, ?, ?, ?, ?, ?, ?) }"
    
    $redOdbc = New-Object System.Data.Odbc.OdbcConnection
    $redOdbc.ConnectionString = "DSN=${env:WSL_META_DSN}"
    if( ! [string]::IsNullOrEmpty(${env:WSL_META_USER})) { $redOdbc.ConnectionString += ";UID=${env:WSL_META_USER}" }
    if( ! [string]::IsNullOrEmpty(${env:WSL_META_PWD}))  { $redOdbc.ConnectionString += ";PWD=${env:WSL_META_PWD}" }
    
    $command = New-Object System.Data.Odbc.OdbcCommand($sql,$redOdbc)
    $command.CommandTimeout = 0
    $command.CommandType = "StoredProcedure"
    $param = [System.Data.Odbc.OdbcParameter]
    [void]$command.Parameters.Add($(New-Object $param("@ReturnValue","Int",0,"ReturnValue",$true,0,0,"","Current",[DBNull]::Value)))
    [void]$command.Parameters.Add($(New-Object $param("@p_status_code","Varchar",1,"Input",$true,0,0,"","Current",$statusCode)))
    [void]$command.Parameters.Add($(New-Object $param("@p_job_name","Varchar",64,"Input",$true,0,0,"","Current",${env:WSL_JOB_NAME})))
    [void]$command.Parameters.Add($(New-Object $param("@p_task_name","Varchar",64,"Input",$true,0,0,"","Current",${env:WSL_TASK_NAME})))
    [void]$command.Parameters.Add($(New-Object $param("@p_sequence","Int",0,"Input",$true,0,0,"","Current",${env:WSL_SEQUENCE})))
    [void]$command.Parameters.Add($(New-Object $param("@p_message","Varchar",256,"Input",$true,0,0,"","Current",$message)))
    [void]$command.Parameters.Add($(New-Object $param("@p_db_code","Varchar",10,"Input",$true,0,0,"","Current",$dbCode)))
    [void]$command.Parameters.Add($(New-Object $param("@p_db_message","Varchar",256,"Input",$true,0,0,"","Current",$dbMessage)))
    [void]$command.Parameters.Add($(New-Object $param("@p_task_key","Int",0,"Input",$true,0,0,"","Current",${env:WSL_TASK_KEY})))
    [void]$command.Parameters.Add($(New-Object $param("@p_job_key","Int",0,"Input",$true,0,0,"","Current",${env:WSL_JOB_KEY})))

    $redOdbc.Open()
    [void]$command.ExecuteNonQuery()
    $redOdbc.Close()
    
    return , $command.Parameters["@ReturnValue"].Value
}

<#
.DESCRIPTION
Wrapper function for the WsWrkError API procedure.
For more information about usage or return values, refer to the Callable Routines API section of the user guide.
.EXAMPLE
WsWrkError -Message "This is a detail log INFO message created by calling WsWrkAudit"
WsWrkError -StatusCode "E" -Message "This is a detail log ERROR message created by calling WsWrkAudit"
#>
function WsWrkError {
    param (
        $statusCode  = 'I',
        $message     = [DBNull]::Value,
        $dbCode      = [DBNull]::Value,
        $dbMessage   = [DBNull]::Value,
        $messageType = [DBNull]::Value
    )

    $sql = "{ ? = call ${env:WSL_META_SCHEMA}WsWrkError (?, ?, ?, ?, ?, ?, ?, ?, ?, ?) }"
    
    $redOdbc = New-Object System.Data.Odbc.OdbcConnection
    $redOdbc.ConnectionString = "DSN=${env:WSL_META_DSN}"
    if( ! [string]::IsNullOrEmpty(${env:WSL_META_USER})) { $redOdbc.ConnectionString += ";UID=${env:WSL_META_USER}" }
    if( ! [string]::IsNullOrEmpty(${env:WSL_META_PWD}))  { $redOdbc.ConnectionString += ";PWD=${env:WSL_META_PWD}" }
    
    $command = New-Object System.Data.Odbc.OdbcCommand($sql,$redOdbc)
    $command.CommandTimeout = 0
    $command.CommandType = "StoredProcedure"
    $param = [System.Data.Odbc.OdbcParameter]
    [void]$command.Parameters.Add($(New-Object $param("@ReturnValue","Int",0,"ReturnValue",$true,0,0,"","Current",[DBNull]::Value)))
    [void]$command.Parameters.Add($(New-Object $param("@p_status_code","Varchar",1,"Input",$true,0,0,"","Current",$statusCode)))
    [void]$command.Parameters.Add($(New-Object $param("@p_job_name","Varchar",64,"Input",$true,0,0,"","Current",${env:WSL_JOB_NAME})))
    [void]$command.Parameters.Add($(New-Object $param("@p_task_name","Varchar",64,"Input",$true,0,0,"","Current",${env:WSL_TASK_NAME})))
    [void]$command.Parameters.Add($(New-Object $param("@p_sequence","Int",0,"Input",$true,0,0,"","Current",${env:WSL_SEQUENCE})))
    [void]$command.Parameters.Add($(New-Object $param("@p_message","Varchar",256,"Input",$true,0,0,"","Current",$message)))
    [void]$command.Parameters.Add($(New-Object $param("@p_db_code","Varchar",10,"Input",$true,0,0,"","Current",$dbCode)))
    [void]$command.Parameters.Add($(New-Object $param("@p_db_message","Varchar",256,"Input",$true,0,0,"","Current",$dbMessage)))
    [void]$command.Parameters.Add($(New-Object $param("@p_task_key","Int",0,"Input",$true,0,0,"","Current",${env:WSL_TASK_KEY})))
    [void]$command.Parameters.Add($(New-Object $param("@p_job_key","Int",0,"Input",$true,0,0,"","Current",${env:WSL_JOB_KEY})))
    [void]$command.Parameters.Add($(New-Object $param("@p_message_type","Varchar",10,"Input",$true,0,0,"","Current",$messageType)))

    $redOdbc.Open()
    [void]$command.ExecuteNonQuery()
    $redOdbc.Close()
    
    return , $command.Parameters["@ReturnValue"].Value
}

<#
.DESCRIPTION
Wrapper function for the WsWrkTask API procedure.
For more information about usage or return values, refer to the Callable Routines API section of the user guide.
.EXAMPLE
WsWrkTask -Inserted 20 -Updated 35
#>
function WsWrkTask {
    param (
        $Inserted = 0,
        $Updated = 0,
        $Replaced = 0,
        $Deleted = 0,
        $Discarded = 0,
        $Rejected = 0,
        $Errored = 0
    )

    $sql = "{ ? = call ${env:WSL_META_SCHEMA}WsWrkTask (?, ?, ?, ?, ?, ?, ?, ?, ?, ?) }"

    $redOdbc = New-Object System.Data.Odbc.OdbcConnection
    $redOdbc.ConnectionString = "DSN=${env:WSL_META_DSN}"
    if( ! [string]::IsNullOrEmpty(${env:WSL_META_USER})) { $redOdbc.ConnectionString += ";UID=${env:WSL_META_USER}" }
    if( ! [string]::IsNullOrEmpty(${env:WSL_META_PWD}))  { $redOdbc.ConnectionString += ";PWD=${env:WSL_META_PWD}" }
    
    $command = New-Object System.Data.Odbc.OdbcCommand($sql,$redOdbc)
    $command.CommandTimeout = 0
    $command.CommandType = "StoredProcedure"
    $param = [System.Data.Odbc.OdbcParameter]
    [void]$command.Parameters.Add($(New-Object $param("@ReturnValue","Int",0,"ReturnValue",$true,0,0,"","Current",[DBNull]::Value)))
    [void]$command.Parameters.Add($(New-Object $param("@p_job_key","Int",0,"Input",$true,0,0,"","Current",${env:WSL_JOB_KEY})))
    [void]$command.Parameters.Add($(New-Object $param("@p_task_key","Int",0,"Input",$true,0,0,"","Current",${env:WSL_TASK_KEY})))
    [void]$command.Parameters.Add($(New-Object $param("@p_sequence","Int",0,"Input",$true,0,0,"","Current",${env:WSL_SEQUENCE})))
    [void]$command.Parameters.Add($(New-Object $param("@p_inserted","Int",0,"Input",$true,0,0,"","Current",$Inserted)))
    [void]$command.Parameters.Add($(New-Object $param("@p_updated","Int",0,"Input",$true,0,0,"","Current",$Updated)))
    [void]$command.Parameters.Add($(New-Object $param("@p_replaced","Int",0,"Input",$true,0,0,"","Current",$Replaced)))
    [void]$command.Parameters.Add($(New-Object $param("@p_deleted","Int",0,"Input",$true,0,0,"","Current",$Deleted)))
    [void]$command.Parameters.Add($(New-Object $param("@p_discarded","Int",0,"Input",$true,0,0,"","Current",$Discarded)))
    [void]$command.Parameters.Add($(New-Object $param("@p_rejected","Int",0,"Input",$true,0,0,"","Current",$Rejected)))
    [void]$command.Parameters.Add($(New-Object $param("@p_errored","Int",0,"Input",$true,0,0,"","Current",$Errored)))
    
    $redOdbc.Open()
    [void]$command.ExecuteNonQuery()
    $redOdbc.Close()
    
    return , $command.Parameters["@ReturnValue"].Value
}

<#
.DESCRIPTION
Used to run any SQL against any ODBC DSN
.EXAMPLE
Run-RedSQL -sql "SELECT * FROM stage_customers" -dsn "dssdemo"
#>
function Run-RedSQL {
    param(
        $sql = '',
        $dsn = '',
        $uid = '',
        $pwd = '',
        $odbcConn,
        [switch]$notrans
    )
	[bool] $overflowError=0 #Flag to check if the arithmatic overflow is encountered
    $InfoMessages = New-Object System.Collections.ArrayList
    if($odbcConn -eq $null) {
        $odbcConn = New-Object System.Data.Odbc.OdbcConnection
    }
    if($odbcConn.State -ne "Open") {
        $odbcConn.ConnectionString = "DSN=$dsn"
        if( ! [string]::IsNullOrWhitespace($uid)){
            $odbcConn.ConnectionString += ";UID=$uid"
        }
        if( ! [string]::IsNullOrWhitespace($pwd)){
            $odbcConn.ConnectionString += ";PWD=$pwd"
        }
        $infoEvent = Register-ObjectEvent -InputObj $odbcConn -EventName "InfoMessage" -MessageData $InfoMessages -Action {
            param (
                $sender,
                $e
            )
            [System.Threading.Monitor]::Enter($Event.MessageData)
            [void]($Event.MessageData).Add($e.Data)
            [System.Threading.Monitor]::Exit($Event.MessageData)
        }
    }
    try {
        if([string]::IsNullOrWhiteSpace($sql)) {
            if($odbcConn.State -ne "Open") {
                $odbcConn.Open()
            }
        }
        else {
            if($odbcConn.State -ne "Open") {
                $odbcConn.Open()
            }
            if( ! $notrans ) {
                $transaction = $odbcConn.BeginTransaction()
            }
            $odbcCommand = New-Object System.Data.Odbc.OdbcCommand($sql,$odbcConn)
            $odbcCommand.CommandTimeout = 0
            $odbcCommand.Transaction = $transaction
			try{
               $odbcReader = $odbcCommand.ExecuteReader()
               if($odbcReader.HasRows) {
                $dataTable = New-Object System.Data.DataTable
                $schemaTable = $odbcReader.GetSchemaTable()
                foreach($row in $schemaTable.Rows) {
                    $null = $dataTable.Columns.Add($row.ColumnName,$row.DataType)
                }
                while($odbcReader.Read()) {
                    $newRow = $dataTable.Rows.Add()
                    for($i = 0; $i -lt $odbcReader.FieldCount; $i++) {
                        $newRow[$i] = $odbcReader.GetValue($i)
                    }
                }
              }
			 }
             catch [System.Management.Automation.MethodInvocationException]{
                    $e = $_.Exception
                    if (($e.Message -match "Arithmetic operation resulted in an overflow.") -eq "True"){
                       $overflowError=1#Set flag if Arithmetic overflow encountered
                    }
					else{
					   throw( $_.Exception)#Throw Errors except Arithmetic overflow
					}
			}
            if( ! $notrans ) {
                $transaction.Commit()
            }
            if($overflowError -eq 1){
               return $odbcConn,1,-[int32]::MaxValue,$InfoMessages.ToArray(),$dataTable.Rows # return -ve 2billion if Arithmetic overflow encountered
            }
            else{
            return $odbcConn,1,$odbcReader.RecordsAffected,$InfoMessages.ToArray(),$dataTable.Rows
            }
        }
    }
    catch {
        $msgArray = new-object System.Collections.ArrayList
        $e = $_.Exception
        $null = $msgArray.Add($e.Message)
        while ($e.InnerException) {
            $e = $e.InnerException
            $null = $msgArray.Add($e.Message)
        }
        return $odbcConn,-2,$odbcReader.RecordsAffected,$msgArray,$dataTable.Rows
    }
}

<#
.DESCRIPTION
Used to hide the evil black box of death
#>
function Hide-Window {
	$t = '[DllImport("user32.dll")] public static extern bool ShowWindow(int handle, int state);'
	add-type -name win -member $t -namespace native
	$parent = (Get-WmiObject Win32_Process | select ProcessID, ParentProcessID | where { $_.ProcessID -eq 	([System.Diagnostics.Process]::GetCurrentProcess()).id }).ParentProcessID
	$currwind = ([System.Diagnostics.Process]::GetProcessById($parent) | Get-Process).MainWindowHandle
	$null = [native.win]::ShowWindow($currwind, 0)
    ${env:mainWindowHandle} = $currwind
}

function Unhide-Window {
    if( ! [string]::IsNullOrEmpty(${env:mainWindowHandle})) {
        $t = '[DllImport("user32.dll")] public static extern bool ShowWindow(int handle, int state);'
	    add-type -name win -member $t -namespace native
	    $null = [native.win]::ShowWindow(${env:mainWindowHandle}, 1)
    }
}

function Get-ExtendedProperty { 
    param(
        $propertyName,
        $tableName
    )
    $sql = @"
      SELECT COALESCE(tab.epv_value, src.epv_value, tgt.epv_value, xpt.epv_value, '')
      FROM ${env:WSL_META_SCHEMA}ws_ext_prop_def def
      LEFT OUTER JOIN ${env:WSL_META_SCHEMA}ws_ext_prop_value tab
      ON tab.epv_obj_key = ( SELECT oo_obj_key 
                             FROM ${env:WSL_META_SCHEMA}ws_obj_object 
                             WHERE UPPER(oo_name) = UPPER('$tableName')
                           )
      AND tab.epv_def_key = def.epd_key
      LEFT OUTER JOIN ${env:WSL_META_SCHEMA}ws_ext_prop_value src
      ON src.epv_obj_key = ( SELECT lt_connect_key 
                             FROM ${env:WSL_META_SCHEMA}ws_load_tab 
                             WHERE UPPER(lt_table_name) = UPPER('$tableName')
                           )
      AND src.epv_def_key = def.epd_key
      LEFT OUTER JOIN ${env:WSL_META_SCHEMA}ws_ext_prop_value tgt
      ON tgt.epv_obj_key = ( SELECT dc_obj_key
                             FROM ${env:WSL_META_SCHEMA}ws_dbc_connect
                             JOIN ${env:WSL_META_SCHEMA}ws_dbc_target
                             ON dt_connect_key = dc_obj_key
                             JOIN ${env:WSL_META_SCHEMA}ws_obj_object
                             ON oo_target_key = dt_target_key
                             WHERE UPPER(oo_name) = UPPER('$tableName')
                           )                           
      AND tgt.epv_def_key = def.epd_key
      LEFT OUTER JOIN ${env:WSL_META_SCHEMA}ws_ext_prop_value xpt
      ON xpt.epv_obj_key = ( SELECT dc_obj_key
                             FROM ${env:WSL_META_SCHEMA}ws_dbc_connect
                             JOIN ${env:WSL_META_SCHEMA}ws_export_tab
                             ON et_connect_key = dc_obj_key
                             WHERE UPPER(et_table_name) = UPPER('$tableName')
                           )
      AND xpt.epv_def_key = def.epd_key
      WHERE UPPER(def.epd_variable_name) = UPPER('$propertyName')
"@

    $redOdbc = New-Object System.Data.Odbc.OdbcConnection
    $redOdbc.ConnectionString = "DSN=${env:WSL_META_DSN}"
    if( ! [string]::IsNullOrEmpty(${env:WSL_META_USER})) { $redOdbc.ConnectionString += ";UID=${env:WSL_META_USER}" }
    if( ! [string]::IsNullOrEmpty(${env:WSL_META_PWD}))  { $redOdbc.ConnectionString += ";PWD=${env:WSL_META_PWD}" }
    
    $command = New-Object System.Data.Odbc.OdbcCommand($sql,$redOdbc)
    $command.CommandTimeout = 0
    
    $redOdbc.Open()
    $value = $command.ExecuteScalar()
    $redOdbc.Close()
    
    return , $value
}

function Get-OdbcDumpSource {
    $src = @"
namespace WhereScape
{
    using System;
    using System.IO;
    using System.Text;
    using System.Collections.Generic;
    using System.Data.Odbc;

    public class OdbcDump {

        public static void Main() {}
        
        private OdbcConnection CreateConnection(string dsn, string username, string password) 
        {
            OdbcConnection conn = new OdbcConnection();
            conn.ConnectionString = String.Format("DSN={0}",dsn);
            if( ! String.IsNullOrEmpty(username)) {
                conn.ConnectionString += String.Format(";UID={0}",username);
            }
            if( ! String.IsNullOrEmpty(password)) {
                conn.ConnectionString += String.Format(";PWD={0}",password);
            }
            conn.Open();
            return conn;
        }

        private bool SplitThresholdExceeded(string query, OdbcConnection conn, int splitThreshold)
        {
            OdbcCommand command = new OdbcCommand(query,conn);
            command.CommandTimeout = 0;

            bool split = false;

            OdbcDataReader rcReader = command.ExecuteReader();
            int rcReaderCurrCount = 0;
            while(rcReader.Read()) 
            {
                rcReaderCurrCount++;
                if(rcReaderCurrCount == splitThreshold) 
                {
                    split = true;
                    break;
                }
            }
            rcReader.Dispose();
            command.Dispose();

            return split;
        }

        public int GetDataToFile(string query, string dsn, string username, string password, string dataFile, string delimiter, int fileCount, int splitThreshold, bool addQuotes, string unicodeString, string enclosedBy, string escapeChar, string nullStr) 
        {
            OdbcConnection conn = CreateConnection(dsn,username,password);

            bool shouldSplit = false;
            if(fileCount > 0 && splitThreshold > 0)
            {
                shouldSplit = SplitThresholdExceeded(query, conn, splitThreshold);
            }

            OdbcCommand command = new OdbcCommand(query,conn);
            command.CommandTimeout = 0;
            OdbcDataReader reader = command.ExecuteReader();

            int rowCount = 0;
            
            List<StreamWriter> swl = new List<StreamWriter>();

            Encoding encoding;
            if ( unicodeString == "UTF8" ) 
            { 
                encoding = new UTF8Encoding(false);
            }
            else if( unicodeString == "UTF16" ) 
            { 
                encoding = new UnicodeEncoding(false,true);
            }
            else {
                encoding = Encoding.ASCII;
            }

            StreamWriter sw = new StreamWriter(dataFile, false, encoding);
            sw.AutoFlush = true;
            swl.Add(sw);
            if(shouldSplit) 
            {
                for( int i = 1; i < fileCount; i++) 
                { 
                    sw = new StreamWriter(dataFile + "_" + i.ToString() + ".txt", false, encoding);
                    sw.AutoFlush = true;
                    swl.Add(sw);
                }
            }
            int columnCount = reader.FieldCount;
            int swNum = 0;
            if (nullStr == null)
            {
                // if null string character is null, replace with empty string
                nullStr = "";
            }
            while(reader.Read()) 
            {
                List<string> data = new List<string>();
                for ( int x = 0; x < columnCount; x++) 
                {
                    if(reader.IsDBNull(x)) 
                    {
                        data.Add(nullStr);
                    }
                    else 
                    {
                        if(addQuotes) 
                        {
                            String dataVal = reader.GetValue(x).ToString();

                            if( ! String.IsNullOrWhiteSpace(escapeChar)) 
                            {
                                // when escapeChar occurs in the data, double it
                                dataVal = dataVal.Replace(escapeChar, escapeChar + escapeChar);
                            }

                            // when enclosedBy occurs in the data, escape it with escapeChar
                            dataVal = dataVal.Replace(enclosedBy,escapeChar + enclosedBy);

                            // enclose the value with enclosedBy chars
                            dataVal = enclosedBy + dataVal + enclosedBy;

                            data.Add(dataVal);
                        }
                        else {
                            // if no enclosedBy set, strip out delimiter char
                            data.Add(reader.GetValue(x).ToString().Replace(delimiter,""));
                        }
                    }
                }
                string[] row = data.ToArray();
                string work = String.Join(delimiter,row);
                work = work.Replace("\r","");
                work = work.Replace("\n"," ");
                if(swNum == fileCount && shouldSplit) 
                {
                    swNum = 0;
                }
                swl[swNum].WriteLine(work);
                if(swNum < fileCount && shouldSplit) 
                {
                    swNum++;
                }
                rowCount++;

            }
            foreach(StreamWriter swDisp in swl) {
                swDisp.Dispose();
            }
            conn.Dispose();
            return rowCount;
        }
        
        public int GetDataToFile(string query, string dsn, string username, string password, string dataFile, string delimiter, int fileCount, int splitThreshold, bool addQuotes, bool unicode, string enclosedBy, string escapeChar) 
        {
            string unicodeString = "ASCII";
            if (unicode) {
                unicodeString = "UTF8";
            }
            int rowCount = GetDataToFile(query, dsn, username, password, dataFile, delimiter, fileCount, splitThreshold, addQuotes, unicodeString, enclosedBy, escapeChar);
            return rowCount;
        }


        public int GetDataToFile(string query, string dsn, string username, string password, string dataFile, string delimiter, int fileCount, int splitThreshold, string unicodeString, string enclosedBy, string escapeChar) 
        {
            bool addQuotes = false;
            if ( ! (String.IsNullOrWhiteSpace(enclosedBy)) ) {
                addQuotes = true;
            }
            int rowCount = GetDataToFile(query, dsn, username, password, dataFile, delimiter, fileCount, splitThreshold, addQuotes, unicodeString, enclosedBy, escapeChar);
            return rowCount;
        }

        public int GetDataToFile(string query, string dsn, string username, string password, string dataFile, string delimiter, int fileCount, int splitThreshold, bool unicode, string enclosedBy, string escapeChar) 
        {
            bool addQuotes = false;
            if ( ! (String.IsNullOrWhiteSpace(enclosedBy)) ) {
                addQuotes = true;
            }
            string unicodeString = "ASCII";
            if (unicode) {
                unicodeString = "UTF8";
            }
            int rowCount = GetDataToFile(query, dsn, username, password, dataFile, delimiter, fileCount, splitThreshold, addQuotes, unicodeString, enclosedBy, escapeChar);
            return rowCount;
        }

        public int GetDataToFile(string query, string dsn, string username, string password, string dataFile, string delimiter, int fileCount, int splitThreshold, bool addQuotes, bool unicode) 
        {
            String enclosedBy = "";
            if ( addQuotes ) {
                enclosedBy = "\"";
            }
            string unicodeString = "ASCII";
            if (unicode) {
                unicodeString = "UTF8";
            }
            int rowCount = GetDataToFile(query, dsn, username, password, dataFile, delimiter, fileCount, splitThreshold, addQuotes, unicodeString, enclosedBy, "");
            return rowCount;
        }

        public int GetDataToFile(string query, string dsn, string username, string password, string dataFile, string delimiter) 
        {
            int rowCount = GetDataToFile(query, dsn, username, password, dataFile, delimiter, 0, 0, false, "ASCII", "", "");
            return rowCount;
        } 
        
        public int GetDataToFile(string query, string dsn, string dataFile, string delimiter) 
        {
            int rowCount = GetDataToFile(query, dsn, null, null, dataFile, delimiter, 0, 0, false, "ASCII", "", "");
            return rowCount;
        }

        public int GetDataToFile(string query, string dsn, string username, string password, string dataFile, string delimiter, int fileCount, int splitThreshold, bool addQuotes, string unicodeString, string enclosedBy, string escapeChar) 
        {
            int rowCount = GetDataToFile(query, dsn, username, password, dataFile, delimiter, fileCount, splitThreshold, addQuotes, unicodeString, enclosedBy, escapeChar, "");
            return rowCount;
        }
    }
}
"@
    return $src
}

function Show-KillBox {
    $parent = (Get-WmiObject Win32_Process | select ProcessID, ParentProcessID | where { $_.ProcessID -eq  $pid }).ParentProcessID
    $caller = (Get-WmiObject Win32_Process | select ProcessID, ParentProcessID | where { $_.ProcessID -eq ([System.Diagnostics.Process]::GetProcessById($parent)).id}).ParentProcessID
    if((Get-Process -Id $caller).Name -eq "med") {
        $killBoxScript = {
            param (
                $scriptHostPid
            )
            try {
                [void][System.Reflection.Assembly]::LoadWithPartialName("System.Windows.Forms")

                $form = New-Object System.Windows.Forms.Form

                $form.Width = 350
                $form.Height = 100
                if([string]::IsNullOrEmpty(${env:WSL_LOAD_TABLE})) {
                    $form.Text = "Script Running"
                }
                else {
                    $form.Text = ${env:WSL_LOAD_TABLE}
                }
                $form.StartPosition = [System.Windows.Forms.FormStartPosition]::CenterScreen
                $form.FormBorderStyle = [System.Windows.Forms.FormBorderStyle]::FixedDialog
                $form.Icon = [System.Drawing.Icon]::ExtractAssociatedIcon("${env:WSL_BINDIR}med.exe")
                $form.MinimizeBox = $true
                $form.MaximizeBox = $false

                $label = New-Object System.Windows.Forms.Label
                $label.Text = "This dialog will close automatically when the script completes"
                $label.Width = 310
                $label.Top = 10
                $label.Left = ( $form.ClientSize.Width - $label.Width ) / 2
                $label.Select()

                $button = New-Object System.Windows.Forms.Button
                $button.Left = ( $form.ClientSize.Width - $button.Width ) / 2
                $button.Top = ( $form.ClientSize.Height - $button.Height ) - 5 
                $button.Width = 100
                $button.Text = "Cancel"
                $button.Anchor = "None"
                $button.TabStop = $true

                $scriptProcess = Get-Process -id $scriptHostPid

                $clickHandler = {
                    $form.Dispose()
                    Unhide-Window
                    $scriptProcess.CloseMainWindow()
                }

                $button.Add_Click($clickHandler)

                $form.Controls.Add($label)
                $form.Controls.Add($button)
                $form.ActiveControl = $label
                $dialogResult = $form.ShowDialog()
                while ( ( $dialogResult -eq [System.Windows.Forms.DialogResult]::Cancel ) -and ( ! $form.IsDisposed ) ) {
                        $dialogResult = $form.ShowDialog()
                }
            } 
            finally {
                if( ! $form.IsDisposed ) {
                    $form.Dispose()
                }
            }
        }
        $job = Start-Job -ScriptBlock $killBoxScript -ArgumentList $parent
    }
}

# Function to download file from Amazon S3
function Download-File-Amazon-S3 {
    param(
        $accessKey,
        $secretKey,
		$regionName,
        $bucketName,
		$fileName,
        $sourcePath,
        $downloadPath
    )

	$setAWSCred = Set-AWSCredential -AccessKey $accessKey -SecretKey $secretKey
	$setAWSRegion = Set-DefaultAWSRegion -Region $regionName
    $getS3Object = Get-S3Object -BucketName $bucketName -KeyPrefix $sourcePath

    $downloadedFilePaths = @()
    foreach ($currentItemName in $getS3Object) {
        $sfileName = $currentItemName.Key.replace($sourcePath.Trim() + "/", "")
        if ($sfileName -Like $fileName) {
            
            $localDownloadPath = $downloadPath + "\" + $sfileName
            $finalsourcePath = "$sourcePath/$sfileName"
            Get-S3Object -BucketName $bucketName -KeyPrefix $finalsourcePath  | Copy-S3Object -LocalFile $localDownloadPath
            $downloadedFilePaths += $localDownloadPath

        }
    }
}
# Function to download file from Google Cloud Storage
function Download-File-Google-Cloud {
    param(
        $sourceFilePath,
        $downloadPath
		
    )
    # Replace last file file name from file path
    $folderPath = $sourceFilePath -replace "(.*)\/.+\/?$", '$1'
    $getObject = gsutil ls $folderPath
    $downloadedFilePaths = @()
    foreach ($currentItemName in $getObject) {
        if ($currentItemName -Like $sourceFilePath) {
            $sfileName = $currentItemName.split("/")[-1]
            $localDownloadPath = $downloadPath + "\" + $sfileName
            gsutil cp $currentItemName $localDownloadPath
            $downloadedFilePaths += $localDownloadPath
        }
    }
    return $downloadedFilePaths
}

# Function to download file from Google Cloud Storage
function Download-File-Azure-Data-Lake {
    param(
        $ctx,
        $fileSystemName,
        $azureFilePath,
        $downloadPath
    )
    
    $azureFolderPath = $azureFilePath.replace("/" + $azureFilePath.split("/" )[-1], "")
    $Getobject = Get-AzDataLakeGen2ChildItem -Context $ctx -FileSystem $fileSystemName -Path "$azureFolderPath/"

    $downloadedFilePaths = @()
    foreach ($currentItemName in $GetObject) {
        $sfileName = $currentItemName.Path
        if ($sfileName -Like $azureFilePath) {
            $localDownloadPath = $downloadPath + "\" + $sfileName.split("/" )[-1]
            Get-AzDataLakeGen2ItemContent -Context $ctx -FileSystem $fileSystemName -Path $sfileName -Destination $localDownloadPath -Force
            $downloadedFilePaths += $localDownloadPath
        }

    }
    return $downloadedFilePaths
}

Function OrcToCsv ($filePath,$downloadPath,$fieldDelimiter)
{
    $pythonCsvExport= @"
import pandas as pd
import pyorc
with open(r'$filePath','rb') as fp:
        reader = pyorc.Reader(fp)
        records = [r for r in reader]
        df = pd.DataFrame.from_records(records)
        df.to_csv(r'$downloadPath', index=False,sep='$fieldDelimiter')

"@
    $exportFile = $FilePath.Split(".")[0] + "_export.py"
    Set-Content -Path $exportFile -Value $pythonCsvExport
    python $exportFile
    Remove-Item $exportFile	

}

Function AvroToCsv ($filePath,$downloadPath,$fieldDelimiter)
{
    $pythonCsvExport= @"
import pandas as pd
import fastavro
with open(r'$filePath', 'rb') as fp:
        reader = fastavro.reader(fp)
        records = [r for r in reader]
        df = pd.DataFrame.from_records(records)
        df.to_csv(r'$downloadPath', index=False,sep='$fieldDelimiter')

"@
    $exportFile = $FilePath.Split(".")[0] + "_export.py"
    Set-Content -Path $exportFile -Value $pythonCsvExport
    python $exportFile
    Remove-Item $exportFile	

}


Function ParquetToCsv ($filePath,$downloadPath,$fieldDelimiter) {
    $pythonCsvExport= @"
import pandas as pd
import pyarrow.parquet as pq
df = pd.read_parquet(r'$filePath',engine='auto')
df.to_csv(r'$downloadPath', index=False,sep='$fieldDelimiter')
"@
    $exportFile = $FilePath.Split(".")[0] + "_export.py"
	Set-Content -Path $exportFile -Value $pythonCsvExport
    python $exportFile
    Remove-Item $exportFile

}