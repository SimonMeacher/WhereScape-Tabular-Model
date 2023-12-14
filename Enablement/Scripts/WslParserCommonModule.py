# --    (c) WhereScape Inc 2020. WhereScape Inc permits you to copy this module solely for use with the RED software, and to modify this module            -- #
# --    for the purposes of using that modified module with the RED software, but does not permit copying or modification for any other purpose.           -- #
# --                                                                                                                                                       -- #
#=====================================================================================================
# Module Name      :    WslParserCommonModule
# DBMS Name        :    Generic for all databases
# Description      :    Generic python functions module used by Browse_File_Parser.py
#                       The Module contains functions to parse and profile file types (delimited,avro,parquet,orc,json,xml)
# Author           :    Wherescape Inc
#======================================================================================================
# Notes / History
# 1.0.0   2022-02-16   First Version
#======================================================================================================

import xmltodict
from collections.abc import MutableMapping
from jsonpath_ng import parse
from lxml import etree
import warnings
warnings.filterwarnings("ignore")
import sys, os
import pandas as pd
import fastavro
import tkinter as tk
import tkinter.font as tkFont
import tkinter.ttk as ttk
from copy import deepcopy
import datetime
import json
import pyorc
import re
import csv
import pyarrow.parquet as pq
from avro.datafile import DataFileReader
from avro.io import DatumReader
import copy
import time

def getAvroData(parameterObject, readType):
    '''
    Read avro file and return pandas dataframe

    Parameters
    ----------
    parameterObject : dict
        Dictionary of parameters. Meta data created from function 'createParserObject' from Browse_File_Parser.py
    readType : str
        Method to read avro file.
    
    Returns
    -------
    df : pandas.DataFrame
    
    '''
    
    with open(parameterObject['filePath'], readType) as fp:
        reader = fastavro.reader(fp)
        records = [r for r in reader]
        df = pd.DataFrame.from_records(records)
        return df


def is_date(string):
    '''
    Check if string is date.

    Parameters
    ----------
    string : str
        String to be checked.
    
    Returns
    -------
    True : bool
        If string is date.
    False : bool
        If string is not date.
    '''
    dateFormats = ['%Y-%m-%d', '%Y/%m/%d', '%Y.%m.%d', '%d-%m-%Y', '%d/%m/%Y', '%d.%m.%Y', '%m-%d-%Y', '%m/%d/%Y', '%m.%d.%Y']
    for dateFormat in dateFormats:
        try:
            datetime.datetime.strptime(string, dateFormat)
            return True
        except ValueError:
            continue
    
    return False


def is_datetime(string):
    '''
    Check if string is datetime.

    Parameters
    ----------
    string : str
        String to be checked.
    
    Returns
    -------
    True : bool
        If string is datetime.
    False : bool
        If string is not datetime.
    '''
    dateTimeFormats = ['%Y-%m-%d %H:%M:%S', '%Y/%m/%d %H:%M:%S', '%Y.%m.%d %H:%M:%S', '%d-%m-%Y %H:%M:%S', '%d/%m/%Y %H:%M:%S', '%d.%m.%Y %H:%M:%S', '%m-%d-%Y %H:%M:%S', '%m/%d/%Y %H:%M:%S', '%m.%d.%Y %H:%M:%S']
    
    for dateTimeFormat in dateTimeFormats:
        try:
            datetime.datetime.strptime(string, dateTimeFormat)
            return True
        except ValueError:
            continue
    
    return False


def is_timestamp(string):
    '''
    Check if string is timestamp.

    Parameters
    ----------
    string : str
        String to be checked.
    
    Returns
    -------
    True : bool
        If string is timestamp.
    False : bool
        If string is not timestamp.
    '''
    timeStampFormats = ['%Y-%m-%d %H:%M:%S.%f', '%Y/%m/%d %H:%M:%S.%f', '%Y.%m.%d %H:%M:%S.%f', '%d-%m-%Y %H:%M:%S.%f', '%d/%m/%Y %H:%M:%S.%f', '%d.%m.%Y %H:%M:%S.%f', '%m-%d-%Y %H:%M:%S.%f', '%m/%d/%Y %H:%M:%S.%f', '%m.%d.%Y %H:%M:%S.%f']
    
    for timeStampFormat in timeStampFormats:
        try:
            datetime.datetime.strptime(string, timeStampFormat)
            return True
        except ValueError:
            continue
    
    return False


def is_date_in_string(string):
    '''
    Check if string is date, date time or timestamp.

    Parameters
    ----------
    string : str
        String to be checked.

    Returns
    -------
    Date : str
        If string is date.
    DateTime : str
        If string is date time.
    Timestamp : str
        If string is timestamp.
    False : bool
        If string is not date, date time or timestamp.
    '''
    if is_date(string):
        return "Date"
    elif is_datetime(string):
        return "Datetime"
    elif is_timestamp(string):
        return "Timestamp"
    else:
        return False


def isFloat(string):
    '''
    Check if string is float.

    Parameters
    ----------
    string : str
        String to be checked.
    
    Returns
    -------
    True : bool
        If string is float.
    False : bool
        If string is not float.
    '''
    try:
        float(string)
        return True
    except ValueError:
        return False


