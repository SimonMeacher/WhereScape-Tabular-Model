# --    (c) WhereScape Inc 2020. WhereScape Inc permits you to copy this module solely for use with the RED software, and to modify this module            -- #
# --    for the purposes of using that modified module with the RED software, but does not permit copying or modification for any other purpose.           -- #
# --                                                                                                                                                       -- #
#=====================================================================================================
# Module Name      :    WslPythonCommon
# DBMS Name        :    Generic for all databases
# Description      :    Generic python functions module used by many
#                       different templates, scripts and database specific
#                       modules
# Author           :    Wherescape Inc
#======================================================================================================
# Notes / History
#  PM:  1.0.0   2020-07-27   First Version
#  PM:  1.0.1   2022-01-11   Updated RunRedSQL Function to handle sessions of the pyodbc connection
#======================================================================================================

import datetime
import re
import win32console
import win32gui
import pyodbc
import os
import sys
import fnmatch
import pytds
from pytds import login
import warnings
from win32ctypes.pywin32.win32api import *
from ctypes import*
import gzip
import shutil
#
#.DESCRIPTION
#Wrapper function for the Ws_Connect_Replace API procedure.
#For more information about usage or return values, refer to the Callable Routines API section of the user guide.
#.EXAMPLE 
#WsConnectReplace("Sales2" ,"Sales")
#
def WsConnectReplace(
        SourceConnection='',
        TargetConnection=''
    ):
    sequence = os.environ["WSL_SEQUENCE"]
    jobName = os.environ["WSL_JOB_NAME"]
    taskName = os.environ["WSL_TASK_NAME"]
    jobId = os.environ["WSL_JOB_KEY"]
    taskId = os.environ["WSL_TASK_KEY"]
    try:
        uid=str(os.environ.get('WSL_META_USER',''))
        pwd=str(os.environ.get('WSL_META_PWD',''))
        ConnectionString = "DSN="+str(os.environ.get('WSL_META_DSN',''))
        if uid and not uid.isspace():
          ConnectionString += ";UID="+uid
        if pwd and not pwd.isspace():
          ConnectionString += ";PWD="+pwd 
        conn = pyodbc.connect(ConnectionString)
        if str(os.environ.get('WSL_META_SCHEMA','')) == "red.":
            sql = """ SELECT red.WsConnectReplace(?,?,?,?,?,?,?,?);"""
        else:
            sql = """
            DECLARE @out nvarchar(max),@out1 nvarchar(max),@out2 nvarchar(max);
            EXEC Ws_Connect_Replace
            @p_sequence  =?
            ,	@p_job_name  = ? 
            , @p_task_name  = ?    
            , @p_job_id = ?    
            , @p_task_id = ?  
            , @p_action = ?  
            , @p_source = ?  
            , @p_target = ? 
            , @p_return_code = @out OUTPUT  
            , @p_return_msg = @out1 OUTPUT   
            , @p_result   = @out2 OUTPUT;   
            SELECT @out AS return_code,@out1 AS return_msg,@out2 AS return_result;"""
        Parameters=[sequence,jobName,taskName,jobId,taskId,"REPLACE",SourceConnection,TargetConnection  ]
        cursor = conn.cursor()
        cursor.execute(sql,Parameters)
        returnValues=cursor.fetchall()
        conn.commit()
        cursor.close()
        return returnValues
    except  Exception as exceptionError:
        print(-2)
        print ("Error getting Connections " +SourceConnection+" "+TargetConnection)
        raise 

#
#.DESCRIPTION
#Wrapper function for the Ws_Job_Abort API procedure.
#For more information about usage or return values, refer to the Callable Routines API section of the user guide.
#.EXAMPLE 
#WsJobAbort("DailyUpdate","Job aborted by WsJobAbort API.")
#
def WsJobAbort(
        JobName = '',
        Sequence = 0,
        JobMsg = ''
    ):
    try:
        uid=str(os.environ.get('WSL_META_USER',''))
        pwd=str(os.environ.get('WSL_META_PWD',''))
        ConnectionString = "DSN="+str(os.environ.get('WSL_META_DSN',''))
        if uid and not uid.isspace():
          ConnectionString += ";UID="+uid
        if pwd and not pwd.isspace():
          ConnectionString += ";PWD="+pwd 
        conn = pyodbc.connect(ConnectionString)
        sql = "{call "+os.environ.get('WSL_META_SCHEMA','')+"WsJobAbort (?,?,?)}"
        Parameters=[JobName,Sequence,JobMsg]
        cursor = conn.cursor()
        cursor.execute(sql,Parameters)
        conn.commit()
        cursor.close()
        print("Executed Successfully")
        sys.exit() 
    except  Exception as exceptionError:
        print(-2)
        print ("Error in Job Abort " +JobName)
        raise 

#.DESCRIPTION
#Wrapper function for the Ws_Job_Clear_Archive API procedure.
#For more information about usage or return values, refer to the Callable Routines API section of the user guide.
#.EXAMPLE 
#WsJobClearArchive -DayCount 10 -Job "DailyUpdate"
#WsJobClearArchive("TRUNCATE")
#>
def WsJobClearArchive(
        DayCount = '',
        Job ='',
        Options = ''
    ):
    sequence = os.environ["WSL_SEQUENCE"]
    jobName = os.environ["WSL_JOB_NAME"]
    taskName = os.environ["WSL_TASK_NAME"]
    jobId = os.environ["WSL_JOB_KEY"]
    taskId = os.environ["WSL_TASK_KEY"]
    uid=str(os.environ.get('WSL_META_USER',''))
    pwd=str(os.environ.get('WSL_META_PWD',''))
    ConnectionString = "DSN="+str(os.environ.get('WSL_META_DSN',''))
    if uid and not uid.isspace():
      ConnectionString += ";UID="+uid
    if pwd and not pwd.isspace():
      ConnectionString += ";PWD="+pwd 
    try:
        conn = pyodbc.connect(ConnectionString)
        if str(os.environ.get('WSL_META_SCHEMA','')) == "red.":
            sql = """ SELECT red.WsJobClearArchive(?,?,?,?,?,?,?,?); """
        else:
            sql=""" 
            DECLARE @out nvarchar(max),@out1 nvarchar(max),@out2 nvarchar(max);
            EXEC Ws_Job_Clear_Archive
            @p_sequence  =?
          ,	@p_job_name  = ? 
          , @p_task_name  = ?    
          , @p_job_id = ?    
          , @p_task_id = ?  
          , @p_day_count = ?  
          , @p_job = ?   
          , @p_options = ?   
          , @p_return_code = @out OUTPUT  
          , @p_return_msg = @out1 OUTPUT   
          , @p_result   = @out2 OUTPUT;   
            SELECT @out AS return_code,@out1 AS return_msg,@out2 AS return_result;"""
        Parameters=[sequence,jobName,taskName,jobId,taskId,DayCount,Job,Options]
        cursor = conn.cursor()
        cursor.execute(sql,Parameters)
        returnValues=cursor.fetchall()
        conn.commit()
        cursor.close()
        return returnValues
    except  Exception as exceptionError:
        print(-2)
        print ("Error in Job " +Job)
        raise
    

