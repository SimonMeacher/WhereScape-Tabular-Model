# --    (c) WhereScape Inc 2020. WhereScape Inc permits you to copy this Script solely for use with the RED software, and to modify this Script         
# --    for the purposes of using that modified Script with the RED software, but does not permit copying or modification for any other purpose.         
#==============================================================================================================================
# Source Enablement Pack Name        :    File Parser
# Scripting Language                 :    Python
# Script Name                        :    Browse_File_Parser.py
# Script Version                     :    1.0
# Description                        :    This script supports file profiling sourced from Windows,Clouds(Amazon S3,Azure Data Lake Storage Gen2,Google Cloud)
#                                         Parses the files for data profiling i.e to analyse the column names and datatypes.
#                                         Displays list of files with column names,column size and datatype in target pane
# Author                             :    WhereScape Inc
#======================================================================================================
# Notes / History
# 1.0.0   2022-02-16   First Version
#======================================================================================================

import warnings
import win32console
import win32gui
warnings.filterwarnings("ignore")
import os,sys,json
import time
import json
import re
import datetime 
import pandas as pd
sys.path.append(os.environ.get('WSL_WORKDIR',''))

# Hide the console window on Windows
def HideWindow():
    hwnd=int(win32console.GetConsoleWindow())
    win32gui.ShowWindow(hwnd,0) 
    return True 

HideWindow()
try:
    # Parser Script Imports For Wherescape RED
    commonModuleWithPath = "$WSL_SCRIPT_WslParserCommonModule_CODE$"
    commonModuleName = commonModuleWithPath.split("\\")[-1][:-3]
    WslParserCommonModule= __import__(commonModuleName)

    guiJSONModule = "$WSL_SCRIPT_WslJsonParserGUI_CODE$"
    guiJSONModule = guiJSONModule.split("\\")[-1][:-3]
    WslJsonParserGUI = __import__(guiJSONModule)

    fileSelectionGUI = "$WSL_SCRIPT_WslParserFileSelectionGUI_CODE$"
    fileSelectionGUI = fileSelectionGUI.split("\\")[-1][:-3]
    WslParserFileSelectionGUI = __import__(fileSelectionGUI)

    WslCloudFileBrowser = "$WSL_SCRIPT_WslCloudFileBrowser_CODE$"
    WslCloudFileBrowser = WslCloudFileBrowser.split("\\")[-1][:-3]
    WslCloudFileBrowser = __import__(WslCloudFileBrowser)

    # Create Error Log File
    errorLog=str(os.environ.get('WSL_TASK_NAME',''))+"_"+str(os.environ.get('WSL_SEQUENCE',''))+".err"

except Exception:
    # Parser Script Imports For Wherescape 3D
    sys.path.append('C:/ProgramData/WhereScape/Modules/WslPython')
    WslJsonParserGUI= __import__('WslJsonParserGUI')
    WslParserFileSelectionGUI= __import__('WslParserFileSelectionGUI')
    WslCloudFileBrowser= __import__('WslCloudFileBrowser')
    WslParserCommonModule= __import__('WslParserCommonModule')

    # Create Error Log File with todays date
    current_time = datetime.datetime.now() 
    today = current_time.strftime("%d_%m_%Y")
    errorLog = f"ErrorLog_{today}.err"

errorStream = open(os.path.join(os.environ.get('WSL_WORKDIR',''), errorLog), 'w+')

# JSON HEADER
# All profiled data is appended to this header, and is printed at the end of the script, is refered as 'BROWSE JSON' in all the scripts.
jsonHead = {
  "localFolderPath": {},
  "treeViewIcons": {
    "schema": "project.ico",
    "table": "File.ico"
  },
  "treeViewLayout": "Tabular",
  
}