# Get RED Icon
def getRedIcon():
    '''
    Get red icon path for GUI.

    Returns
    -------
    redIconPath : str
    
    '''
    try:
        # Check if dir exist
        if os.path.exists(os.path.join(os.environ.get('WSL_BINDIR',''), 'Icons')):
            if os.path.exists(os.path.join(os.environ.get('WSL_BINDIR'), 'Icons\Red.ico')):
                return os.path.join(os.environ.get('WSL_BINDIR'), 'Icons\Red.ico')
            else:
                return os.path.join(os.environ.get('WSL_BINDIR'), 'Icons\Load.ico')
        else:
            return None
    except Exception:
        return None


def getOrcData(parameterObject, readType):
    '''
    Read orc file and return pandas dataframe

    Parameters
    ----------

    parameterObject : dict
        Dictionary of parameters. Meta data created from function 'createParserObject' from Browse_File_Parser.py
    readType : str
        Method to read orc file.
    
    Returns
    -------
    df : pandas.DataFrame
    
    '''

    with open(parameterObject['filePath'], readType) as fp:
        reader = pyorc.Reader(fp)
        records = [r for r in reader]
        df = pd.DataFrame.from_records(records)
        df.columns = reader.schema.fields
        return df

def getLimitedData(parameterObject,errorStream):
    '''
    Read data from file and return limited data (based on rowcount). This function is used for Delimited, Excel, Parque.

    Parameters
    ----------
    parameterObject : dict
        Dictionary of parameters. Meta data created from function 'createParserObject' from Browse_File_Parser.py
    errorStream : str
        Error stream function from Browse_File_Parser.py
    
    Returns
    -------
    df : pandas.DataFrame
    
    '''

    # Get max rows and columns from the data frame
    pd.set_option("display.max_rows", None)
    pd.set_option('display.max_columns', None)
    recordDelimiter = str(parameterObject['recordDelimiter'])
    fieldDelimiter = str(parameterObject['fieldDelimiter'])
    fieldEnclosure = str(parameterObject['fieldEnclosure'])
    if parameterObject['headerLine'] != None and parameterObject['headerLine'] != '':
        headerLine = int(parameterObject['headerLine'])
    else:
        headerLine = parameterObject['headerLine']

    header = parameterObject['header']
    
    # Read CSV/Plain/Txt File
    if parameterObject['parser'].lower() == 'delimited':

        file = open(parameterObject['filePath'], encoding=parameterObject['encodingType']).read()
        isQuoting = csv.QUOTE_NONE if fieldEnclosure == '' else csv.QUOTE_ALL

        if file.count(fieldDelimiter) > 2 and recordDelimiter in [r"\\n", r"\\r", r"\\r\\n", r"\n", r"\r", r"\r\n"]:
            if fieldEnclosure == '':
                data = csv.reader(file.splitlines(), delimiter=fieldDelimiter)
            else:
                data = csv.reader(file.splitlines(), delimiter=fieldDelimiter, quotechar=fieldEnclosure, quoting=isQuoting)
            
        elif file.count(recordDelimiter) > 2 and file.count(fieldDelimiter) > 2:
            if fieldEnclosure == '':
                data = csv.reader(file.splitlines(), delimiter=fieldDelimiter)
            else:
                data = csv.reader(file.split(recordDelimiter), delimiter=fieldDelimiter, quotechar=fieldEnclosure, quoting=isQuoting)
        else:
            data = "SINGLE_RECORD"
        
        # file.close()

        if data != "SINGLE_RECORD":
            rows = []
            for row in data:
                rows.append(row)
               
            if header == True:
                header = rows[headerLine]
                rows = rows[headerLine+1:]
            else:
                header = [str(f"COL_{i}") for i in range(0,len(rows[0]))]
                rows = rows[0:]
            try:
                df = pd.DataFrame(rows, columns=header)
            except Exception as e:
                errorStream.write(f"Error in converting CSV file to DataFrame: {str(e)}")
                df = pd.DataFrame()
    
            if df.empty:
                data = "SINGLE_RECORD"
                return data

        elif data == "SINGLE_RECORD":
            return data

    # Read Excel File
    elif parameterObject['parser'].lower() == 'xlsx':
        try:
            df = pd.read_excel(
            parameterObject['filePath'], 
            header=headerLine,
            sheet_name=parameterObject['SheetName'])            
        except UnicodeDecodeError:
            data = open(parameterObject['filePath'], encoding=parameterObject['encodingType'])
            df = pd.read_excel(data, header=headerLine,sheet_name=parameterObject['SheetName'])
            data.close()

        if header == False:
            df.columns = [f'COL_{str(col)}' for col in df.columns]

    # Read Parquet File
    elif parameterObject['parser'].lower() == 'parquet':
        df = pd.read_parquet(
            parameterObject['filePath'], 
            engine='auto')
    
    # Get the total row count
    parameterObject['rowCount'] = len(df.index)

    # Limit data profiling to specified rows.
    df = df[parameterObject['skipLine'] : parameterObject['rowLimit']]
    
    return df