#
#.DESCRIPTION
#Wrapper function for the Ws_Job_Clear_Logs API procedure.
#For more information about usage or return values, refer to the Callable Routines API section of the user guide.
#.EXAMPLE 
#WsJobClearLogs("DailyUpdate", 10)
#
def WsJobClearLogs(
        JobToClean = '',
        KeepCount = 0
    ):
    sequence = os.environ["WSL_SEQUENCE"]
    jobName = os.environ["WSL_JOB_NAME"]
    taskName = os.environ["WSL_TASK_NAME"]
    jobId = os.environ["WSL_JOB_KEY"]
    taskId = os.environ["WSL_TASK_KEY"]
    uid=str(os.environ.get('WSL_META_USER',''))
    pwd=str(os.environ.get('WSL_META_PWD',''))
    ConnectionString = "DSN="+str(os.environ.get('WSL_META_DSN',''))
    if uid and not uid.isspace():
      ConnectionString += ";UID="+uid
    if pwd and not pwd.isspace():
      ConnectionString += ";PWD="+pwd 
    try:
        conn = pyodbc.connect(ConnectionString)
        if str(os.environ.get('WSL_META_SCHEMA','')) == "red.":
            sql = """ SELECT red.WsJobClearLogs(?,?,?,?,?,?,?); """
        else:
            sql=""" 
            DECLARE @out nvarchar(max),@out1 nvarchar(max),@out2 nvarchar(max);
            EXEC Ws_Job_Clear_Logs
            @p_sequence  =?
          ,	@p_job_name  = ? 
          , @p_task_name  = ?    
          , @p_job_id = ?    
          , @p_task_id = ?  
          , @p_job_to_clean = ? 
          , @p_keep_count = ?
          , @p_return_code = @out OUTPUT  
          , @p_return_msg = @out1 OUTPUT   
          , @p_result   = @out2 OUTPUT;   
            SELECT @out AS return_code,@out1 AS return_msg,@out2 AS return_result;"""
        Parameters=[sequence,jobName,taskName,jobId,taskId,JobToClean,KeepCount]
        cursor = conn.cursor()
        cursor.execute(sql,Parameters)
        returnValues=cursor.fetchall()
        conn.commit()
        cursor.close()
        return returnValues
    except  Exception as exceptionError:
        print(-2)
        print ("Error in Job " +JobToClean)
        raise
#
#.DESCRIPTION
#Wrapper function for the Ws_Job_Clear_Logs_By_Date API procedure.
#For more information about usage or return values, refer to the Callable Routines API section of the user guide.
#.EXAMPLE 
#WsJobClearLogsByDate("DailyUpdate",10)
#>
def WsJobClearLogsByDate(
        JobToClean = '',
        DayCount = 0
    ):
    sequence = os.environ["WSL_SEQUENCE"]
    jobName = os.environ["WSL_JOB_NAME"]
    taskName = os.environ["WSL_TASK_NAME"]
    jobId = os.environ["WSL_JOB_KEY"]
    taskId = os.environ["WSL_TASK_KEY"]
    uid=str(os.environ.get('WSL_META_USER',''))
    pwd=str(os.environ.get('WSL_META_PWD',''))
    ConnectionString = "DSN="+str(os.environ.get('WSL_META_DSN',''))
    if uid and not uid.isspace():
      ConnectionString += ";UID="+uid
    if pwd and not pwd.isspace():
      ConnectionString += ";PWD="+pwd 
    try:
        conn = pyodbc.connect(ConnectionString)
        if str(os.environ.get('WSL_META_SCHEMA','')) == "red.":
            sql = """ SELECT red.WsJobClearLogsByDate(?,?,?,?,?,?,?); """
        else:
            sql=""" 
            DECLARE @out nvarchar(max),@out1 nvarchar(max),@out2 nvarchar(max);
            EXEC Ws_Job_Clear_Logs_By_Date
            @p_sequence  =?
          ,	@p_job_name  = ? 
          , @p_task_name  = ?    
          , @p_job_id = ?    
          , @p_task_id = ?  
          , @p_job_to_clean = ?
          , @p_day_count = ?
          , @p_return_code = @out OUTPUT  
          , @p_return_msg = @out1 OUTPUT   
          , @p_result   = @out2 OUTPUT;   
            SELECT @out AS return_code,@out1 AS return_msg,@out2 AS return_result;"""
        Parameters=[sequence,jobName,taskName,jobId,taskId,JobToClean,DayCount]
        cursor = conn.cursor()
        cursor.execute(sql,Parameters)
        returnValues=cursor.fetchall()
        conn.commit()
        cursor.close()
        return returnValues
    except  Exception as exceptionError:
        print(-2)
        print ("Error in Job " +JobToClean)
        raise
#
#.DESCRIPTION
#Wrapper function for the Ws_Job_Create API procedure.
#For more information about usage or return values, refer to the Callable Routines API section of the user guide.
#.EXAMPLE 
#WsJobCreate( "DailyUpdate" ,"DailyUpdate_${env:WSL_SEQUENCE}","ONCE",5)
#>=
def WsJobCreate(
        TemplateJob = '',
        NewJob = '',
        Description ='',
        State = '',
        Threads = 0,
        Scheduler = '',
        Logs = 0,
        SuccessCmd = '',
        FailureCmd =''
    ):
    sequence = os.environ["WSL_SEQUENCE"]
    jobName = os.environ["WSL_JOB_NAME"]
    taskName = os.environ["WSL_TASK_NAME"]
    jobId = os.environ["WSL_JOB_KEY"]
    taskId = os.environ["WSL_TASK_KEY"]
    uid=str(os.environ.get('WSL_META_USER',''))
    pwd=str(os.environ.get('WSL_META_PWD',''))
    ConnectionString = "DSN="+str(os.environ.get('WSL_META_DSN',''))
    if uid and not uid.isspace():
      ConnectionString += ";UID="+uid
    if pwd and not pwd.isspace():
      ConnectionString += ";PWD="+pwd 
    try:
        conn = pyodbc.connect(ConnectionString)
        if str(os.environ.get('WSL_META_SCHEMA','')) == "red.":
            sql = """ SELECT red.WsJobCreate(?,?,?,?,?,?,?,?,?,?,?,?,?,?); """
        else:
            sql=""" 
            DECLARE @out nvarchar(max),@out1 nvarchar(max),@out2 nvarchar(max);
            EXEC Ws_Job_Create
            @p_sequence  =?
          ,	@p_job_name  = ? 
          , @p_task_name  = ?    
          , @p_job_id = ?    
          , @p_task_id = ?  
          , @p_template_job = ?
          , @p_new_job = ?
          , @p_description = ?
          , @p_state = ?
          , @p_threads = ?
          , @p_scheduler = ?
          , @p_logs = ?
          , @p_okay = ?
          , @p_fail = ?
          , @p_return_code = @out OUTPUT  
          , @p_return_msg = @out1 OUTPUT   
          , @p_result   = @out2 OUTPUT;   
            SELECT @out AS return_code,@out1 AS return_msg,@out2 AS return_result;"""
        Parameters=[sequence,jobName,taskName,jobId,taskId,TemplateJob,NewJob,Description,State,Threads,Schedule,Logs,SuccessCmd,FailureCmd]
        cursor = conn.cursor()
        cursor.execute(sql,Parameters)
        returnValues=cursor.fetchall()
        conn.commit()
        cursor.close()
        return returnValues
    except  Exception as exceptionError:
        print(-2)
        print ("Error in Job " +TemplateJob)
        raise