def createParserObject(selectedParaObject):
    '''
    Central function to add parameters to the file object. Each file selected for parsing will get tagged with this meta data during execution.

    Parameters
    ----------
    selectedParaObject : dict
        Dictionary containing the parameters to be added to the file. This is the output of the 'File Selection GUI' and 'Cloud File Browser GUI'.
    
    Returns
    -------
    parserObject : dict
        Dictionary containing the parameters to be added to the file. Output parameters of this function are usable throughout the parser project.
    '''

    fileParserObject = {}

   # Parser
    if selectedParaObject['parser'].strip() == 'DELIMITED':
        fileParserObject['parser'] = 'delimited'
    elif selectedParaObject['parser'].strip() == 'XLSX':
        fileParserObject['parser'] = 'xlsx'
    elif selectedParaObject['parser'].strip() == 'PARQUET':
        fileParserObject['parser'] = 'parquet'
    elif selectedParaObject['parser'].strip() == 'XML':
        fileParserObject['parser'] = 'xml'
    elif selectedParaObject['parser'].strip() == 'JSON':
        fileParserObject['parser'] = 'json'
    elif selectedParaObject['parser'].strip() == 'AVRO':
        fileParserObject['parser'] = 'avro'
    elif selectedParaObject['parser'].strip() == 'ORC':
        fileParserObject['parser'] = 'orc'

    if selectedParaObject['parser'].strip() == 'DELIMITED':

        # Record Delimiter
        if selectedParaObject['recordDelimiter'] == '\\n' or selectedParaObject['recordDelimiter'] == r'\n':
            fileParserObject['recordDelimiter'] = r'\n'
        else:
            fileParserObject['recordDelimiter'] = selectedParaObject['recordDelimiter']

        # fieldDelimiter
        fileParserObject['fieldDelimiter'] = selectedParaObject['fieldDelimiter']

        # fieldEnclosure
        fileParserObject['fieldEnclosure'] = selectedParaObject['enclosedBy']

        # rowLimit
        fileParserObject['rowLimit'] = int(selectedParaObject['rowLimit'])

        # skipLine
        fileParserObject['skipLine'] = int(selectedParaObject['skipLine'])

        # header
        if int(selectedParaObject['checkBoxHeader']) == 1:
            fileParserObject['header'] = True
            fileParserObject['headerLine'] = selectedParaObject['headerLine']
        else:
            fileParserObject['header'] = False
            fileParserObject['headerLine'] = selectedParaObject['headerLine']

    elif selectedParaObject['parser'].strip() == 'XLSX':
        # header
        if int(selectedParaObject['checkBoxHeader']) == 1:
            fileParserObject['headerLine'] = selectedParaObject['headerLine']
            fileParserObject['header'] = True
        else:
            fileParserObject['headerLine'] = None
            fileParserObject['header'] = False

        if selectedParaObject['SheetName'] == "DEF_0":
            xl = pd.ExcelFile(selectedParaObject['fileName'])
            excelSheets=xl.sheet_names
            fileParserObject['SheetName'] = excelSheets[0]
        else:
            fileParserObject['SheetName'] = selectedParaObject['SheetName']
            
        fileParserObject['recordDelimiter'] = ''
        fileParserObject['fieldDelimiter'] = ''
        fileParserObject['fieldEnclosure'] = ''
        fileParserObject['rowLimit'] = int(selectedParaObject['rowLimit'])
        fileParserObject['skipLine'] = 0

    elif selectedParaObject['parser'].strip() in ['PARQUET','ORC']:
        fileParserObject['profilingFactor'] = float(selectedParaObject['Profiling factor'])
        fileParserObject['recordDelimiter'] = ''
        fileParserObject['header'] = True
        fileParserObject['fieldDelimiter'] = ''
        fileParserObject['fieldEnclosure'] = ''
        fileParserObject['rowLimit'] = 1000
        fileParserObject['skipLine'] = 0
        fileParserObject['headerLine'] = 0

    elif selectedParaObject['parser'].strip() == 'JSON':
        fileParserObject['recordDelimiter'] = ''
        fileParserObject['header'] = True
        fileParserObject['fieldDelimiter'] = ''
        fileParserObject['fieldEnclosure'] = ''
        fileParserObject['rowLimit'] = 1000
        fileParserObject['skipLine'] = 0
        fileParserObject['headerLine'] = 0
        fileParserObject['depth'] = int(selectedParaObject['Depth'])

    elif selectedParaObject['parser'].strip() == 'XML':
        fileParserObject['recordDelimiter'] = ''
        fileParserObject['header'] = True
        fileParserObject['fieldDelimiter'] = ''
        fileParserObject['fieldEnclosure'] = ''
        fileParserObject['rowLimit'] = 1000
        fileParserObject['skipLine'] = 0
        fileParserObject['headerLine'] = 0
        fileParserObject['depth'] = int(selectedParaObject['Depth'])

    else:
        fileParserObject['recordDelimiter'] = ''
        fileParserObject['header'] = True
        fileParserObject['fieldDelimiter'] = ''
        fileParserObject['fieldEnclosure'] = ''
        fileParserObject['rowLimit'] = 1000
        fileParserObject['skipLine'] = 0
        fileParserObject['headerLine'] = 0
        fileParserObject['SheetName'] = ''
        fileParserObject['profilingFactor'] = 1

    # fileName
    fileParserObject['fileName'] = str(selectedParaObject['fileName'].split('/')[-1])

    # Local Path Variable: This is the path shown at the top of the file browser in RED. 
    # For Windows: directory path.
    # For GCS and S3: bucket name.
    # For Azure Blob: file system name.

    global localPath
    if selectedParaObject['connectionType'] == 'local':
        localPath = str(('/'.join(selectedParaObject['fileName'].split('/')[0:-1]).replace('/', '\\')))
    else:
        localPath = selectedParaObject['connectionLocation']

    # Cloud Details
    fileParserObject['connectionType'] = selectedParaObject['connectionType']
    fileParserObject['connectionString'] = selectedParaObject['connectionString']
    fileParserObject['cloudFilePath'] = selectedParaObject['cloudFilePath']
    
    # Encoding Type
    fileParserObject['encodingType'] = selectedParaObject['encoding']

    # filePath
    fileParserObject['filePath'] = str(selectedParaObject['fileName'].replace('/', '\\'))
    
    return fileParserObject