def filterColumnName(columnName):
    '''
    Regex to filter column name to remove numbers inside the square brackets ([~]).

    Parameters
    ----------

    columnName : str
        Column name to be filtered.

    Returns
    -------

    columnName : str
        Filtered column name.
    '''

    if bool(re.search(r"\[(.*?)\]", str(columnName).strip())) == True:
        columnName = re.sub(r"\[(.*?)\]",r"[]", str(columnName))
    return columnName

def filterColumnNameForXML(columnName):
    '''
    XML Column name is converted into '.' method from xPath.

    Parameters
    ----------
    
    columnName : str
        Column name to be converted into xPath format.
    
    Returns
    -------

    columnName : str
        xPath format of column name.
    '''

    if columnName[0] == '/':
        columnName = columnName[1:]
    
    columnName = columnName.replace("/",".")
    if bool(re.search(r"\[(.*?)\]", str(columnName).strip())) == True:
        columnName = re.sub(r"\[(.*?)\]",r"[]", str(columnName))
    return columnName


def switchColumnNames(dataFromJSONViewer,columnName,entityName, parser):
    '''
    Replace original column name with the new column name assigned by user during entity creation in JSON/XML Viewer.

    Parameters
    ----------
    dataFromJSONViewer : dict
        GUI data from JSON/XML Viewer.
    columnName : str
        Original column name.
    entityName : str
        Entity name.
    parser : str
        Parser type.
    
    Returns
    -------

    columnName : str
        New column name.
    '''

    newColumnName = columnName
    for i in dataFromJSONViewer:
        if entityName in i:
            if i[entityName]["ChangedNames"]:
                for j in i[entityName]["ChangedNames"]:
                    if parser == 'json':
                        if filterColumnName(j["OldName"]) == columnName:
                            newColumnName = j["NewName"]
                    else:
                        if filterColumnNameForXML(j["OldName"]) == columnName:
                            newColumnName = j["NewName"]

    return newColumnName

def singleColumnJSON(parameterObject):
    '''
    Single column data profiling. Used to represent if any error occurs during data profiling.
    
    '''


    columnMetaList = []

    columnMetaList.append({
          "name": "COL1",
          "dataType": "varchar",
          "dataTypeLength": 777,
          "dataTypeScale": None,
          "dataTypePrecision": None,
          "nullAllowed": True,
          "defaultValue": "",
          "description": "",
          "displayName": "COL1",
          "format": "",
          "additive": False,
          "numeric": False,
          "attribute": False,
          "sourceTable": str(parameterObject['fileName']),
          "sourceColumn": "COL1",
          "transform": "",
          "transformType": "",
          "uiConfigColumnProperties": {}
        })

    return columnMetaList

# IMP: This function is not in used. For Parsing of xml data, we are using 'parseJSONPath' function by converting xml data to json data. This function is kept for future reference. For more information, please refer to 'XSD schema' part in 'parseJSONPath' function.
def parseXMLPath(parameterObject, xmlPath):
    '''
    Data profiling for XML file using xPath.

    Parameters
    ----------

    parameterObject : dict
        Dictionary of parameters. Meta data created from function 'createParserObject' from Browse_File_Parser.py
    xmlPath : str
        XML path create by JSON/XML Viewer. Dot notation is converted into xPath format.
    
    Returns
    -------

    columnLenMax: int
        Maximum length of column.
    dataType: str
        Data type of column.
    '''
    
    xmlAttrib = False
    
    xmlPath = xmlPath.replace('.', '/')
    xmlPath = '/' + xmlPath

    lastNode = xmlPath.split('/')[-1]

    if lastNode.startswith('#'):
        # remove last node from xmlPath
        xmlPath = xmlPath[:-len(lastNode)]
        if xmlPath[-1] == '/':
            xmlPath = xmlPath[:-1]
    
    elif lastNode.startswith('@'):
        xmlAttrib = True

    xml_file = open(parameterObject['filePath'], encoding=parameterObject['encodingType'])

    tree = etree.parse(xml_file)
    root = tree.getroot()

    columnData = []

    for match in tree.xpath(xmlPath):
        if xmlAttrib == True:
            columnData.append(match)
        else:
            columnData.append(match.text)

    columnLenMax = max(len(str(x)) for x in columnData)

    # Check the data type of the column
    dataTypeList = []
    for i in columnData:
        if "[***]" in str(i):
            dataTypeList.append("JSON")
        elif str(i).isnumeric() == True:
            dataTypeList.append('int')
        elif isFloat(str(i)) == True:
            dataTypeList.append('float')
        elif is_date_in_string(str(i)) != False:
            dataTypeList.append(is_date_in_string(str(i)))
        else:
            dataTypeList.append('str')

    if 'int' in dataTypeList:
        dataType = 'numeric'
    if 'float' in dataTypeList:
        dataType = 'float'
    if 'str' in dataTypeList:
        dataType = 'string'
    if 'Date' in dataTypeList:
        dataType = 'date'
        columnLenMax = 0
    if 'Datetime' in dataTypeList:
        dataType = 'datetime'
        columnLenMax = 0
    if 'Timestamp' in dataTypeList:
        dataType = 'timestamp'
        columnLenMax = 0

    return columnLenMax, dataType