#
#.DESCRIPTION
#Wrapper function for the Ws_Job_CreateWait API procedure.
#For more information about usage or return values, refer to the Callable Routines API section of the user guide.
##.EXAMPLE
#WsJobCreateWait ("DailyUpdate","DailyUpdate_${env:WSL_SEQUENCE}","ONCE" , 5,e (Get-Date "2017-10-3").DateTime)
#
def WsJobCreateWait(
        TemplateJob = '',
        NewJob = '',
        Description ='',
        State = '',
        ReleaseTime = '',
        Threads = 0,
        Scheduler = '',
        Logs = 0,
        SuccessCmd = '',
        FailureCmd =''
    ):
    sequence = os.environ["WSL_SEQUENCE"]
    jobName = os.environ["WSL_JOB_NAME"]
    taskName = os.environ["WSL_TASK_NAME"]
    jobId = os.environ["WSL_JOB_KEY"]
    taskId = os.environ["WSL_TASK_KEY"]
    uid=str(os.environ.get('WSL_META_USER',''))
    pwd=str(os.environ.get('WSL_META_PWD',''))
    ConnectionString = "DSN="+str(os.environ.get('WSL_META_DSN',''))
    if uid and not uid.isspace():
      ConnectionString += ";UID="+uid
    if pwd and not pwd.isspace():
      ConnectionString += ";PWD="+pwd 
    try:
        conn = pyodbc.connect(ConnectionString)
        if str(os.environ.get('WSL_META_SCHEMA','')) == "red.":
            sql = """ SELECT red.WsJobCreateWait(?,?,?,?,?,?,?,?,?,?,?,?,?,?,?); """
        else:
            sql=""" 
            DECLARE @out nvarchar(max),@out1 nvarchar(max),@out2 nvarchar(max);
            EXEC Ws_Job_CreateWait
            @p_sequence  =?
          ,	@p_job_name  = ? 
          , @p_task_name  = ?    
          , @p_job_id = ?    
          , @p_task_id = ?  
          , @p_template_job = ?
          , @p_new_job = ?
          , @p_description = ?
          , @p_state = ?
          , @p_release_time = ?
          , @p_threads = ?
          , @p_scheduler = ?
          , @p_logs = ?
          , @p_okay = ?
          , @p_fail = ?
          , @p_return_code = @out OUTPUT  
          , @p_return_msg = @out1 OUTPUT   
          , @p_result   = @out2 OUTPUT;   
        `   SELECT @out AS return_code,@out1 AS return_msg,@out2 AS return_result;"""
        Parameters=[sequence,jobName,taskName,jobId,taskId,TemplateJob,NewJob,Description,State,ReleaseTime,Threads,Schedule,Logs,SuccessCmd,FailureCmd]
        cursor = conn.cursor()
        cursor.execute(sql,Parameters)
        returnValues=cursor.fetchall()
        conn.commit()
        cursor.close()
        return returnValues
    except  Exception as exceptionError:
        print(-2)
        print ("Error in Job " +TemplateJob)
        raise

#
#.DESCRIPTION
#Wrapper function for the Ws_Job_Release API procedure.
#For more information about usage or return values, refer to the Callable Routines API section of the user guide.
#.EXAMPLE
#WsJobRelease ("DailyUpdate")
#>
def WsJobRelease(
        ReleaseJob = ''
    ):
    sequence = os.environ["WSL_SEQUENCE"]
    jobName = os.environ["WSL_JOB_NAME"]
    taskName = os.environ["WSL_TASK_NAME"]
    jobId = os.environ["WSL_JOB_KEY"]
    taskId = os.environ["WSL_TASK_KEY"]
    uid=str(os.environ.get('WSL_META_USER',''))
    pwd=str(os.environ.get('WSL_META_PWD',''))
    ConnectionString = "DSN="+str(os.environ.get('WSL_META_DSN',''))
    if uid and not uid.isspace():
      ConnectionString += ";UID="+uid
    if pwd and not pwd.isspace():
      ConnectionString += ";PWD="+pwd 
    try:
        conn = pyodbc.connect(ConnectionString)
        if str(os.environ.get('WSL_META_SCHEMA','')) == "red.":
            sql = """ SELECT red.WsJobRelease(?,?,?,?,?,?); """
        else:
            sql=""" 
            DECLARE @out nvarchar(max),@out1 nvarchar(max),@out2 nvarchar(max);
            EXEC Ws_Job_Release
            @p_sequence  =?
          ,	@p_job_name  = ? 
          , @p_task_name  = ?    
          , @p_job_id = ?    
          , @p_task_id = ?   
          , @p_release_job    = ?     
          , @p_return_code = @out OUTPUT  
          , @p_return_msg = @out1 OUTPUT   
          , @p_result   = @out2 OUTPUT;   
        SELECT @out AS return_code,@out1 AS return_msg,@out2 AS return_result;"""
        Parameters=[sequence,jobName,taskName,jobId,taskId,statusCode,ReleaseJob,ReleaseTime]
        cursor = conn.cursor()
        cursor.execute(sql,Parameters)
        returnValues=cursor.fetchall()
        conn.commit()
        cursor.close()
        return returnValues
    except  Exception as exceptionError:
        print(-2)
        print ("Error in Job " +TemplateJob)
        raise

#
#.DESCRIPTION
#Wrapper function for the Ws_Job_Restart API procedure.
#For more information about usage or return values, refer to the Callable Routines API section of the user guide.
#.EXAMPLE
#WsJobRestart("DailyUpdate")
#
def WsJobRestart(
        RestartJob = ''
    ):
    sequence = os.environ["WSL_SEQUENCE"]
    jobName = os.environ["WSL_JOB_NAME"]
    taskName = os.environ["WSL_TASK_NAME"]
    jobId = os.environ["WSL_JOB_KEY"]
    taskId = os.environ["WSL_TASK_KEY"]
    uid=str(os.environ.get('WSL_META_USER',''))
    pwd=str(os.environ.get('WSL_META_PWD',''))
    ConnectionString = "DSN="+str(os.environ.get('WSL_META_DSN',''))
    if uid and not uid.isspace():
      ConnectionString += ";UID="+uid
    if pwd and not pwd.isspace():
      ConnectionString += ";PWD="+pwd 
    try:
        conn = pyodbc.connect(ConnectionString)
        if str(os.environ.get('WSL_META_SCHEMA','')) == "red.":
            sql = """ SELECT red.WsJobRestart(?,?,?,?,?,?,?); """
        else:
            sql=""" 
            DECLARE @out nvarchar(max),@out1 nvarchar(max),@out2 nvarchar(max);
            EXEC Ws_Job_Restart
            @p_sequence  =?
          ,	@p_job_name  = ? 
          , @p_task_name  = ?    
          , @p_job_id = ?    
          , @p_task_id = ?   
          , @p_release_job    = ?   
          , @p_release_time = ?   
          , @p_return_code = @out OUTPUT  
          , @p_return_msg = @out1 OUTPUT   
          , @p_result   = @out2 OUTPUT;   
            SELECT @out AS return_code,@out1 AS return_msg,@out2 AS return_result;"""
        Parameters=[sequence,jobName,taskName,jobId,taskId,statusCode,ReleaseJob]
        cursor = conn.cursor()
        cursor.execute(sql,Parameters)
        returnValues=cursor.fetchall()
        conn.commit()
        cursor.close()
        return returnValues
    except  Exception as exceptionError:
        print(-2)
        print ("Error in Job " +TemplateJob)
        raise
    #
