import os,re,random,shutil,math
import sys, csv
import tkinter as tk
import tkinter.font as tkFont
import tkinter.ttk as ttk
# This function returns matching regular expression for the source file name filter.
def fileFilterRegExpressions(fileType):
     if "." in fileType:
         fileNameExtension=fileType.split('.')[1]
         if fileType == "*."+fileNameExtension or fileType == "."+fileNameExtension or fileType == fileNameExtension: 
           fileTypeRegExp = "^.+\."+fileNameExtension+"$"
         elif fileType == "*.*":
           fileTypeRegExp = "^.+\.*$"
         elif fileType == "^"+fileType:
           fileTypeRegExp = "^"+fileType+".+\.*$"
         elif fileType == "^"+fileType+"\*":
           fileTypeRegExp = "^"+fileType+".+"
         elif "*" in fileType :
          fileTypeRegExp = "^"+fileType.split('*')[0]+".*\."+fileNameExtension+"$"
         else:
           fileTypeRegExp = fileType
     else:
         if "*" in fileType :
          fileTypeRegExp = "^"+fileType.split('*')[0]+".*\.*$"
         else:
          fileTypeRegExp = "^"+fileType
     return fileTypeRegExp

# This function creates json part for each column
def createJsonColumns(columnName,columnDataType,columnLength,fileName,columnIndex,newColumns):
                                newColumns = """{
                                "name": """+ '"'+columnName.replace('"','').replace("'",'')+'"'+""",
                                  "dataType": """+'"'+columnDataType+'"'+""",
                                """+columnLength+""",
                                      "dataTypeScale": null,
                                "dataTypePrecision": null,
                                "nullAllowed": true,                    
                                "defaultValue": "",
                                "description": "",
                                "displayName": """+ '"'+columnName.replace('"','').replace("'",'')+'"'+""",
                                "format": "",
                                "additive": false,
                                "numeric": false,
                                "attribute": false,              
                                "sourceTable": """+'"'+fileName+'"'+""",           
                                "sourceColumn": "COL"""+str(columnIndex)+'"'+""",              
                                "transform": "",
                                "transformType": "", 
                                "uiConfigColumnProperties" : {}
                                 },"""
                                return newColumns

# This function creates json for the source information of each source file                           
def createJsonTable(fileName,fieldDelimiter,recordDelimiter,newColumns,newFilesText,headerLine,enclosedBy,path,directory):
                         if enclosedBy == '"':
                             enclosedBy = '\\"'
                         if  recordDelimiter == '\n' or recordDelimiter.strip() =="" or recordDelimiter == '\\n':
                          recordDelimiter = '\\n'
                         newFilesText=newColumns[:-1]+"],"+"""
                               "loadInfo": {
                               "fileLoaderOptions": "",
                               "fileParsed": false,
                               "overrideLoadSQL": "",
                               "overrideSourceColumns": "",
                               "selectDistinctValues": false,
                               "sourceFile": {
                                              "charSet": "",
                                              "escapeEncoding": "",
                                              "fieldDelimiter": """+'"'+str(fieldDelimiter)+'"'+""",
                                              "fieldEnclosure": """+'"'+str(enclosedBy)+'"'+""",
                                              "headerLine": """+headerLine+""",
                                              "name": """+'"'+fileName+'"'+""",
                                              "nonStringNullEncoding": "",
                                              "nullEncoding": "",
                                              "path":  """+path+""",
                                              "recordDelimiter": """+'"'+str(recordDelimiter)+'"'+"""
                                              },
                              "sourceSchema":" """+ directory+""" ",
                              "sourceTables": """+'"'+fileName+'"'+""",
                              "useOverrideSourceColumns": false,
                              "whereAndGroupByClauses": ""
                              },
                             "uiConfigLoadTableProperties" : {}},"""
                         return newFilesText
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

