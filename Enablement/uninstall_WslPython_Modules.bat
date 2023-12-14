@ECHO off
SET ERRORLEVEL=0
REM Check for Admin rights
CALL :isAdmin
IF %ERRORLEVEL% == 0 (
  GOTO :run
) ELSE (
  ECHO This script must be "Run as administrator" 
  ECHO Please right click the script and select "Run as administrator" or run this script from within an administrator cmd prompt.
  PAUSE
  EXIT /B
)
:isAdmin
fsutil dirty query %systemdrive% >nul
EXIT /B
:run
SET scriptpath=%~dp0
SET logfile="%~dpn0.log"
SET errorfile="%~dpn0.err"
ECHO Begining uninstall of WhereScape Python Libs... 1> %logfile% 2> %errorfile%
ECHO Uninstalling WhereScape Python Libs, please Wait..
REM Check for Python and PIP
echo %PATH% |find "Python" > nul 2>&1 && ( GOTO continue_libs_install ) || ( GOTO no_python )
pip --version >nul 2>&1 && ( GOTO continue_libs_install ) || ( GOTO no_pip )
:no_python
ECHO -- >> %logfile%
ECHO ERROR: Python is required, it must be both installed and in the system PATH >> %logfile%
goto end
:no_pip
ECHO -- >> %logfile%
ECHO ERROR: PIP is required, download https://bootstrap.pypa.io/get-pip.py and run: python get-pip.py >> %logfile%
goto end
:continue_libs_install
ECHO -- >> %logfile%
ECHO Uninstalling Python Libraries >> %logfile%
python --version 1>> %logfile% 2>> %errorfile%
python -m pip install --upgrade pip 1>> %logfile% 2>> %errorfile%
REM uninstall libraries using Pip
python -m pip uninstall pywin32-ctypes -y 1>> %logfile% 2>> %errorfile%
python -m pip uninstall python-tds -y 1>> %logfile% 2>> %errorfile%
python -m pip uninstall pywin32 -y 1>> %logfile% 2>> %errorfile%
python -m pip uninstall glob2 -y 1>> %logfile% 2>> %errorfile%
python -m pip uninstall gzip-reader -y 1>> %logfile% 2>> %errorfile%
python -m pip uninstall regex -y 1>> %logfile% 2>> %errorfile%
python -m pip uninstall pyodbc -y 1>> %logfile% 2>> %errorfile%
IF EXIST "%scriptpath%\Templates\wsl_bigquery_create_table.peb" (
python -m pip uninstall google-cloud -y 1>> %logfile% 2>> %errorfile%
python -m pip uninstall google-cloud-bigquery -y 1>> %logfile% 2>> %errorfile%
)
If exist "%scriptpath%\Scripts\Browse_File_Parser.py" (
python -m pip uninstall avro avro_python3 fastavro jsonpath_ng lxml openpyxl pandas pandas_stubs Pillow protobuf pyarrow pyorc pywin32 xmltodict -y 1>> %logfile% 2>> %errorfile%
)
set /p awsPackages=Do you want to uninstall python packages for Amazon S3 [y/n]?:
If /I "%awsPackages%"=="y" goto yes
goto no
:yes
python -m  pip uninstall boto3 -y 1>> %logfile% 2>> %errorfile%
:no
set /p azPackages=Do you want to uninstall python packages for Azure Datalake Storage Gen2   [y/n]?: 
If /I "%azPackages%"=="y" goto yes
goto no
:yes
python -m  pip uninstall azure-storage -y 1>> %logfile% 2>> %errorfile%
python -m  pip uninstall azure-storage-file-datalake -y 1>> %logfile% 2>> %errorfile%
:no
set /p gcPackages=Do you want to uninstall python packages for Google Cloud   [y/n]?: 
If /I "%gcPackages%"=="y" goto yes
goto no
:yes
python -m  pip uninstall gcloud -y 1>> %logfile% 2>> %errorfile%
python -m  pip uninstall google_api_python_client google_auth_oauthlib google-cloud-core google-cloud-datastore google-cloud-storage -y 1>> %logfile% 2>> %errorfile%
:no

:end
for /f %%i in ("%errorfile%") do if %%~zi gtr 0 SET ERRORLEVEL=1
IF %ERRORLEVEL% NEQ 0 (
  ECHO ---
  ECHO Printing error file %errorfile%:
  ECHO ---
  TYPE %errorfile%
  ECHO ---
  ECHO Error file can be found here: %errorfile%
  ECHO Log file can be found here  : %logfile%
  ECHO ---
  ECHO UNINSTALL COMPLETED! 
  ECHO There were one or more failures or warning during the uninstall, the error log will be opened on exit. Additional information may be found in the log file. 
  ECHO ---
  PAUSE
  START notepad %errorfile% 
) ELSE (
  ECHO Uninstall Successful. The uninstall log file is located here: %logfile%
  PAUSE
)
EXIT /B %ERRORLEVEL%