#.DESCRIPTION
#Wrapper function for the Ws_Job_Schedule API procedure.
#For more information about usage or return values, refer to the Callable Routines API section of the user guide.
#.EXAMPLE
#WsJobSchedule( "DailyUpdate", (Get-Date "2017-10-3 19:30").DateTime)
#
def WsJobSchedule(
        ReleaseJob = '',
        ReleaseTime = ''
    ): 
    sequence = os.environ["WSL_SEQUENCE"]
    jobName = os.environ["WSL_JOB_NAME"]
    taskName = os.environ["WSL_TASK_NAME"]
    jobId = os.environ["WSL_JOB_KEY"]
    taskId = os.environ["WSL_TASK_KEY"]
    uid=str(os.environ.get('WSL_META_USER',''))
    pwd=str(os.environ.get('WSL_META_PWD',''))
    ConnectionString = "DSN="+str(os.environ.get('WSL_META_DSN',''))
    if uid and not uid.isspace():
      ConnectionString += ";UID="+uid
    if pwd and not pwd.isspace():
      ConnectionString += ";PWD="+pwd 
    try:
        conn = pyodbc.connect(ConnectionString)
        if str(os.environ.get('WSL_META_SCHEMA','')) == "red.":
            sql = """ SELECT red.WsJobSchedule(?,?,?,?,?,?,?); """
        else:
            sql=""" 
            DECLARE @out nvarchar(max),@out1 nvarchar(max),@out2 nvarchar(max);
            EXEC @rc=Ws_Job_Schedule
            @p_sequence  =?
          ,	@p_job_name  = ? 
          , @p_task_name  = ?    
          , @p_job_id = ?    
          , @p_task_id = ?   
          , @p_release_job    = ?   
          , @p_release_time = ?   
          , @p_return_code = @out OUTPUT  
          , @p_return_msg = @out1 OUTPUT   
          , @p_result   = @out2 OUTPUT;   
            SELECT rc as status,@out AS return_code,@out1 AS return_msg,@out2 AS return_result;"""
        Parameters=[sequence,jobName,taskName,jobId,taskId,statusCode,ReleaseJob,ReleaseTime]
        cursor = conn.cursor()
        cursor.execute(sql,Parameters)
        returnValues=cursor.fetchall()
        conn.commit()
        cursor.close()
        return returnValues
    except  Exception as exceptionError:
        print(-2)
        print ("Error in Job " +ReleaseJob)
        raise
    
#
#.DESCRIPTION
#Wrapper function for the Ws_Job_Status API procedure.
#For more information about usage or return values, refer to the Callable Routines API section of the user guide.
#.EXAMPLE
#WsJobStatus( "DailyUpdate" ,120)
#Ws_Job_Status -CheckJob "DailyUpdate" -StartedAfterDt (Get-Date).AddHours(-2).DateTime
#>
def WsJobStatus(
        CheckSequence = '',
        CheckJob = '',
        StartedInLastMins = '',
        StartedAfterDt =''
    ):
    sequence = os.environ["WSL_SEQUENCE"]
    jobName = os.environ["WSL_JOB_NAME"]
    taskName = os.environ["WSL_TASK_NAME"]
    jobId = os.environ["WSL_JOB_KEY"]
    taskId = os.environ["WSL_TASK_KEY"]
    uid=str(os.environ.get('WSL_META_USER',''))
    pwd=str(os.environ.get('WSL_META_PWD',''))
    ConnectionString = "DSN="+str(os.environ.get('WSL_META_DSN',''))
    if uid and not uid.isspace():
      ConnectionString += ";UID="+uid
    if pwd and not pwd.isspace():
      ConnectionString += ";PWD="+pwd 
    try:
        conn = pyodbc.connect(ConnectionString)
        if str(os.environ.get('WSL_META_SCHEMA','')) == "red.":
            sql = """ SELECT red.WsJobStatus(?,?,?,?,?,?,?,?,?); """
        else:
            sql=""" 
            DECLARE @out nvarchar(max),@out1 nvarchar(max),@out2 nvarchar(max),@out3 nvarchar(max),@out4 nvarchar(max),@out5 nvarchar(max);
            EXEC @rc=Ws_Job_Schedule
            @p_sequence  =?
          ,	@p_job_name  = ? 
          , @p_task_name  = ?    
          , @p_job_id = ?    
          , @p_task_id = ?   
          , @p_check_sequence =?
          , @p_check_job = ?
          , @p_started_in_last_mi = ?
          , @p_started_after_dt = ?
          , @p_return_code = @out OUTPUT  
          , @p_return_msg = @out1 OUTPUT   
          , @p_result   = @out2 OUTPUT;   
          , @p_job_status_simple   = @out3 OUTPUT; 
          , @p_job_status_standard   = @out4 OUTPUT; 
          , @p_job_status_enhanced   = @out5 OUTPUT; 
            SELECT @out AS return_code,@out1 AS return_msg,@out2 AS return_result,@out3 AS p_job_status_simple,@out4 AS p_job_status_standard,@out5 AS p_job_status_enhanced;"""
        Parameters=[sequence,jobName,taskName,jobId,taskId,CheckSequence,CheckJob,StartedInLastMins,StartedAfterDt]
        cursor = conn.cursor()
        cursor.execute(sql,Parameters)
        returnValues=cursor.fetchall()
        conn.commit()
        cursor.close()
        return returnValues
    except  Exception as exceptionError:
        print(-2)
        print ("Error in Job " +ReleaseJob)
        raise
    

#
#.DESCRIPTION
#Wrapper function for the Ws_Load_Change API procedure.
#For more information about usage or return values, refer to the Callable Routines API section of the user guide.
#.EXAMPLE
#WsLoadChange( "SCHEMA","load_customers","site2")
#Ws_Load_Change -Action "CONNECTION" -Table "load_customers" -NewValue "Sales2"
#>
def WsLoadChange(
        Action = '',
        Table = '',
        NewValue = ''
    ):
    sequence = os.environ["WSL_SEQUENCE"]
    jobName = os.environ["WSL_JOB_NAME"]
    taskName = os.environ["WSL_TASK_NAME"]
    jobId = os.environ["WSL_JOB_KEY"]
    taskId = os.environ["WSL_TASK_KEY"]
    uid=str(os.environ.get('WSL_META_USER',''))
    pwd=str(os.environ.get('WSL_META_PWD',''))
    ConnectionString = "DSN="+str(os.environ.get('WSL_META_DSN',''))
    if uid and not uid.isspace():
      ConnectionString += ";UID="+uid
    if pwd and not pwd.isspace():
      ConnectionString += ";PWD="+pwd
    try:
        conn = pyodbc.connect(ConnectionString)
        if str(os.environ.get('WSL_META_SCHEMA','')) == "red.":
            sql = """ SELECT red.WsLoadChange(?,?,?,?,?,?,?,?); """
        else:
            sql=""" 
            DECLARE @out nvarchar(max),@out1 nvarchar(max),@out2 nvarchar(max);
            EXEC Ws_Load_Change
            @p_sequence  =?
          ,	@p_job_name  = ? 
          , @p_task_name  = ?    
          , @p_job_id = ?    
          , @p_task_id = ?   
          , @p_action   = ?   
          , @p_table = ?   
          , @p_new_value = ? 
          , @p_return_code = @out OUTPUT  
          , @p_return_msg = @out1 OUTPUT   
          , @p_result   = @out2 OUTPUT;   
            SELECT rc as status,@out AS return_code,@out1 AS return_msg,@out2 AS return_result;"""
        Parameters=[sequence,jobName,taskName,jobId,taskId,Action,Table,NewValue]
        cursor = conn.cursor()
        cursor.execute(sql,Parameters)
        returnValues=cursor.fetchall()
        conn.commit()
        cursor.close()
        return returnValues
    except  Exception as exceptionError:
        print(-2)
        print ("Error in Load table  " +Table)
        raise
    

