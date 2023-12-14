from jsonpath_ng import parse
import json
import pandas as pd
import re
import xmltodict
from collections.abc import MutableMapping
import sys
import os
import csv


def checkList(list_):
    if isinstance(list_,dict): 
        return all(isinstance(i,(dict) ) for i in list_)
    else:
       return  all(isinstance(i, (int,float,str,list)) for i in list_)


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
    
    
def sanitizeString(column):
    column = re.sub(r"\[(.*?)\]", "[*]", column, 0, re.MULTILINE)
    column = re.sub(r'\.(\d+)\.', r'."\1".', column)
    column = re.sub(r'\.(\d+)', r'."\1"', column)
    jsonPathSplit = column.split('.')
    jsonPathSplitList = []
    for pathString in jsonPathSplit:
        if ":" in pathString or "#" in pathString or "@" in pathString:
            if pathString[-3:] == "[*]":
                jsonPathSplitList.append(f'"{pathString[:-3]}"[*]')
            else:
                jsonPathSplitList.append(f'"{pathString}"')
        else:
            jsonPathSplitList.append(pathString)
    pathOfSelectedNode = '.'.join(jsonPathSplitList)  
    return pathOfSelectedNode
    
    
def jsonToCsv(filePath, encodingType, downloadLocation, headers=[]):

    '''
    This function converts the JSON file to CSV.

    Parameters
    ----------
    filePath : str
        Path of the JSON file.
    encodingType: str
        Encoding type of the JSON file.
    headers : list
        List of headers to be used in the CSV file.
    
    Returns
    -------
    csvFile : str
        Path of the CSV file.

    '''

    if headers == []:
        headers = getAllJSONKeys(filePath, 'JSON', encodingType)

    headers = [sanitizeString(header) for header in headers]

    csvHeader = []
    
    for header in headers:
        header = re.sub(r"\[(.*?)\]", "[]", header, 0, re.MULTILINE)
        header = re.sub(r'"', "", header, 0, re.MULTILINE)
        csvHeader.append(header)
    
    uniqueHeaders = []
    uniqueCsvHeaders = []

    for header in headers:
        if header not in uniqueHeaders:
            uniqueHeaders.append(header)

    headers = uniqueHeaders.copy()

    for header in csvHeader:
        if header not in uniqueCsvHeaders:
            uniqueCsvHeaders.append(header)

    csvHeader = uniqueCsvHeaders.copy()
    # headers = [head for head in headers if head]
    # csvHeader = [csvhead for csvhead in csvHeader if csvhead]

    # Create a dataframe with the csvHeader
    df = pd.DataFrame(columns=csvHeader)

    # Load the JSON file
    with open(filePath, encoding=encodingType) as f:
        jsonData = json.load(f)
    
    # Convert the JSON data to a csv
    for head in headers:
        if head == "":
            continue

        mainHead = []
        for h in head.split('.'):
            if " " in h:
                mainHead.append(f'"{h}"')
            else:
                mainHead.append(h)

        head = '.'.join(mainHead)

        head = "[*].{}".format(head)
        
        try:
            jsonpathExpression = parse(head)
            data = []
            for match in jsonpathExpression.find(jsonData): 
                if checkList(match.context.value):
                    if match.path.index:
                        data.append(str(match.context.value).replace("\n", "").strip())
                else:
                    if isinstance(match.value, str):
                        data.append((match.value).replace("\n", "").strip()) 
                    else:
                        data.append(str(match.value).replace("\n", "").strip()) 
        except Exception as e:
            print(-2)
            print("Error Converting JSON to CSV: {}".format(e))
            print(f"Node Path: {head}")
            exit()
    
        # To remove [*]. from start of the string
        head = head[4:]

        # Desanitize - JSON
        head = re.sub(r"\[(.*?)\]", "[]", head, 0, re.MULTILINE)

        # Remove Double Quotes
        head = re.sub(r'"', "", head, 0, re.MULTILINE)

        df[head] = pd.Series(data)
    
    fileName = filePath.split(os.sep)[-1]
    fileName = fileName.split(".")[0] + '.csv'
    downloadLocation = os.path.join(downloadLocation, fileName)
    
    df.to_csv(downloadLocation, index=False , quoting=csv.QUOTE_ALL, sep='|')
    
if __name__ == '__main__':    
    jsonToCsv(sys.argv[1], sys.argv[2], sys.argv[3], sys.argv[4].replace("\r\n","").split(','))