def createColumnForEntity(jsonData, columnNameList, entityName, dataFromJSONViewer, parameterObject, trim, errorStream):
    '''
    Create column entity for 'BROWSE JSON' based on JSON/XML Viewer data.

    Parameters
    ----------
    jsonData : dict
        JSON data (not needed incase of XML).
    columnNameList : list
        List of column names.
    entityName : str
        Entity name.
    dataFromJSONViewer : dict
        GUI data from JSON/XML Viewer.
    parameterObject : dict
        Parameters for data profiling.
    errorStream : str
        Error stream.
    
    Returns
    -------

    columnMetaList : list
        List of column meta data for 'BROWSE JSON'.

    '''

    columnMetaList = []
    completedCols = []
    completedSourceColumns = []

    # Progress Bar Starts
    root = tk.Tk()
    center(root)

    if parameterObject['parser'].upper() == 'XML':
        root.title(f"Profiling XML Data - {entityName}")
    else:
        root.title(f"Profiling JSON Data - {entityName}")

    root.resizable(False, False)
    root.iconbitmap(getRedIcon())
    root.geometry('{}x{}'.format(500, 100))
    progress_var = tk.DoubleVar()
    currentColumnLabelVar = tk.StringVar()
    theLabel = tk.Label(root, textvariable=currentColumnLabelVar)
    theLabel.pack()
    progress_bar = ttk.Progressbar(root, orient="horizontal", length=400, mode="determinate", variable=progress_var, maximum=len(columnNameList))
    progress_bar.pack()
    progress_bar.start()

    # Create Cancel and Skip Button
    cancelButton = tk.Button(
        root, text="Cancel", command=root.destroy, height=1, width=7)
    cancelButton.pack(pady=5, padx=5)

    try:
        root.update()
        for k, column in enumerate(columnNameList):

            # If key is empty or invalid
            if column == '[].':
                continue

            currentColumnLabelVar.set(f"Processing: {column}")
            progress_var.set(k)
            root.update()
            time.sleep(0.02)
            try:
                if parameterObject['parser'].upper() == 'JSON':
                    columnLenMax, dataType = parseJSONPath(jsonData, column)
                else:
                    with open(parameterObject['filePath'], encoding=parameterObject['encodingType']) as f:
                        xmlJson = xmltodict.parse(f.read())
                        file_data = json.dumps(xmlJson)
                        file_data = json.loads(file_data)
                        jsonData = file_data
                    
                    columnLenMax, dataType = parseJSONPath(jsonData, column)
                    regex = r"\[(.*?)\]"
                    subst = ""
                    column = re.sub(regex, subst, column, 0, re.MULTILINE)
                    if column.endswith('#text'):
                        column = column.replace('.#text', '')

            except Exception as e:
                errorStream.write(f"Error in parsing {column}: {str(e)}\n")
                continue
        
            # If column is directly child of json array, remove extra brackets from column name
            if column[0:3] == '[].':
                column = column[3:]

            if dataFromJSONViewer != None and entityName != None:
                sourceColumn = column
                column = switchColumnNames(dataFromJSONViewer, str(
                    column), entityName, parameterObject['parser'].lower())
            else:
                sourceColumn = column
                column = column
            
            regex = r"\[(.*?)\]"
            if bool(re.match(regex,str(column).strip())) == True:
                index = re.search(regex,str(column).strip()).group(1)
                column = re.sub(index, r"", str(column))

            if len(str(column).strip()) >=64 and trim:
                column = column[-64:]

            # sourceColumn = str(str(sourceColumn).strip()).replace(" ", "_")
            columnNameFiltered = str(str(column).strip()).replace(" ", "_")

            # Remove double quotes from column name and source column name
            columnNameFiltered = columnNameFiltered.replace('"', '')
            sourceColumn = sourceColumn.replace('"', '')
            column = column.replace('"', '')

            specialCharRegex = r"[^a-zA-Z0-9 @ [\.\] \n\.]"
            sourceColumn = re.sub(specialCharRegex, '_', sourceColumn)
            columnNameFiltered = re.sub(specialCharRegex, '_', columnNameFiltered)

            if str(sourceColumn).strip() in completedSourceColumns:
                continue

            oldColumnName = str(columnNameFiltered).strip()

            if str(columnNameFiltered).strip() in completedCols:                
                # check the number of times the column is repeated in completedCols                
                columnNameFiltered = columnNameFiltered[3:]
                oldColumnName = str(columnNameFiltered).strip()
                columnNameFiltered = columnNameFiltered + "_" + str(completedCols.count(str(oldColumnName).strip()))


            # Create column's JSON object and append it to the list
            columnMetaList.append({
                "name": f"{str(columnNameFiltered).strip()}",
                "dataType": f"{dataType}",
                "dataTypeLength": columnLenMax,
                "dataTypeScale": None,
                "dataTypePrecision": None,
                "nullAllowed": True,
                "defaultValue": "",
                "description": "",
                "displayName": f"{str(column).strip()}",
                "format": "",
                "additive": False,
                "numeric": False,
                "attribute": False,
                "sourceTable": str(parameterObject['fileName']),
                "sourceColumn": f"{str(sourceColumn).strip()}",
                "transform": "",
                "transformType": "",
                "uiConfigColumnProperties": {}
            })
            completedCols.append(str(oldColumnName).strip())
            completedSourceColumns.append(str(sourceColumn).strip())
    except Exception as e:
        # Cancel button clicked
        errorStream.write(
            f"Profiling stopped for 'Entity: {entityName}' by user or error in profiling: {str(e)}")
        # root.destroy()
        return None

    # Progress Bar Ends
    root.destroy()
    return columnMetaList