# This function creates popup UI 
def browseFileUI(fileList):

    root = tk.Tk()
    root.title("Browse Azure Data Lake Gen2 Storage")
    root.geometry('430x430')
    iconPath = str(os.path.join(os.environ.get('WSL_BINDIR'),'Icons\Red.ico'))
    if os.path.exists(iconPath)==False:
     iconPath = str(os.path.join(os.environ.get('WSL_BINDIR'),'Icons\Load.ico'))
    root.iconbitmap(iconPath)
    center(root)
    

    file_header = ['File Name', 'Size']

    labelMessage = """NOTE: Please click to select the file(s) you want to download for Data profiling."""

    msg = ttk.Label(wraplength="4i", justify="left", anchor="w", padding=(10, 2, 10, 6), text=labelMessage)
    msg.pack(fill='x')

    container = ttk.Frame(relief=tk.RAISED, borderwidth=1)
    container.pack(fill='both', expand=True)

    tree = ttk.Treeview(columns=file_header, show="headings",selectmode="none")
    vsb = ttk.Scrollbar(tree, orient="vertical", command=tree.yview)
    vsb.pack(side='right', fill='y')
    
    hsb = ttk.Scrollbar(tree, orient="horizontal", command=tree.xview)
    hsb.pack(side='bottom', fill='x')



    for col in file_header:
        tree.heading(col, text=col.title())
    # adjust the column's width to the header strings
        tree.column(col,
            width=tkFont.Font().measure(col.title()))
    tree.column("File Name", anchor='w')
    tree.column("Size", anchor='w')


    # Custom Select or Focus
    def select(event=None):
        tree.selection_toggle(tree.focus())

    tree.bind("<ButtonRelease-1>", select)
    
    # Print Selected to Focused
    def okButton():
        global selectedRows
        selectedRows = []
        # Multiple File Profiling is working
        for item in tree.selection():
            item_text = tree.item(item)
            selectedRows.append({"item": item_text, "id": item})
        if not selectedRows:
            print(1)
            print("No files selected")
            print("""{"treeViewLayout": "Tabular", "treeViewIcons": {"schema": "project.ico","table": "Smartkey.ico"}}""") 
            sys.exit()

        root.destroy()

    def closeButton():
         print(1)
         print("""{"treeViewLayout": "Tabular", "treeViewIcons": {"schema": "project.ico","table": "Smartkey.ico"}}""")
         root.destroy()
         sys.exit()

    tree.grid(column=0, row=0, sticky='nsew', in_=container)
    container.grid_columnconfigure(0, weight=1)
    container.grid_rowconfigure(0, weight=1)
    tree.configure(yscrollcommand=vsb.set,xscrollcommand=hsb.set)
    
    closeButton = tk.Button(text="Cancel", height=1, width=15, command=closeButton)
    closeButton.pack(side=tk.RIGHT, padx=15, pady=5)


    okButton = tk.Button(text="OK", command=okButton, height=1, width=15)
    okButton.pack(side=tk.RIGHT)

    for i in range(0, len(fileList)):
        tree.insert('', "end", iid=fileList[i]['ID'], text=fileList[i]['name'], 
        values=(fileList[i]['name'], fileList[i]['Size']+' KB'))

    root.mainloop()

    return selectedRows
		
# This function creates json for the single column files like json,xml or files without delimiters
def singleColumnJson(fileName,fieldDelimiter,newColumns,newFilesText,headerLine,enclosedBy,path,directory):
                   newColumns +=createJsonColumns("COL1","varchar",'"dataTypeLength": ' + str("777"),fileName,1,newColumns)
                   newFilesText+=' "'+fileName+'" : { "name" : "'+fileName.split(".")[0]+'","description" : "", "rowCount": 0, "columns" : ['
                   newFilesText+=createJsonTable(fileName,fieldDelimiter,"",newColumns,newFilesText,headerLine,enclosedBy,path,directory)
                   return newFilesText

#Write errors in error file placed at work directory
def writeErrorLog(path,e):
    errorLog=str(os.environ.get('WSL_TASK_NAME',''))+"_"+str(os.environ.get('WSL_SEQUENCE',''))+".err"
    errorStream = open(os.path.join(os.environ.get('WSL_WORKDIR',''),errorLog), 'a+')
    errorStream.write("ERROR: {0}: {1}\n".format(str(path), str(e)))
    errorStream.close()
