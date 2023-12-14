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
ECHO Begining install of WhereScape Python Modules and required Python Libs... 1> %logfile% 2> %errorfile%
ECHO Installing WhereScape Python Modules and required Python Libs, please Wait..
REM Copy Python Modules
ECHO Copying Python Modules... 1>> %logfile% 2>> %errorfile%
IF NOT EXIST "C:\ProgramData\WhereScape\Modules\" MKDIR "C:\ProgramData\WhereScape\Modules\"
IF NOT EXIST "C:\ProgramData\WhereScape\Modules\WslPython\" MKDIR "C:\ProgramData\WhereScape\Modules\WslPython\"
COPY /Y "%scriptpath%Python Modules\WslPython\" C:\ProgramData\WhereScape\Modules\WslPython\ 1>> %logfile% 2>> %errorfile%
IF EXIST "%scriptpath%Scripts\" ( COPY /Y "%scriptpath%Scripts\Wsl*" C:\ProgramData\WhereScape\Modules\WslPython\ 1>> %logfile% 2>> %errorfile% ) ELSE ( COPY /Y "%scriptpath%Source Enablement Pack\Scripts\Wsl*" C:\ProgramData\WhereScape\Modules\WslPython\ 1>> %logfile% 2>> %errorfile% )
IF %ERRORLEVEL% NEQ 0 ( ECHO Failed to copy or update Python modlues to C:\ProgramData\WhereScape\Modules\WslPython\ >> %logfile% & GOTO end )
ECHO Sucessfully copied Python modules to C:\ProgramData\WhereScape\Modules\WslPython\ >> %logfile%
REM Check for Python and PIP
echo %PATH% |find "Python" > nul 2>&1 && ( GOTO continue_libs_install ) || ( GOTO no_python )
pip --version >nul 2>&1 && ( GOTO continue_libs_install ) || ( GOTO no_pip )
:no_python
ECHO -- >> %logfile%
ECHO ERROR: Python is required, it must be both installed and in the system PATH >> %errorfile%
goto end
:no_pip
ECHO -- >> %logfile%
ECHO ERROR: PIP is required, download https://bootstrap.pypa.io/get-pip.py and run: python get-pip.py >> %errorfile%
goto end
:continue_libs_install
ECHO -- >> %logfile%
ECHO Installing Python Libraries >> %logfile%
python --version 1>> %logfile% 2>> %errorfile%
python -m pip install --upgrade pip 1>> %logfile% 2>> %errorfile%
REM Install/upgrade required libraries using Pip
python -m pip install --upgrade pip 1>> %logfile% 2>> %errorfile%
python -m pip install pywin32-ctypes 1>> %logfile% 2>> %errorfile%
python -m pip install python-tds 1>> %logfile% 2>> %errorfile%
python -m pip install pywin32 1>> %logfile% 2>> %errorfile%
python -m pip install glob2 1>> %logfile% 2>> %errorfile%
python -m pip install gzip-reader 1>> %logfile% 2>> %errorfile%
python -m pip install regex 1>> %logfile% 2>> %errorfile%
python -m pip install pyodbc 1>> %logfile% 2>> %errorfile%
IF EXIST "%scriptpath%\Templates\wsl_bigquery_create_table.peb" (
python -m pip install google-cloud 1>> %logfile% 2>> %errorfile%
python -m pip install google-cloud-bigquery 1>> %logfile% 2>> %errorfile%
)
If exist "%scriptpath%\Scripts\Browse_File_Parser.py" (
python -m pip install avro avro_python3 fastavro jsonpath_ng lxml openpyxl pandas pandas_stubs Pillow protobuf pyarrow pyorc pywin32 xmltodict 1>> %logfile% 2>> %errorfile%
)
set /p awsPackages=Do you want to install python packages for Amazon S3 [y/n]?:
If /I "%awsPackages%"=="y" goto yes
goto no
:yes
python -m  pip install boto3==1.20.35 1>> %logfile% 2>> %errorfile%
:no
set /p azPackages=Do you want to install python packages for Azure Datalake Storage Gen2   [y/n]?: 
If /I "%azPackages%"=="y" goto yes
goto no
:yes
python -m  pip install azure-storage-file-datalake 1>> %logfile% 2>> %errorfile%
:no
set /p gcPackages=Do you want to install python packages for Google Cloud   [y/n]?: 
If /I "%gcPackages%"=="y" goto yes
goto no
:yes
python -m  pip install --upgrade gcloud 1>> %logfile% 2>> %errorfile%
python -m  pip install google_api_python_client==2.51.0 google_auth_oauthlib==0.4.2 google-cloud-core==2.3.1 google-cloud-datastore==2.7.1 google-cloud-storage==2.4.0 1>> %logfile% 2>> %errorfile%
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
  ECHO INSTALL FAILED! 
  ECHO There were one or more failures during the install, the error log will be opened on exit. Additional information may be found in the log file. 
  ECHO ---
  PAUSE
  START notepad %errorfile% 
) ELSE (
  ECHO Install Successful. The install log file is located here: %logfile%
  PAUSE
)
EXIT /B %ERRORLEVEL%