def getPrecisionAndScale(dataType):
    '''
    Extract precision and scale from data type.

    Parameters
    ----------
    dataType : str
        Data type with precision and scale.
        Sample Format: 'decimal128(10,2)'
    
    Returns
    -------
    dataType: str
        Data type without precision and scale.
        Sample Format: 'decimal128'
    precision : int
        Precision.
    scale : int
        Scale.
    '''
    
    regex = r"([^(,)]+)(?!.*\()"
    matches = re.finditer(regex, dataType, re.MULTILINE)

    values = []
    for matchNum, match in enumerate(matches, start=1):
        for groupNum in range(0, len(match.groups())):
            groupNum = groupNum + 1
            value = match.group(groupNum)
            values.append(value.strip())
            
    precision = values[0]
    scale = values[1]

    dataType = dataType.split("(")[0]

    return dataType, int(precision), int(scale)


# Create JSON Column
def getColumnJSON(df, parameterObject,jsonDataFromGUI,entityName):
    '''
    Create column entity for 'BROWSE JSON' for 'Parquet', 'Avro', 'Orc', 'Delimited', 'Excel'.

    Parameters
    ----------
    df : pandas.DataFrame
        Pandas dataframe.
    parameterObject : dict
        Parameters for data profiling.
    jsonDataFromGUI : dict
        GUI data from JSON/XML Viewer.
    entityName : str
        Entity name.
    
    Returns
    -------

    columnMetaList : list
        List of column meta data for 'BROWSE JSON'.

    '''
    
    if parameterObject['parser'].lower() == 'parquet':
        parquetMetaData = pq.read_metadata(parameterObject['filePath'], memory_map=True)
        parquetSchema = pq.read_schema(parameterObject['filePath'], memory_map=True)
    elif parameterObject['parser'].lower() == 'avro':
        avrodata = open(parameterObject['filePath'], 'rb')
        avro_reader = DataFileReader(avrodata, DatumReader())
        metadata = copy.deepcopy(avro_reader.meta)
        avroSchema = json.loads(metadata['avro.schema'])
        # avrodata.close()
    elif parameterObject['parser'].lower() == 'orc':
        with open(parameterObject['filePath'], "rb") as downloaded_file:
            reader = pyorc.Reader(downloaded_file)

    # List which holds the Column's JSON
    columnMetaList = []

    if parameterObject['parser'].lower() == 'parquet':
        # columnNames = parquetMetaData.schema.names
        columnNames = zip(parquetSchema.names, parquetSchema.types)
    elif parameterObject['parser'].lower() == 'orc':
        columnNames = reader.schema.fields
    else:
        # Convert column data frame to list of column names
        columnNames = df.columns.values.tolist()

    # Loop through column list
    for columnIndex, column in enumerate(columnNames):
        scale = None
        precision = None

        # For Parquet column meta data is used directly to get the column data type
        if parameterObject['parser'].lower() == 'parquet':
            columnName = column[0]
            columnConvertedType = column[1]
            columnType = parquetMetaData.row_group(0).column(columnIndex).physical_type

            profilingFactor = parameterObject['profilingFactor']
            columnLenMax = round(profilingFactor*parquetMetaData.row_group(0).column(columnIndex).total_uncompressed_size/parquetMetaData.row_group(0).column(columnIndex).num_values)

            if columnConvertedType == None or columnConvertedType == '':
                dataType = str(columnType)
            else:
                dataType = str(columnConvertedType)
            
            # If dataType has () in it, then extract the precision and scale
            if "(" in dataType and ")" in dataType:
                # Extract precision and scale
                dataType, precision, scale = getPrecisionAndScale(str(dataType))

            if "[" in dataType and "]" in dataType:
                dataType = dataType.split("[")[0]

            if dataType == 'BYTE_ARRAY':
                columnLenMax = columnLenMax * 100
            
            if dataType.lower() in ['string', 'varchar']:
                scale = None
                precision = None
            
            column = columnName
     
        elif parameterObject['parser'].lower() == 'orc':
            profilingFactor = parameterObject['profilingFactor']
            columnMeta = pyorc.Column(reader, columnIndex)
            dataType = str(columnMeta.statistics['kind']).replace('TypeKind.','')
            columnDataSize = str('null')
            if 'total_length' in columnMeta.statistics:
                columnDataSize = str(round(profilingFactor*columnMeta.statistics['total_length']/columnMeta.statistics['number_of_values']))

            if columnDataSize == 'null':
                columnLenMax = None
            else:
                columnLenMax = int(columnDataSize)

        # For Avro column meta data is used directly to get the column data type
        elif parameterObject['parser'].lower() == 'avro':
            dataType = avroSchema['fields'][columnIndex]['type']
            if isinstance(dataType, list):
                dataType = dataType[1]

            columnData = df[column].values.tolist()
        
            # Check the max length of the column
            columnLenMax = max(len(str(x)) for x in columnData)

        # For other file types column data type is determined by looping through the column data
        else:
            columnData = df[column].values.tolist()
            # Check the max length of the column
            columnLenMax = max(len(str(x)) for x in columnData)

            # Check the data type of the column
            dataTypeList = []
            for i in columnData:

                if "[***]" in str(i):
                    dataTypeList.append("JSON")
                elif str(i).isnumeric() == True:
                    dataTypeList.append('int')
                elif isFloat(str(i)) == True:
                    dataTypeList.append('float')
                elif is_date_in_string(str(i)) != False:
                    dataTypeList.append(is_date_in_string(str(i)))
                else:
                    dataTypeList.append('str')

            if 'int' in dataTypeList:
                dataType = 'numeric'
            if 'float' in dataTypeList:
                dataType = 'float'
            if 'str' in dataTypeList:
                dataType = 'string'
            if 'Date' in dataTypeList:
                dataType = 'date'
                columnLenMax = 0
            if 'Datetime' in dataTypeList:
                dataType = 'datetime'
                columnLenMax = 0
            if 'Timestamp' in dataTypeList:
                dataType = 'timestamp'
                columnLenMax = 0

        checkColumnIsNull = True

        if jsonDataFromGUI != None and entityName != None:
            sourceColumn = column
            column = switchColumnNames(jsonDataFromGUI, str(column), entityName,parameterObject['parser'].lower())
        else:
            sourceColumn = column
            column = column

        if parameterObject['parser'].lower() == 'xml' and "}" in sourceColumn:
            sourceColumn = sourceColumn.split("}")[-1]
        elif parameterObject['parser'].lower() == 'xml' and "[]." in sourceColumn:
            sourceColumn = sourceColumn.split("[].")[-1]
        
        regex = r"\[(.*?)\]"
        if bool(re.match(regex,str(column).strip())) == True:
            index = re.search(regex,str(column).strip()).group(1)
            column = re.sub(index, r"", str(column))

        if len(str(column).strip()) >=64:
            column = column[-64:]

        sourceColumn = str(str(sourceColumn).strip()).replace(" ", "_")
        columnNameFiltered = str(str(column).strip()).replace(" ", "_")

        specialCharRegex = r"[^a-zA-Z0-9 @ [\.\] \n\.]"
        sourceColumn = re.sub(specialCharRegex, '_', sourceColumn)
        columnNameFiltered = re.sub(specialCharRegex, '_', columnNameFiltered)

        if parameterObject['parser'].lower() == 'xml' and "}" in columnNameFiltered:
            columnNameFiltered = columnNameFiltered.split("}")[-1]
        elif parameterObject['parser'].lower() == 'xml' and "@" in columnNameFiltered:
            columnNameFiltered = columnNameFiltered.split("@")[-1]
        elif parameterObject['parser'].lower() == 'xml' and "[]." in columnNameFiltered:
            columnNameFiltered = columnNameFiltered.split("[].")[-1]
        elif parameterObject['parser'].lower() == 'xml' and "__." in columnNameFiltered:
            columnNameFiltered = columnNameFiltered.split("__.")[-1]
        
        # Create column's JSON object and append it to the list
        columnMetaList.append({
          "name": f"{str(columnNameFiltered).strip()}",
          "dataType": f"{dataType}",
          "dataTypeLength": columnLenMax,
          "dataTypeScale": scale,
          "dataTypePrecision": precision,
          "nullAllowed": checkColumnIsNull,
          "defaultValue": "",
          "description": "",
          "displayName": f"{str(column).strip()}",
          "format": "",
          "additive": False,
          "numeric": False,
          "attribute": False,
          "sourceTable": str(parameterObject['fileName']),
          "sourceColumn": f"{str(sourceColumn).strip()}",
          "transform": "",
          "transformType": "",
          "uiConfigColumnProperties": {}
        })
    return columnMetaList