def getColumnNameListForJSON(dataFromJSONViewer):
    '''
    This function is used to get the column names which are edited in the JSON Viewer.

    Parameters
    ----------
    dataFromJSONViewer : dict

    Returns
    -------
    columnNameList : list
    '''

    columnNameListForJSON = []
    for i in dataFromJSONViewer:
        for k,v in i.items():
            if v["ChangedNames"] == []:
                columnNameListForJSON.append({k:v["Columns"], 'Trim':v["Trim"]})
            else:
                for j in v["ChangedNames"]:
                    if j["NewName"] in v["Columns"]:
                        v["Columns"].remove(j["NewName"])
                        v["Columns"].append(j["OldName"])
                    
                columnNameListForJSON.append({k:v["Columns"], "Trim":v["Trim"]})
    return columnNameListForJSON

def getColumnNameListForXML(dataFromXMLViewer):
    '''
    This function is used to get the column names which are edited in the XML Viewer.

    Parameters
    ----------
    dataFromXMLViewer : dict

    Returns
    -------
    columnNameList : list
    '''

    columnNameListForXML = []
    for i in dataFromXMLViewer:
        for k,v in i.items():
            if v["ChangedNames"] == []:
                columnNameListForXML.append({k:v["Columns"], 'Trim':v["Trim"]})
            else:
                for j in v["ChangedNames"]:
                    if j["NewName"] in v["Columns"]:
                        v["Columns"].remove(j["NewName"])
                        v["Columns"].append(j["OldName"])
                    
                columnNameListForXML.append({k:v["Columns"], "Trim":v["Trim"]})
    return columnNameListForXML
    
# Used to remove '[]' from xml column names
def removeBracketsForXML(string):
    regex = r"\[(.*?)\]"
    subst = "[]"
    result = re.sub(regex, subst, string, 0, re.MULTILINE)
    return result

# Common function to get any key from list
def findKeyInList(key,list):
    keyList = []
    for i in list:
        for k,v in i.items():
            if k == key:
                keyList.append(v)
    return keyList