#
#.DESCRIPTION
#Wrapper function for the Ws_Maintain_Indexes API procedure.
#For more information about usage or return values, refer to the Callable Routines API section of the user guide.
#.EXAMPLE
#WsMaintainIndexes("dim_date","BUILD ALL")
#Ws_Maintain_Indexes -IndexName "dim_date_idx_0" -Option "DROP"
#
def WsMaintainIndexes(
        TableName ='',
        IndexName ='',
        Option =''
    ):
    sequence = os.environ["WSL_SEQUENCE"]
    jobName = os.environ["WSL_JOB_NAME"]
    taskName = os.environ["WSL_TASK_NAME"]
    jobId = os.environ["WSL_JOB_KEY"]
    taskId = os.environ["WSL_TASK_KEY"]
    uid=str(os.environ.get('WSL_META_USER',''))
    pwd=str(os.environ.get('WSL_META_PWD',''))
    ConnectionString = "DSN="+str(os.environ.get('WSL_META_DSN',''))
    if uid and not uid.isspace():
      ConnectionString += ";UID="+uid
    if pwd and not pwd.isspace():
      ConnectionString += ";PWD="+pwd 
    try:
        conn = pyodbc.connect(ConnectionString)
        if str(os.environ.get('WSL_META_SCHEMA','')) == "red.":
            sql = """ SELECT red.WsMaintainIndexes(?,?,?,?,?,?,?,?); """
        else:
            sql=""" 
            DECLARE @out nvarchar(max),@out1 nvarchar(max),@out2 nvarchar(max);
            EXEC Ws_Maintain_Indexes
            @p_sequence  =?
          ,	@p_job_name  = ? 
          , @p_task_name  = ?    
          , @p_job_id = ?    
          , @p_task_id = ?   
          , @p_table_name   = ?   
          , @p_index_name = ?   
          , @p_option = ? 
          , @p_return_code = @out OUTPUT;   
            SELECT @out AS return_code;"""
        Parameters=[sequence,jobName,taskName,jobId,taskId,TableName,Table,IndexName,Option]
        cursor = conn.cursor()
        cursor.execute(sql,Parameters)
        returnValues=cursor.fetchall()
        conn.commit()
        cursor.close()
        return returnValues
    except  Exception as exceptionError:
        print(-2)
        print ("Error in  table  " +TableName)
        raise

#
#.DESCRIPTION
#Wrapper function for the Ws_Version_Clear API procedure.
#For more information about usage or return values, refer to the Callable Routines API section of the user guide.
#.EXAMPLE
#WsVersionClear(60)
#>
def WsVersionClear(
        DayCount = 0,
        KeepCount = 0
    ):
    sequence = os.environ["WSL_SEQUENCE"]
    jobName = os.environ["WSL_JOB_NAME"]
    taskName = os.environ["WSL_TASK_NAME"]
    jobId = os.environ["WSL_JOB_KEY"]
    taskId = os.environ["WSL_TASK_KEY"]
    uid=str(os.environ.get('WSL_META_USER',''))
    pwd=str(os.environ.get('WSL_META_PWD',''))
    ConnectionString = "DSN="+str(os.environ.get('WSL_META_DSN',''))
    if uid and not uid.isspace():
      ConnectionString += ";UID="+uid
    if pwd and not pwd.isspace():
      ConnectionString += ";PWD="+pwd 
    try:
        conn = pyodbc.connect(ConnectionString)
        if str(os.environ.get('WSL_META_SCHEMA','')) == "red.":
            sql = """ SELECT red.WsVersionClear(?,?,?,?,?,?,?); """
        else:
            sql=""" 
            DECLARE @out nvarchar(max),@out1 nvarchar(max),@out2 nvarchar(max);
            EXEC Ws_Version_Clear
            @p_sequence  =?
          ,	@p_job_name  = ? 
          , @p_task_name  = ?    
          , @p_job_id = ?    
          , @p_task_id = ?   
          , @p_day_count   = ?   
          , @p_keep_count = ?   
          , @p_return_code = @out OUTPUT  
          , @p_return_msg = @out1 OUTPUT   
          , @p_result   = @out2 OUTPUT;   
            SELECT rc as status,@out AS return_code,@out1 AS return_msg,@out2 AS return_result;"""
        Parameters=[sequence,jobName,taskName,jobId,taskId,DayCount,KeepCount]
        cursor = conn.cursor()
        cursor.execute(sql,Parameters)
        returnValues=cursor.fetchall()
        conn.commit()
        cursor.close()
        return returnValues
    except  Exception as exceptionError:
        print(-2)
        print ("Error in  Job  " +jobName)
        raise
    
#
#.DESCRIPTION
#Used to hide the evil black box of death
#win32console -- Interface to the Windows Console functions for dealing with character-mode applications
#win32gui -- Python extensions for Microsoft Windows’ Provides access to much of the Win32 API
#ShowWindow -- '0' passed to hide console window
def HideWindow():
    hwnd=int(win32console.GetConsoleWindow())
    win32gui.ShowWindow(hwnd,0) 
    return True 
#ShowWindow -- '1' passed to show console window 
def UnhideWindow():
    hwnd=int(win32console.GetConsoleWindow())
    win32gui.ShowWindow(hwnd,1)
    return True 
#
#.DESCRIPTION
#Wrapper function for the WsParameterRead API procedure.
#For more information about usage or return values, refer to the Callable Routines API section of the user guide.
#.EXAMPLE
#WsParameterRead ("CURRENT_DAY")
#
def WsParameterRead(
        ParameterName = ''
    ):
    if str(os.environ.get('WSL_META_SCHEMA','')) == "red.":
        sql = """ SELECT red.WsParameterRead(?); """
    else:
        sql=""" 
        DECLARE @out varchar(max),@out1 varchar(max);
        EXEC WsParameterRead
        @p_parameter = ? 
       ,@p_value = @out OUTPUT
       ,@p_comment=@out1 OUTPUT;
        SELECT @out AS p_value,@out1 AS p_comment;"""
    Parameters=[ParameterName]
    uid=str(os.environ.get('WSL_META_USER',''))
    pwd=str(os.environ.get('WSL_META_PWD',''))
    ConnectionString = "DSN="+str(os.environ.get('WSL_META_DSN',''))
    if uid and not uid.isspace():
      ConnectionString += ";UID="+uid
    if pwd and not pwd.isspace():
      ConnectionString += ";PWD="+pwd  
    try:
        conn = pyodbc.connect(ConnectionString)
        cursor=conn.cursor()
        number_of_rows=cursor.execute(sql,Parameters)
        rows=cursor.fetchall()
        conn.commit()
        cursor.close()
        return rows
    except  Exception as exceptionError:
        print(-2)
        print ("Error in  Parameter Read  " +ParameterName)
        raise

#
#.DESCRIPTION
#Wrapper function for the WsParameterWrite API procedure.
#For more information about usage or return values, refer to the Callable Routines API section of the user guide.
#.EXAMPLE
#WsParameterWrite("CURRENT_DAY","Monday" ,"The current day of the week")
#
def WsParameterWrite(
        ParameterName    = '',
        ParameterValue   = '',
        ParameterComment = ''
    ):
    sql = "{call "+os.environ.get('WSL_META_SCHEMA','')+"WsParameterWrite (?,?,?)}"
    Parameters=[ParameterName,ParameterValue,ParameterComment]
    uid=str(os.environ.get('WSL_META_USER',''))
    pwd=str(os.environ.get('WSL_META_PWD',''))
    ConnectionString = "DSN="+str(os.environ.get('WSL_META_DSN',''))
    if uid and not uid.isspace():
      ConnectionString += ";UID="+uid
    if pwd and not pwd.isspace():
      ConnectionString += ";PWD="+pwd 
    try:
        conn = pyodbc.connect(ConnectionString)
        cursor=conn.cursor()
        number_of_rows=cursor.execute(sql,Parameters)
        #rows=cursor.fetchall()
        conn.commit()
        cursor.close()
        return number_of_rows
    except  Exception as exceptionError:
        print(-2)
        print ("Error in  Parameter Write  " +ParameterName)
        raise


 