# Create JSON Body
def createJsonBody(parameterObject, columnList, rowCount, objectHead, objectKey):
    '''
    Create JSON Body for 'BROWSE JSON' (For JSON Head).

    Parameters
    ----------

    parameterObject : dict
        Dictionary containing the parameters for the file.
    
    columnList : list
        List containing the column meta data json objects. Created by functions like getColumnJSON(), createColumnForEntity()
    
    rowCount : int
        Number of rows to profile.
    
    objectHead : str
        This is the head for JSON Body. Pass the variable which holds JSON Head from Browse_File_Parser.py
    
    objectKey : str
        This is the key for JSON Body. Pass the variable which holds 'localPath' from Browse_File_Parser.py

    Returns
    -------

    jsonBody : dict
        Dictionary containing the JSON Body.
    
    '''


    if parameterObject['connectionType'] == 'local':
        path = parameterObject['filePath'].replace( '\\' + parameterObject['fileName'], '')
    else:
        path = parameterObject['connectionString']

    if parameterObject['parser'].lower() == 'xlsx':
        fileName = parameterObject['fileName'].split('.')[0]
        sfileName = str(parameterObject['fileName'].split('.')[0]) + "." + parameterObject['SheetName'] + ".xlsx"
    else:
        fileName = parameterObject['fileName']
        sfileName = parameterObject['fileName']
    
    if columnList[0]['dataTypeLength'] == 777:
        fileName = parameterObject['fileName'] + "_[Profiling failed. Please check error log file in work directory]"
        sfileName = fileName
    
    objectHead[objectKey][fileName] = {
      "name": str(parameterObject['fileName'].split('.')[0]),
      "description": "",
      "rowCount": rowCount,
      "columns": columnList,
      "loadInfo": {
        "fileLoaderOptions": "",
        "fileParsed": False,
        "overrideLoadSQL": "",
        "overrideSourceColumns": "",
        "selectDistinctValues": False,
        "sourceFile": {
          "charSet": "",
          "escapeEncoding": "",
          "fieldDelimiter": str(parameterObject['fieldDelimiter']),
          "fieldEnclosure": "\"" if str(parameterObject['fieldEnclosure']) == "\"" else str(parameterObject['fieldEnclosure']),
          "headerLine": True if parameterObject['header'] == True else False,
          "name": str(sfileName),
          "nonStringNullEncoding": "",
          "nullEncoding": "",
          "path": path,
          "recordDelimiter": r"\\n" if str(parameterObject['recordDelimiter']) == r"\n" else str(parameterObject['recordDelimiter'])
        },
        "sourceSchema": "",
        "sourceTables": str(parameterObject['fileName']),
        "useOverrideSourceColumns": False,
        "whereAndGroupByClauses": ""
      },
      "uiConfigLoadTableProperties": {
          "fileType": str(parameterObject['parser'].strip()).upper(),
      }
    }