# Main Entry Point Function for the File Parser
def profileDataFiles():

    connectionDetails = {
        "connectionType": "",
        "cloudFilePath": "",
    }
    
    # Import atleast one ui property from each cloud ui to check the connection type
    redIcon = WslParserCommonModule.getRedIcon()

    # For Amazon S3
    if "WSL_SRCCFG_s3AccessKey" not in "$WSL_SRCCFG_s3AccessKey$".strip():
        aws_access_key = "$WSL_SRCCFG_s3AccessKey$".strip()
        aws_secret_access_key = os.environ.get('WSL_SRCCFG_s3SecretKey').strip()
        region_name = "$WSL_SRCCFG_s3Region$".strip()
        s3_bucket_name = "$WSL_SRCCFG_s3Bucket$".strip()

        # Import File Browser
        S3Browser = WslCloudFileBrowser.FileBrowserUI(redIcon)
        WslParserCommonModule.center(S3Browser.root)
        S3Browser.s3Connection(aws_access_key, aws_secret_access_key, region_name, s3_bucket_name)
        S3Browser.createFileBrowser()
        S3Browser.loadFilesIntoBrowser()
        S3Browser.root.mainloop()

        # Get the downloaded file path
        downloadedFiles = S3Browser.downloadLocation

        # Get local file path from the downloadedFiles list object
        localDownloadedPath = findKeyInList("localPath",downloadedFiles)
        cloudFilePath = findKeyInList("cloudPath",downloadedFiles)

        connectionDetails["connectionType"] = "S3"
        connectionDetails["cloudFilePath"] = cloudFilePath

    # For Azure Data Lake
    elif "WSL_SRCCFG_azureStorageAccountName" not in "$WSL_SRCCFG_azureStorageAccountName$".strip():
        azure_account_name= "$WSL_SRCCFG_azureStorageAccountName$".strip()
        azure_account_key = os.environ.get("WSL_SRCCFG_azureStorageAccountAccessKey").strip()
        azure_file_system = "$WSL_SRCCFG_azureStorageFileSystem$".strip()

        # Import File Browser
        AzureBrowser = WslCloudFileBrowser.FileBrowserUI(redIcon)
        WslParserCommonModule.center(AzureBrowser.root)
        AzureBrowser.azureConnection(azure_account_name, azure_account_key, azure_file_system)
        AzureBrowser.createFileBrowser()
        AzureBrowser.loadFilesIntoBrowser()
        AzureBrowser.root.mainloop()

        # Get the downloaded file path
        downloadedFiles = AzureBrowser.downloadLocation

        # Get local file path from the downloadedFiles list object
        localDownloadedPath = findKeyInList("localPath",downloadedFiles)
        cloudFilePath = findKeyInList("cloudPath",downloadedFiles)

        connectionDetails["connectionType"] = "AZ"
        connectionDetails["cloudFilePath"] = cloudFilePath

    # For Google Cloud Storage
    elif "WSL_SRCCFG_gsBucket" not in "$WSL_SRCCFG_gsBucket$".strip():
        gcs_project = "$WSL_SRCCFG_gsProject$".strip()
        gcs_bucket_name = "$WSL_SRCCFG_gsBucket$".strip()

        # Import File Browser
        GCSBrowser = WslCloudFileBrowser.FileBrowserUI(redIcon)
        WslParserCommonModule.center(GCSBrowser.root)
        GCSBrowser.gcpConnection(gcs_project, gcs_bucket_name)
        GCSBrowser.createFileBrowser()
        GCSBrowser.loadFilesIntoBrowser()
        GCSBrowser.root.mainloop()

        # Get the downloaded file path
        downloadedFiles = GCSBrowser.downloadLocation

        # Get local file path from the downloadedFiles list object
        localDownloadedPath = findKeyInList("localPath",downloadedFiles)
        cloudFilePath = findKeyInList("cloudPath",downloadedFiles)

        connectionDetails["connectionType"] = "GCS"
        connectionDetails["cloudFilePath"] = cloudFilePath

    else:
        downloadedFiles = None
        localDownloadedPath = None
        cloudFilePath = ''
        connectionDetails["connectionType"] = "local"
        connectionDetails["cloudFilePath"] = ''
    try:
        # Run File Selection GUI for the downloaded files
        selectedFiles = WslParserFileSelectionGUI.getSelectedFiles(redIcon, localDownloadedPath)
        if selectedFiles == []:
            return    
        # Add cloud details at this section b4 sending it to createParserObject function
        for g in range(len(selectedFiles)):
            # Filter cloud path
            if connectionDetails['connectionType'] != "local":
                cloudPath = connectionDetails['cloudFilePath'][g]
                if "/" in cloudPath:
                    cloudPath = cloudPath.split("/")
                    cloudPath.pop()
                    cloudPath = "/".join(cloudPath)
                    if cloudPath[-1] == "/":
                        cloudPath = cloudPath[:-1]
                else:
                    cloudPath = ""
            else:
                cloudPath = 'local'
            # Create Connection String for Source Directory
            if connectionDetails['connectionType'] == "S3":
                connectionDetails['connectionString'] = f"s3://{s3_bucket_name}/{cloudPath}"
                connectionDetails['connectionLocation'] = s3_bucket_name

            elif connectionDetails['connectionType'] == "AZ":
                connectionDetails['connectionString'] = f"https://{azure_account_name}.dfs.core.windows.net/{azure_file_system}/{cloudPath}"
                connectionDetails['connectionLocation'] = azure_file_system

            elif connectionDetails['connectionType'] == "GCS":
                connectionDetails['connectionString'] = f"gs://{gcs_bucket_name}/{cloudPath}"
                connectionDetails['connectionLocation'] = gcs_bucket_name

            else:
                connectionDetails['connectionString'] = "local"
                connectionDetails['connectionLocation'] = ''

            selectedFiles[g]['cloudFilePath'] = cloudPath
            selectedFiles[g]['connectionType'] = connectionDetails['connectionType']
            selectedFiles[g]['connectionString'] = connectionDetails['connectionString']
            selectedFiles[g]['connectionLocation'] = connectionDetails['connectionLocation']

    except Exception as e:
        errorStream.write(f"Error in getting selected files: {str(e)}")
        pass

    fileMetaDataObjectList = []
    try:
        for sFile in selectedFiles:
            fileMetaDataObject = createParserObject(sFile)
            fileMetaDataObjectList.append(fileMetaDataObject)
            
    except Exception as err:
        errorStream.write(str(f"Error in creating parser object for: {str(err)}"))
        if fileMetaDataObjectList != []:
            pass
        else:
            return 
    
    jsonHead[localPath] = jsonHead.pop('localFolderPath')

    # Get file path of each selected file
    # fileMetaDataObjectList: It contains all the file metadata objects created using 'createParserObject' function.
    for fileMeta in fileMetaDataObjectList:
        try:
            # READ DATA FOR: DELIMITED, XLSX AND PARQUET
            if fileMeta['parser'].lower() in ['delimited', 'xlsx', 'parquet']:

                # Check if file is not empty
                if fileMeta['parser'].lower() in ['delimited', 'parquet']:
                    fileSize = os.path.getsize(fileMeta['filePath'])
                elif fileMeta['parser'].lower() == 'xlsx':
                    df = pd.read_excel(fileMeta['filePath'], sheet_name=fileMeta['SheetName'])
                    fileSize = df.memory_usage(deep=True).sum()

                # If file is empty, create single record object
                if fileSize == 0:
                    errorStream.write(f"Cannot profile {fileMeta['filePath']} is empty.\n")
                    singleColumnJSON = WslParserCommonModule.singleColumnJSON(fileMeta)
                    WslParserCommonModule.createJsonBody(fileMeta, singleColumnJSON, 777, jsonHead, localPath)
                    continue
                else:
                    data = WslParserCommonModule.getLimitedData(fileMeta,errorStream)

            # READ DATA FOR: ORC
            elif fileMeta['parser'].lower() in 'orc':

                # Check if file is not empty
                fileSize = os.path.getsize(fileMeta['filePath'])
                if fileSize == 0:
                    errorStream.write(f"Cannot profile {fileMeta['filePath']} is empty.\n")
                    singleColumnJSON = WslParserCommonModule.singleColumnJSON(fileMeta)
                    WslParserCommonModule.createJsonBody(fileMeta, singleColumnJSON, 777, jsonHead, localPath)
                    continue
                else:
                    data = WslParserCommonModule.getOrcData(fileMeta, 'rb')
            
            # READ DATA FOR: AVRO
            elif fileMeta['parser'].lower() in 'avro':

                # Check if file is not empty
                fileSize = os.path.getsize(fileMeta['filePath'])
                if fileSize == 0:
                    errorStream.write(f"Cannot profile {fileMeta['filePath']} is empty.\n")
                    singleColumnJSON = WslParserCommonModule.singleColumnJSON(fileMeta)
                    WslParserCommonModule.createJsonBody(fileMeta, singleColumnJSON, 777, jsonHead, localPath)
                    continue
                else:
                    data = WslParserCommonModule.getAvroData(fileMeta, 'rb')
            
            # READ DATA FOR: XML
            elif fileMeta['parser'].lower() in 'xml':
                if os.stat(fileMeta['filePath']).st_size == 0:
                    singleColumnJSON = WslParserCommonModule.singleColumnJSON(fileMeta)
                    WslParserCommonModule.createJsonBody(fileMeta, singleColumnJSON, 777, jsonHead, localPath)
                    errorStream.write(f"Cannot profile {fileMeta['filePath']} is empty.\n")
                    continue
                
                # Run XML Parser Viewer
                xmlDataFromGUI = WslJsonParserGUI.jsonView(
                    fileMeta['filePath'], fileMeta['depth'], fileMeta['parser'].upper(), redIcon, fileMeta['encodingType'])
                entityList = getColumnNameListForXML(xmlDataFromGUI)
                rowCount = 100

                # entityList: It contains metadata received from the XML Parser Viewer GUI related to entities.
                for index, entity in enumerate(entityList):

                    data = 'XML'
                    if str(list(entity.keys())[0]) == fileMeta['fileName']:
                        allJsonKeys = WslParserCommonModule.getAllJSONKeys(
                            fileMeta['filePath'], 'XML', fileMeta['encodingType'])
                        entityName = str(list(entity.keys())[0])
                        columnNameList = allJsonKeys
                        columnNameList = [removeBracketsForXML(
                            x) for x in columnNameList]

                        # Remove duplicates from columnNameList
                        columnNameList = list(set(columnNameList[:]))
                    else:
                        entityName = str(list(entity.keys())[0])
                        columnNameList = entity[entityName]

                    # list of json columns for 'BROWSE JSON' are created
                    columnListJSON = WslParserCommonModule.createColumnForEntity(
                        '', columnNameList, entityName, xmlDataFromGUI, fileMeta, entity['Trim'], errorStream)

                    # If columnListJSON is empty, then to showcase error, create a single column JSON
                    if columnListJSON == None:
                        singleColumnJSON = WslParserCommonModule.singleColumnJSON(
                            fileMeta)
                        WslParserCommonModule.createJsonBody(
                            fileMeta, singleColumnJSON, 777, jsonHead, localPath)
                        continue

                    # ColumnListJson is attached to main "Browse JSON" and appended to JSON HEAD
                    WslParserCommonModule.createJsonBodyForSubJSONEntity(
                        fileMeta, columnListJSON, rowCount, jsonHead, localPath, str(list(entity.keys())[0]))

            # READ DATA FOR: JSON
            elif fileMeta['parser'].lower() in 'json':
                if os.stat(fileMeta['filePath']).st_size == 0:
                    singleColumnJSON = WslParserCommonModule.singleColumnJSON(fileMeta)
                    WslParserCommonModule.createJsonBody(fileMeta, singleColumnJSON, 777, jsonHead, localPath)
                    errorStream.write(f"Cannot profile {fileMeta['filePath']} is empty.\n")
                    continue
                
                # Run JSON Parser Viewer
                jsonDataFromGUI = WslJsonParserGUI.jsonView(fileMeta['filePath'], fileMeta['depth'], fileMeta['parser'].upper(), redIcon, fileMeta['encodingType'])
                entityList = getColumnNameListForJSON(jsonDataFromGUI)
                rowCount = 100
                jsonData = json.load(open(fileMeta['filePath'], encoding=fileMeta['encodingType']))

                # entityList: It contains metadata received from the JSON Parser Viewer GUI related to entities.
                for index, entity in enumerate(entityList):

                    # data = JSON, is added to skip the single column file creation of main json file, if its required to create single column file then pass data = 'SINGLE_RECORD'
                    data = 'JSON'
                    if str(list(entity.keys())[0]) == fileMeta['fileName']:
                        allJsonKeys = WslParserCommonModule.getAllJSONKeys(
                            fileMeta['filePath'], 'JSON', fileMeta['encodingType'])
                        entityName = str(list(entity.keys())[0])
                        columnNameList = allJsonKeys
                    else:
                        entityName = str(list(entity.keys())[0])
                        columnNameList = entity[entityName]

                    columnNameList = [WslParserCommonModule.filterColumnName(i) for i in columnNameList]
                    columnNameList = list(set(columnNameList))

                    # list of json columns for 'BROWSE JSON' are created
                    columnListJSON = WslParserCommonModule.createColumnForEntity(
                        jsonData, columnNameList, entityName, jsonDataFromGUI, fileMeta, entity['Trim'], errorStream)

                    # If columnListJSON is empty, then to showcase error, create a single column JSON
                    if columnListJSON == None:
                        singleColumnJSON = WslParserCommonModule.singleColumnJSON(fileMeta)
                        WslParserCommonModule.createJsonBody(fileMeta, singleColumnJSON, 777, jsonHead, localPath)
                        continue
                    
                    # ColumnListJson is attached to main "Browse JSON" and appended to JSON HEAD
                    WslParserCommonModule.createJsonBodyForSubJSONEntity(fileMeta, columnListJSON, rowCount, jsonHead, localPath, str(list(entity.keys())[0]))
            else:
                print(-2)
                errorStream.write("Invalid file parser selected")
                print("Invalid file parser selected")

            # If parsing is not successful for CSV because of delimiter error or any other error, then 'SINGLE_RECORD' flag is raised which will create a single column json
            if type(data) == str:
                if data == "SINGLE_RECORD":
                    singleColumnJSON = WslParserCommonModule.singleColumnJSON(fileMeta)
                    WslParserCommonModule.createJsonBody(fileMeta, singleColumnJSON, 777, jsonHead, localPath)

                    errorStream.write(f"Error in parsing file {fileMeta['filePath']}: File either empty or incorrect parameters passed.\n")

                    if fileMeta['connectionType'] != "local":
                        os.remove(fileMeta['filePath'])
                elif data == 'JSON':
                    continue
                elif data == 'XML':
                    continue
            else:
                # Get Row Count
                if fileMeta['parser'].lower() in 'json':
                    rowCount = len(data.index)
                if fileMeta['parser'].lower() in 'orc':
                    rowCount = len(data)  
                else:
                    rowCount = fileMeta['rowLimit']
                
                # Create Final BROWSE JSON. Except for XML and JSON.
                allColumnList = data.columns.values.tolist()
                allColumnListJSON = WslParserCommonModule.getColumnJSON(data[allColumnList], fileMeta, None,None)
                WslParserCommonModule.createJsonBody(fileMeta, allColumnListJSON, rowCount, jsonHead, localPath)

                # If connection type is cloud, then temp file is deleted.
                if fileMeta['connectionType'] != "local":
                    for attempt in range(5):
                        try:
                            os.remove(fileMeta['filePath'])
                            break
                        except PermissionError:
                            time.sleep(1)

        # For any error in parsing, create a single column json and write the error in errorStream
        except Exception as e:
            singleColumnJSON = WslParserCommonModule.singleColumnJSON(fileMeta)
            WslParserCommonModule.createJsonBody(fileMeta, singleColumnJSON, 777, jsonHead, localPath)
            if fileMeta['connectionType'] != "local":
                os.remove(fileMeta['filePath'])
                errorStream.write(f"Error in parsing file '{os.path.join(fileMeta['cloudFilePath'], fileMeta['fileName'])}': {str(e)}\n")
            else:
                errorStream.write(f"Error in parsing file {fileMeta['filePath']}: {str(e)}\n")

try:
    profileDataFiles()
except Exception as e:
    errorStream.write(str(e))

# Write JSON to WSL_WORKDIR
with open(os.path.join(os.environ.get('WSL_WORKDIR',''),'Wsl_Browse.json'),'w',encoding='utf-8') as f:
    json.dump(jsonHead, f, ensure_ascii=False, indent=4)

errorStream.close()
print(1)
print(json.dumps(jsonHead))