#.DESCRIPTION
#Wrapper function for the WsWrkAudit API procedure.
#For more information about usage or return values, refer to #the Callable Routines API section of the user guide.
#.EXAMPLE
#WsWrkAudit -Message "This is an audit log INFO message created #by calling WsWrkAudit"
#WsWrkAudit -StatusCode "E" -Message "This is an audit log ERROR message created by calling WsWrkAudit"
#
def WsWrkAudit(
        StatusCode = 'I',
        Message='',
        DBCode='',
        DBMessage=''):
    sql = "{call "+os.environ.get('WSL_META_SCHEMA','')+"WsWrkAudit (?,?,?,?,?,?,?,?,?)}"
    
    uid=str(os.environ.get('WSL_META_USER',''))
    pwd=str(os.environ.get('WSL_META_PWD',''))
    ConnectionString = "DSN="+str(os.environ.get('WSL_META_DSN',''))
    if uid and not uid.isspace():
      ConnectionString += ";UID="+uid
    if pwd and not pwd.isspace():
      ConnectionString += ";PWD="+pwd
    sequence = os.environ["WSL_SEQUENCE"]
    jobName = os.environ["WSL_JOB_NAME"]
    taskName = os.environ["WSL_TASK_NAME"]
    jobId = os.environ["WSL_JOB_KEY"]
    taskId = os.environ["WSL_TASK_KEY"]
   
    Parameters=[StatusCode,jobName,taskName,sequence,Message,DBCode,DBMessage,taskId,jobId]
    try:
        conn = pyodbc.connect(ConnectionString)
        cursor=conn.cursor()
        numberOfRows=cursor.execute(sql,Parameters)
        conn.commit()
        cursor.close()
        return numberOfRows
    except  Exception as exceptionError:
        print(-2)
        print ("Error in  Parameter Read  " +ParameterName)
        raise
    
#.DESCRIPTION
#Wrapper function for the WsWrkTask API procedure.
#For more information about usage or return values, refer to the Callable Routines API section of the user guide.
##.EXAMPLE
#WsWrkTask(20, 35)
#>
def WsWrkTask(
        Inserted = 0,
        Updated = 0,
        Replaced = 0,
        Deleted = 0,
        Discarded = 0,
        Rejected = 0,
        Errored = 0
    ):
    sequence = os.environ["WSL_SEQUENCE"]
    jobName = os.environ["WSL_JOB_NAME"]
    taskName = os.environ["WSL_TASK_NAME"]
    jobId = os.environ["WSL_JOB_KEY"]
    taskId = os.environ["WSL_TASK_KEY"]
    
    uid=str(os.environ.get('WSL_META_USER',''))
    pwd=str(os.environ.get('WSL_META_PWD',''))
    ConnectionString = "DSN="+str(os.environ.get('WSL_META_DSN',''))
    if uid and not uid.isspace():
      ConnectionString += ";UID="+uid
    if pwd and not pwd.isspace():
      ConnectionString += ";PWD="+pwd

    if str(os.environ.get('WSL_META_SCHEMA','')) == "red.":
        sql = """ SELECT red.WsWrkTask(?,?,?,?,?,?,?,?,?,?); """
    else:
        sql=""" 
        SET NOCOUNT ON
        DECLARE @out nvarchar(max);
        EXEC @out=WsWrkTask
        @p_job_key = ? 
      , @p_task_key = ?    
      , @p_sequence = ?    
      , @p_inserted = ?   
      , @p_updated   = ?   
      , @p_replaced  = ?   
      , @p_deleted    = ?  
      , @p_discarded  = ?  
      , @p_rejected  = ?   
      , @p_errored   = ?;
        SELECT @out AS return_value;"""
    uid=str(os.environ.get('WSL_META_USER',''))
    pwd=str(os.environ.get('WSL_META_PWD',''))
    ConnectionString = "DSN="+str(os.environ.get('WSL_META_DSN',''))
    if uid and not uid.isspace():
      ConnectionString += ";UID="+uid
    if pwd and not pwd.isspace():
      ConnectionString += ";PWD="+pwd
    Parameters=[jobId,taskId,sequence,Inserted,Updated,Replaced,Deleted,Discarded,Rejected,Errored]
    try:
        conn = pyodbc.connect(ConnectionString)
        cursor = conn.cursor()
        cursor.fast_executemany = False
        cursor.execute(sql,Parameters)
        return_values=cursor.fetchone()
        nextNumber = return_values[0]
        conn.commit()
        cursor.close()
        return nextNumber
    except  Exception as exceptionError:
        print(-2)
        print ("Error in  Jobid   " +jobId)
        raise 
    
    
#
#.DESCRIPTION
#Wrapper function for the WsWrkError API procedure.
#For more information about usage or return values, refer to the Callable Routines API section of the user guide.
#.EXAMPLE
#WsWrkError ( "This is a detail log INFO message created by calling WsWrkAudit")
#WsWrkError -StatusCode "E" -Message "This is a detail log ERROR message created by calling WsWrkAudit"
#>
def WsWrkError(
        statusCode  = 'I',
        message     = '',
        dbCode      = '',
        dbMessage   = '',
        messageType = ''
    ):
    sequence = os.environ["WSL_SEQUENCE"]
    jobName = os.environ["WSL_JOB_NAME"]
    taskName = os.environ["WSL_TASK_NAME"]
    jobId = os.environ["WSL_JOB_KEY"]
    taskId = os.environ["WSL_TASK_KEY"]
    uid=str(os.environ.get('WSL_META_USER',''))
    pwd=str(os.environ.get('WSL_META_PWD',''))
    ConnectionString = "DSN="+str(os.environ.get('WSL_META_DSN',''))
    if uid and not uid.isspace():
      ConnectionString += ";UID="+uid
    if pwd and not pwd.isspace():
      ConnectionString += ";PWD="+pwd 
    conn = pyodbc.connect(ConnectionString)
    
    sql = "{call "+os.environ.get('WSL_META_SCHEMA','')+"WsWrkError (?,?,?,?,?,?,?,?,?,?)}"
    Parameters=[statusCode,jobName,taskName,sequence,message,dbCode,dbMessage,taskId,jobId,messageType]
    try:
        cursor = conn.cursor()
        cnt=cursor.execute(sql,Parameters).rowcount
        if cnt>0:
         nextNum = 1
        else:
          nextNum=0
        conn.commit()
        cursor.close()
        return nextNum
    except  Exception as exceptionError:
        print(-2)
        print ("Error in  Jobid   " +jobId)
        raise 
    