# Same function as createJsonBody() but for 'JSON Files'
def createJsonBodyForSubJSONEntity(parameterObject, columnList, rowCount, objectHead, objectKey, entity_name):

    if parameterObject['connectionType'] == 'local':
        path = parameterObject['filePath'].replace( '\\' + parameterObject['fileName'], '')
    else:
        path = parameterObject['connectionString']
    
    objectHead[objectKey][f'{entity_name}'] = {
      "name":str(entity_name).split('.')[0],
      "description": "",
      "rowCount": rowCount,
      "columns": columnList,
      "loadInfo": {
        "fileLoaderOptions": "",
        "fileParsed": False,
        "overrideLoadSQL": "",
        "overrideSourceColumns": "",
        "selectDistinctValues": False,
        "sourceFile": {
          "charSet": "",
          "escapeEncoding": "",
          "fieldDelimiter": str(parameterObject['fieldDelimiter']),
          "fieldEnclosure": "\"" if str(parameterObject['fieldEnclosure']) == "\"" else str(parameterObject['fieldEnclosure']),
          "headerLine": True if parameterObject['header'] == True else False,
          "name": str(parameterObject['fileName']),
          "nonStringNullEncoding": "",
          "nullEncoding": "",
          "path": path,
          "recordDelimiter": "\\n" if str(parameterObject['recordDelimiter']) == "\n" else str(parameterObject['recordDelimiter'])
        },
        "sourceSchema": "",
        "sourceTables": str(parameterObject['fileName']),
        "useOverrideSourceColumns": False,
        "whereAndGroupByClauses": ""
      },
      "uiConfigLoadTableProperties": {
          "fileType": str(parameterObject['parser'].strip()).upper(),
      }
    }


# This function to center root window of Popup UI
def center(win):
    """
    centers a tkinter window
    :param win: the main window or Toplevel window to center
    """
    win.update_idletasks()
    width = win.winfo_width()
    frm_width = win.winfo_rootx() - win.winfo_x()
    win_width = width + 2 * frm_width
    height = win.winfo_height()
    titlebar_height = win.winfo_rooty() - win.winfo_y()
    win_height = height + titlebar_height + frm_width
    x = win.winfo_screenwidth() // 2 - win_width // 2
    y = win.winfo_screenheight() // 2 - win_height // 2
    win.geometry('{}x{}+{}+{}'.format(width, height, x, y))
    win.deiconify()
    