def GetExtendedProperty( 
        propertyName,
        tableName
    ):
    if str(os.environ.get('WSL_META_SCHEMA','')) == "red.":
        sql=""" 
              SELECT COALESCE(tab.epv_value, src.epv_value, tgt.epv_value, '')
              FROM """+os.environ.get("WSL_META_SCHEMA","")+"""ws_ext_prop_def def
              LEFT OUTER JOIN """+os.environ.get("WSL_META_SCHEMA","")+"""ws_ext_prop_value tab
              ON tab.epv_obj_key = ( SELECT oo_obj_key 
                                     FROM """+os.environ.get("WSL_META_SCHEMA","")+"""ws_obj_object 
                                     WHERE UPPER(oo_name) = UPPER('"""+tableName+"""')
                                   )
              AND tab.epv_def_key = def.epd_key
              LEFT OUTER JOIN """+os.environ.get("WSL_META_SCHEMA","")+"""ws_ext_prop_value src
              ON src.epv_obj_key = ( SELECT lt_connect_key 
                                     FROM """+os.environ.get("WSL_META_SCHEMA","")+"""ws_load_tab 
                                     WHERE UPPER(lt_table_name) = UPPER('"""+tableName+"""')
                                   )
              AND src.epv_def_key = def.epd_key
              LEFT OUTER JOIN """+os.environ.get("WSL_META_SCHEMA","")+"""ws_ext_prop_value tgt
              ON tgt.epv_obj_key = ( SELECT dc_obj_key
                                     FROM """+os.environ.get("WSL_META_SCHEMA","")+"""ws_dbc_connect
                                     JOIN """+os.environ.get("WSL_META_SCHEMA","")+"""ws_dbc_target
                                     ON dt_connect_key = dc_obj_key
                                     JOIN """+os.environ.get("WSL_META_SCHEMA","")+"""ws_obj_object
                                     ON oo_target_key = dt_target_key
                                     WHERE UPPER(oo_name) = UPPER('"""+tableName+"""')
                                   )
              AND tgt.epv_def_key = def.epd_key
              LEFT OUTER JOIN """+os.environ.get("WSL_META_SCHEMA","")+"""ws_ext_prop_value xpt
              ON xpt.epv_obj_key = ( SELECT dc_obj_key
                                     FROM """+os.environ.get("WSL_META_SCHEMA","")+"""ws_dbc_connect
                                     JOIN """+os.environ.get("WSL_META_SCHEMA","")+"""ws_export_tab
                                     ON et_connect_key = dc_obj_key
                                     WHERE UPPER(et_table_name) = UPPER('"""+tableName+"""')
                                   )
              AND xpt.epv_def_key = def.epd_key																															 
              WHERE UPPER(def.epd_variable_name) = UPPER('"""+propertyName+"""')
            """
    else:
        sql=""" 
          SELECT COALESCE(tab.epv_value, src.epv_value, tgt.epv_value, '')
          FROM ws_ext_prop_def def
          LEFT OUTER JOIN ws_ext_prop_value tab
          ON tab.epv_obj_key = ( SELECT oo_obj_key 
                                 FROM ws_obj_object 
                                 WHERE UPPER(oo_name) = UPPER('"""+tableName+"""')
                               )
          AND tab.epv_def_key = def.epd_key
          LEFT OUTER JOIN ws_ext_prop_value src
          ON src.epv_obj_key = ( SELECT lt_connect_key 
                                 FROM ws_load_tab 
                                 WHERE UPPER(lt_table_name) = UPPER('"""+tableName+"""')
                               )
          AND src.epv_def_key = def.epd_key
          LEFT OUTER JOIN ws_ext_prop_value tgt
          ON tgt.epv_obj_key = ( SELECT dc_obj_key
                                 FROM ws_dbc_connect
                                 JOIN ws_dbc_target
                                 ON dt_connect_key = dc_obj_key
                                 JOIN ws_obj_object
                                 ON oo_target_key = dt_target_key
                                 WHERE UPPER(oo_name) = UPPER('"""+tableName+"""')
                               )
          AND tgt.epv_def_key = def.epd_key
          WHERE UPPER(def.epd_variable_name) = UPPER('"""+propertyName+"""')
          """
    try:
        uid=str(os.environ.get('WSL_META_USER',''))
        pwd=str(os.environ.get('WSL_META_PWD',''))
        ConnectionString = "DSN="+str(os.environ.get('WSL_META_DSN',''))
        if uid and not uid.isspace():
          ConnectionString += ";UID="+uid
        if pwd and not pwd.isspace():
          ConnectionString += ";PWD="+pwd    
        conn = pyodbc.connect(ConnectionString)
        cursor = conn.cursor()
        cursor.execute(sql)
        return_values=cursor.fetchone()
        conn.commit()
        cursor.close()
        if return_values is None:
            return ""
        return return_values[0]
    except  Exception as exceptionError:
        print(-2)
        print ("Error getting Extended Property " +propertyName)
        raise 
        
     
def GetFileFormatFullName( 
        fileFormat
    ):
    if str(os.environ.get('WSL_META_SCHEMA','')) == "red.":
        sql=""" 
           SELECT dt_database,dt_schema
           FROM """+os.environ.get("WSL_META_SCHEMA","")+"""ws_dbc_target
           INNER JOIN """+os.environ.get("WSL_META_SCHEMA","")+"""ws_obj_object
           ON dt_target_key = oo_target_key
           where oo_name='"""+fileFormat+"'"
    else:
        sql=""" 
           SELECT dt_database,dt_schema
           FROM ws_dbc_target
           INNER JOIN ws_obj_object
           ON dt_target_key = oo_target_key
           where oo_name='"""+fileFormat+"'"
    
    uid=str(os.environ.get('WSL_META_USER',''))
    pwd=str(os.environ.get('WSL_META_PWD',''))
    ConnectionString = "DSN="+str(os.environ.get('WSL_META_DSN',''))
    if uid and not uid.isspace():
      ConnectionString += ";UID="+uid
    if pwd and not pwd.isspace():
      ConnectionString += ";PWD="+pwd   
    try:
        conn = pyodbc.connect(ConnectionString)
        cursor = conn.cursor()
        cursor.execute(sql)
        returnValues=cursor.fetchone()
        conn.commit()
        cursor.close()
        if returnValues == None:
           returnValues = ""
        elif not returnValues[0].strip() or returnValues[0].strip() == None:
           returnValues = returnValues[1]
        elif not returnValues[1].strip() or returnValues[1].strip() == None:
           returnValues = returnValues[0]
        else:
           returnValues = returnValues[0]+"."+returnValues[1]
        return returnValues
    except  Exception as exceptionError:
        print(-2)
        print ("Error getting Extended Property " +propertyName)
        raise 

#.DESCRIPTION
#Used to run any SQL against any ODBC DSN
#.EXAMPLE
#RunRedSQL( "SELECT * FROM stage_customers","dssdemo")
#options is the extra argument required for connection string for adding more parameters
def RunRedSQL(
                sql,
                dsn,
                uid,
                pwd,
                connection="",
                options=''
               ):
    connectionString = 'DSN='+dsn
    if uid and not uid.isspace():
        connectionString +=';UID='+uid
    if pwd and not pwd.isspace():
        connectionString +=';PWD='+pwd
    connectionString += options   
    numberOfRows=0
    rows=''
    infoEvent=''
    flag=0
    try:
        if sql and not sql.isspace():
         if connection not in (None, ""):
           cursor=connection.cursor().execute(sql)
         else:
           if connection=="":
             flag=1
           connection = pyodbc.connect(connectionString, autocommit=True)
           cursor=connection.cursor().execute(sql)    
                     
    except Exception as e:
           return connection,-2,0,e.args,rows
    try:

        if sql.lstrip().startswith("SELECT")==True:
         try:
          rows = cursor.fetchall()
          numberOfRows=len(rows)
         except Exception as inst:
            infoEvent=inst
        else:
           numberOfRows=cursor.rowcount
        if flag==1:
         connection.commit()
         connection.close()
        return connection,1,numberOfRows,infoEvent,rows
    except pyodbc.Error as ex:
        sqlstate = ex.args[0]
        return connection,-2,numberOfRows,ex.args,rows  

        
def SplitThresholdExceeded(query, dsn,uid,pwd, splitThreshold):
    numberOfRows=RunRedSQL(query, dsn,uid,pwd)
    split=False
    if numberOfRows[2] >=splitThreshold :
         split = True
    return split    
     
def  GetDataToFile( query,dsn,uid,pwd,dataFile,delimiter,fileCount,splitThreshold,addQuotes,unicode,enclosedBy,escapeChar):  
  try:
    connectionString = 'DSN='+dsn
    if uid and not uid.isspace():
        connectionString +=';UID='+uid
    if pwd and not pwd.isspace():
        connectionString +=';PWD='+pwd
    connection = pyodbc.connect(connectionString, autocommit=True)
    cursor = connection.cursor() 
    cursor.execute(query)
    
    rowCount = 0
    cntRecords=0
    fileNumber=0
    encoding_type = ''
    fileObjects=[]
    shouldSplit = False
    
    if unicode==True:
        encoding_type = 'utf-8'  
    else:
        encoding_type = 'ascii'
   
    if fileCount > 1 and splitThreshold > 0:
       shouldSplit = SplitThresholdExceeded(query, dsn,uid,pwd, splitThreshold)
    
    fileList =[dataFile + ".txt"]
    
    f = open(fileList[fileNumber],encoding=encoding_type, mode='a+',errors='replace')
    fileObjects.insert(0,f)
    
    if shouldSplit==True:
       i=1
       while i < fileCount:
        fileList.append(dataFile + "_" + str(i) + ".txt")
        f = open(fileList[i],encoding=encoding_type, mode='a+',errors='replace')
        fileObjects.insert(i,f)
        i=i+1    

    for row in cursor:
        rowCount=rowCount+1
        recordList=[]
        for eachValue in row: 
           dataVal=eachValue        
           if addQuotes == True:
             if escapeChar and not escapeChar.isspace():
               dataVal = str(dataVal).replace(escapeChar, escapeChar + escapeChar)
             dataVal =str(dataVal).replace(enclosedBy,escapeChar + enclosedBy)

             if dataVal=='None':
               dataVal=""
             # enclose the value with enclosedBy chars
             dataVal = enclosedBy + dataVal + enclosedBy
             recordList.append(dataVal)
           else:
             #if not enclosedBy set, strip out delimiter char
              recordList.append(str(dataVal).replace(delimiter,""))
           rowNew = recordList
        formattedRecord = delimiter.join(rowNew).replace("\r","").replace("\n","")
        
        try:
           if fileNumber == fileCount and shouldSplit==True:
                fileNumber = 0
           fileObjects[fileNumber].write(formattedRecord+"\n")
           if fileNumber < fileCount and shouldSplit==True:
              fileNumber=fileNumber+1  
        except Exception as inst:
            print("Error  at line "+formattedRecord)
            print(inst.args)
    
    for file in fileObjects:
      file.close()   
   
    cursor.close      
    connection.close()
    return 1,rowCount
  
  except Exception as inst:
       print(-2)
       print(inst)
       return -2
#.DESCRIPTION
#Used to to create log file and print load result in RED

def PrintLog(fileAud):
    with open(fileAud, 'r') as write_to_console:
     print(write_to_console.read())

#.DESCRIPTION
#Used to to replace wsl tags present in string

def ReplaceWslTags(stuff):
    if '$SEQUENCE$' in stuff:
        stuff = stuff.replace('$SEQUENCE$',str(os.environ.get('WSL_SEQUENCE','')))
    if re.findall(r'\$(.+?)\$',stuff)!=[]:
        # If stuff contains two or more $s and the $SEQUENCE$ string is not detected
        # or has already been replaced then we assume a date
            suppliedFormat = re.findall(r'\$(.+?)\$',stuff)[0]
            dateFormat = suppliedFormat.replace('YYYY','%Y').replace('MMM','%b').replace('MM','%m').replace('DD','%d').replace('HH','%H').replace('MI','%M').replace('SS','%S')
            dateString = datetime.today().strftime(dateFormat)
            replaceString = '$' + suppliedFormat + '$'
            stuff = stuff.replace(replaceString,dateString)
    if stuff.find('$') != -1:
       os.environ["warn"] = True
       print("Unclosed '$' tag in " +stuff)
       print("Unclosed '$' will be removed")
       stuff = stuff.replace('\$','')
    return stuff.strip()

#.DESCRIPTION
#Used to to compress a given file
def GzipFile(
        inFile="No input file specified",
        outFile=".gz",
        removeOriginal=True,
        fileType=""
    ):
    if fileType =="avro":
        import zipfile
        with zipfile.ZipFile(outFile, 'w') as zipavro:
            zipavro.write(inFile)
    if fileType =="parquet":
      import pyarrow as pa
      import pyarrow.parquet as pq
      import pandas as pd
      df = pd.read_parquet(inFile,engine='auto')
      df.to_parquet(outFile+".gz",compression='gzip')
      outNewFile=outFile+".gz"
    else:
      if outFile!=".gz":
        with open(inFile, 'rb') as f_in:
          with gzip.open(outFile+".gz", 'wb') as f_out:
              shutil.copyfileobj(f_in, f_out)
        outNewFile=outFile+".gz"
      else:
         with open(inFile, 'rb') as f_in:
          with gzip.open(os.path.splitext(inFile)[0]+outFile, 'wb') as f_out:
              shutil.copyfileobj(f_in, f_out)
         outNewFile=(inFile+outFile)
      if removeOriginal==True:
          os.remove(inFile)
    return (outNewFile)             


# Function to download files from Amazon S3
def downloadFileFromAmazonS3(accessKey,secretKey,regionName,bucketName,sourcePath,fileName,downloadPath):
  import boto3
  from boto3 import client
  import botocore
# Clients provide a low-level interface to AWS whose methods map close to 1:1 with service APIs.
  client = boto3.client(
    's3',
    aws_access_key_id = accessKey.strip(),
    aws_secret_access_key = secretKey.strip(),
    region_name =regionName
  )
  client.download_file(bucketName,os.path.join(sourcePath,fileName).replace("s3://","").replace(bucketName + '/',"").replace("\\","/").strip(),os.path.join( downloadPath,fileName))

# Function to download files from Google Cloud
def downloadFileFromGoogleCloud(sourceFilePath,fileName,downloadPath):
        import subprocess
        try:
            downloadCmd = "gsutil cp "+str(os.path.join(sourceFilePath,fileName)).replace("\\","/").strip()+" "+os.path.join(downloadPath,fileName)
            returned_output = subprocess.check_output('cmd /c "'+downloadCmd+'"', shell=True,stderr=subprocess.STDOUT)
            returned_output=returned_output.decode('utf-8')
            return returned_output
        except subprocess.CalledProcessError as e:
            print(-2)
            print(e.output)
            sys.exit()

# Function to download files from Azure Data Lake Gen 2 
def downloadFileFromAzureDataLake(storage_account_name,storage_account_key,fileSystem,directory,fileName,downloadPath):
    from azure.storage.filedatalake import DataLakeServiceClient
    from azure.core.exceptions import ResourceExistsError
    import sys, csv
    from azure.storage.blob import BlobServiceClient, ContainerClient, BlobClient, DelimitedTextDialect,DelimitedJsonDialect, BlobQueryError
    try:
        global service_client

        service_client = DataLakeServiceClient(account_url="{}://{}.dfs.core.windows.net".format(
            "https", storage_account_name), credential=storage_account_key)

    except Exception as e:
        print(-2)
        print(e)

    try:
        file_system_client = service_client.get_file_system_client(file_system=fileSystem)

        if directory !='':
          directory_client = file_system_client.get_directory_client(directory)
          file_client = directory_client.get_file_client(fileName)
        else:
          file_client=file_system_client.get_file_client(fileName)
        local_file = open(os.path.join(downloadPath,fileName),'wb')
        download = file_client.download_file()
        
        downloaded_bytes = download.readall()

        local_file.write(downloaded_bytes)

        local_file.close()

    except Exception as e:
     print(-2)
     print(e)   