def parseJSONPath(jsonData, jsonPath):
    '''
    Profile JSON Data using JSON Path.

    Parameters
    ----------

    jsonData : dict
        Dictionary containing the JSON Data.
    
    jsonPath : str
        JSON Path to profile. Dot notation created in JSON/XML Viewer.
    
    Returns
    -------

    columnLenMax : int
        Maximum length of the column.
    dataType : str
        Data type of the column.
    '''

    jsonPath = jsonPath.split(".")

    for i in jsonPath:
        res = bool(re.match("^(?=.*[a-zA-Z])(?=.*[\d])[a-zA-Z\d]+$", i))
        if res:
            element = ("\"%s\""% i)
            index = jsonPath.index(i)
            jsonPath[index] = element

    jsonPath = ('.'.join(map(str,jsonPath)))

    jsonPath = jsonPath.replace('[*].', '').replace('*', '').replace('"', '')

    if "[]" not in jsonPath:
        jsonPath = "[*]." + jsonPath

    regex = r"\[\]"
    subst = "[*]"
    jsonPath = re.sub(regex, subst, jsonPath, 0, re.MULTILINE)

    # XSD schema start
    # This part handles the XML file which have XSD schema.
    jsonPathSplit = jsonPath.split('.')
    jsonPathSplitList = []
    for pathString in jsonPathSplit:
        if ":" in pathString or "#" in pathString or "@" in pathString:
            if pathString[-3:] == "[*]":
                jsonPathSplitList.append(f'"{pathString[:-3]}"[*]')
            else:
                if pathString[0] == '"' and pathString[-1] == '"':
                    jsonPathSplitList.append(pathString)
                else:
                    jsonPathSplitList.append(f'"{pathString}"')
        elif " " in pathString:
            jsonPathSplitList.append(f'"{pathString}"')
        else:
            jsonPathSplitList.append(pathString)

    # XSD schema end
    jsonPath = '.'.join(jsonPathSplitList)
    jsonPath = re.sub(r'\.(\d+)\.', r'."\1".', jsonPath)
    jsonPath = re.sub(r'\.(\d+)', r'."\1"', jsonPath)
    jsonpathExpression = parse(jsonPath)

    columnData = []

    for match in jsonpathExpression.find(jsonData):
        columnData.append(match.value)

    columnLenMax = max(len(str(x)) for x in columnData)

    # Check the data type of the column
    dataTypeList = []
    for i in columnData:
        if "[***]" in str(i):
            dataTypeList.append("JSON")
        elif str(i).isnumeric() == True:
            dataTypeList.append('int')
        elif isFloat(str(i)) == True:
            dataTypeList.append('float')
        elif is_date_in_string(str(i)) != False:
            dataTypeList.append(is_date_in_string(str(i)))
        else:
            dataTypeList.append('str')

    if 'int' in dataTypeList:
        dataType = 'numeric'
    if 'float' in dataTypeList:
        dataType = 'float'
    if 'str' in dataTypeList:
        dataType = 'string'
    if 'Date' in dataTypeList:
        dataType = 'date'
        columnLenMax = 0
    if 'Datetime' in dataTypeList:
        dataType = 'datetime'
        columnLenMax = 0
    if 'Timestamp' in dataTypeList:
        dataType = 'timestamp'
        columnLenMax = 0
    
    jsonPath = jsonPath.replace('*', '').replace('"', '')
    if str(jsonPath[-4:]) == "[][]":
        dataType = 'string'
        columnLenMax = 4000

    return columnLenMax, dataType

def flattenForKeys(dictionary, parent_key=False, separator='.', isList=False):
    '''
    Flatten a dictionary to a list of keys with dot notation. Used when entire JSON file needs to be profiled.

    Parameters
    ----------

    dictionary : dict
        Dictionary containing the JSON Data.
    parent_key : bool
        Parent key of the dictionary.
    separator : str
        Separator to use for the dot notation.
    isList : bool
        If the dictionary is a list.

    Returns
    -------

    flattenedDict : dict
        Flattened dictionary.

    '''

    items = []
    for key, value in dictionary.items():
        if isList == True:
            new_key = str(parent_key) + '[' + key + ']' if parent_key else key
        else:
            new_key = str(parent_key) + separator + key if parent_key else key

        if isinstance(value, MutableMapping):
            if not value.items():
                items.append((new_key, None))
            else:
                items.extend(flattenForKeys(value, new_key, separator).items())
        elif isinstance(value, list):
            if len(value):
                for k, v in enumerate(value):
                    items.extend(
                        flattenForKeys({str(k): v}, new_key, isList=True).items())
            else:
                items.append((new_key, None))
        else:
            items.append((new_key, value))
    return dict(items)

def getAllJSONKeys(filePath, parser, encodingType):
    '''
    This function calls flattenForKeys() and extracts all the keys from the JSON/XML data.

    Parameters
    ----------

    filePath : str
        Path of the JSON file.
    parser : str
        Parser to use for the JSON file.
    encodingType: str
        Encoding type of the JSON file.

    Returns
    -------

    jsonKeys : list
        List of all the keys in the JSON/XML data.
    '''

    if parser == 'XML':
        with open(filePath, encoding=encodingType) as f:
            xmlJson = xmltodict.parse(f.read())
            json_data = json.dumps(xmlJson)
            jsonData = json.loads(json_data)
    else:
        jsonData = json.load(open(filePath, encoding=encodingType))

    if isinstance(jsonData, list):
        allKeysFromList = []
        for item in jsonData:
            itemObject = flattenForKeys(item)
            for key, value in itemObject.items():
                allKeysFromList.append(key)

        allKeys = list(set(allKeysFromList))
        
    elif isinstance(jsonData, dict):
        result = flattenForKeys(jsonData)
        allKeys = []
        for key, value in result.items():
            allKeys.append(key)

    return allKeys

