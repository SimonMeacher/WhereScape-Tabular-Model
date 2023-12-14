# --    (c) WhereScape Inc 2020. WhereScape Inc permits you to copy this module solely for use with the RED software, and to modify this module            -- #
# --    for the purposes of using that modified module with the RED software, but does not permit copying or modification for any other purpose.           -- #
# --                                                                                                                                                       -- #
#=====================================================================================================
# Module Name      :    WslJsonParserGUI
# DBMS Name        :    Generic for all databases
# Description      :    Generic python functions module used by Browse_File_Parser.py
#                       The Module contains functions to generate GUI to represent JSON and XML Files
#                       in a tree structure.It allows to select/remove entity/tags from the files
# Author           :    Wherescape Inc
#======================================================================================================
# Notes / History
# 1.0.0   2022-02-16   First Version
#======================================================================================================

import json
import tkinter as tk
from tkinter import messagebox
import tkinter.ttk as ttk
import re
import tkinter.font as tkFont
from jsonpath_ng import  parse
from tkinter import simpledialog
import collections
import xmltodict
try:
    collectionsAbc = collections.abc
except AttributeError:
    collectionsAbc = collections


entitiesObjects = []
columnNames = []
parent = []
finalPath = []

class JSONTreeFrame(ttk.Frame):
    def __init__(self,master,encoding='utf-8',MAX_N_SHOW_ITEM=None,parser='JSON',file_path=None,file_data=None,second_json_tree_data=None,mainObject=None,initial_dir="~/"):
        '''
        Initialize the frame and the widgets for Tree View.

        :param master: The parent widget.
        :param MAX_N_SHOW_ITEM: The maximum number of items to show in the tree.
        :param parser: The parser to use i.e JSON or XML.
        :param file_path: The file path of the json/xml file.
        :param file_data: The data of the json/xml file (optional).
        :param second_json_tree_data: The data of the second json/xml file (optional).
        :param initial_dir: The initial directory to open the file dialog.(optional)

        '''

        super().__init__(master)
        self.master = master
        self.customFont = tkFont.Font(family="Tahoma", size=10)
        style = ttk.Style()
        style.configure("Treeview.Heading", font=self.customFont)
        self.tree = ttk.Treeview(self)
        self.tree.tag_configure('TkTextFont', font=self.customFont)
        self.create_widgets()
        self.encoding = encoding
        self.MAX_N_SHOW_ITEM = MAX_N_SHOW_ITEM
        self.sub_win = None
        self.initial_dir = initial_dir
        self.search_box = None
        self.bottom_frame = None
        self.second_frame = None
        self.search_box = None
        self.search_label = None
        self.parser = parser
        self.column = self.tree.column
        self.heading = self.tree.heading
        self.help_title = tk.StringVar()
        self.help_title.set("Create or Add Entities")
        self.help_desc = tk.StringVar()
        self.help_desc.set("Select a node from the treeview and press 'Add' to add it to the list of entities.")
        self.ProfileMainFile = False
        self.trim_value = tk.BooleanVar()
        self.trim_value.set(True)
        
        if file_path:
            self.set_table_data_from_json_path(file_path)
        elif file_data:
            self.set_table_data_from_json(file_data)
        elif second_json_tree_data:
            self.set_table_data_for_second_frame(second_json_tree_data, mainObject)

    def create_widgets(self):
        '''
        Create scrollbar and column/row configuration for the treeview.
        '''

        self.tree.bind('<Double-1>', self.click_item)

        ysb = ttk.Scrollbar(self, orient=tk.VERTICAL, command=self.tree.yview)
        self.tree.configure(yscroll=ysb.set)

        self.tree.grid(row=0, column=0, sticky=(tk.N, tk.S, tk.E, tk.W))
        ysb.grid(row=0, column=1, sticky=(tk.N, tk.S))
        self.columnconfigure(0, weight=1)
        self.rowconfigure(0, weight=1)

    def init_search_box(self):
        '''
        Initialize the search box.        
        '''

        self.bottom_frame = tk.Frame(self)
        self.bottom_frame.grid(column=0, row=2, sticky=(tk.N, tk.S, tk.E, tk.W))

        self.search_label = tk.Label(self.bottom_frame, text="Search:", font=self.customFont)
        self.search_label.pack(side=tk.LEFT, pady=12)

        self.search_box = tk.Entry(self.bottom_frame,width = 45)
        self.search_box.pack(side=tk.LEFT,pady=12)
        self.search_box.bind('<Key>', self.find_word)

        self.addBtn = tk.Button(self.bottom_frame, text="Add", height = 1, width = 7, command=self.addToSelectionList, font=self.customFont)
        self.addBtn.pack(side=tk.LEFT, padx=4,pady=10)
        self.addBtn.bind("<Enter>", lambda event: self.helpDesc("Add Button", "Add selected nodes into existing entitiy or create a new one."))
        self.addBtn.bind("<Leave>", lambda event: self.helpDesc())

    def helpBox(self):
        '''
        Initialize the help box. Help box is the box shown at the bottom of the screen.

        '''


        self.help_frame = tk.Frame(self, width=200, height=200, bg='#dfe1e6',borderwidth=1, relief='flat', highlightthickness=1,highlightbackground="#d0d3d7")

        self.help_frame.grid(column=0, row=3, sticky=(tk.N, tk.S, tk.E, tk.W), columnspan=2,padx=10,pady=10)

        titleFont  = tkFont.Font(family="Tahoma", size=10, weight='bold')
        descFont  = tkFont.Font(family="Tahoma", size=10)

        self.help_label = tk.Label(self.help_frame, textvariable=self.help_title, font=titleFont, bg='#dfe1e6')
        self.help_label.grid(column=0, row=0, sticky=(tk.N, tk.S, tk.E, tk.W))

        self.help_description = tk.Label(self.help_frame, textvariable=self.help_desc, font=descFont, bg='#dfe1e6', anchor='nw')
        self.help_description.grid(column=0, row=1, sticky=(tk.N, tk.S, tk.E, tk.W), columnspan=4)


    # Insert Node for First Frame
    def insert_node(self, parent, key, value):
        '''
        Insert a node into the treeview. The node is inserted as a child of the parent node. The node is created with the key and value and is assigned data type.

        :param parent: The parent node.
        :param key: The key of the node.
        :param value: The value of the node.
    
        '''

        if value is None:
            node = self.tree.insert(parent, 'end', text=key,values=str(key), open=False)
            return            
        if type(value) in (list, tuple):
            node = self.tree.insert(parent, 'end', text=str(key + ' : [Array]'),values=str(key), open=False)
            for index, item in enumerate(value[:self.MAX_N_SHOW_ITEM]):
                self.insert_node(node, str('[' + str(index) + ']'), item)
        elif isinstance(value, dict):
            node = self.tree.insert(parent, 'end', text=str(key + ' : [Object]'),values=str(key), open=False)
            for key, item in value.items():
                self.insert_node(node, key, item)
        else:
            self.tree.insert(parent, 'end', text=str(key + ' : ' + str(value)),values=str(key), open=False)
    
    # Insert Node for secondary Frame
    def insert_node_for_second_frame(self, parent, key, value, trim_value):
        '''
        Insert a node into the treeview of second frame (entity frame). The node is inserted as a child of the parent node. The node is created with the key and value.

        :param parent: The parent node.
        :param key: The key of the node.
        :param value: The value of the node.
        '''

        node = self.tree.insert(parent, 'end', text=key, open=False)
        style = ttk.Style()
        style.configure("Treeview")
        if value is None:
            return
        if type(value) in (list, tuple):
            for index, item in enumerate(value):
                item = item.replace('"',"")
                try:
                    # Text with more than 64 characters are colored in red
                    if len(item) > 64 and trim_value == True:
                        self.tree.insert(node, 'end', text=item, open=False, tags = ('red_fg',))
                        self.tree.tag_configure('red_fg',foreground="#E21717")
                    else:
                        self.tree.insert(node, 'end', text=item, open=False)
                except NameError:
                    self.tree.insert(node, 'end', text=item, open=False)
        else:
            value = value.replace('"', '')
            try:
                if len(value) > 64 and trim_value == True:
                    self.tree.insert(node, 'end', text=value, open=False,tags = ('red_fg',))
                    self.tree.tag_configure('red_fg',foreground="#E21717")
                else:
                    self.tree.insert(node, 'end', text=value, open=False)
            except NameError:
                self.tree.insert(node, 'end', text=value, open=False)

        style.map('Treeview', background=[('selected', '#0178d6')], foreground=[('selected', 'white')])

    def click_item(self, event=None):
        item_id = self.tree.selection()
        item_text = self.tree.item(item_id, 'text')

    # Finish Button Action
    def sendFinalEntities(self):
        '''
        Finish button action. It will send the final entities to the parser (Browse_File_Parser.py).
        '''
        root.destroy()
    
    def editNodeName(self,data,originalValue,parentName, newValue):
        '''
        Edit node and entity name from the entity frame. It will update the treeview and the entity dictionary.

        :param data: The data of the node.
        :param originalValue: The original value of the node.
        :param parentName: The parent name of the node.
        :param newValue: The new value of the node.

        '''

        if parentName == None:
            for i in data:
                for k,v in i.items():
                    if k == originalValue:
                        i[newValue] = i.pop(originalValue)
                        break
        else:
            for i in data:
                for k,v in i.items():
                    if k == parentName:
                        for j in v["Columns"]:
                            if j == originalValue:
                                v["Columns"].remove(j)
                                v["Columns"].append(newValue)
                                v["ChangedNames"].append({ "OldName": originalValue, "NewName": newValue })

    def editButtonEvent(self):
        '''
        Edit button action. It will show the edit box and update the treeview and the entity dictionary. 
        IMP: This function will change the name of the node and the entity only in UI and not in META-DATA. To change the name in META-DATA, use the editNodeName function.
        '''

        global entitiesObjects
        itemiid = self.secondFrameTree.focus()

        if self.parser == 'JSON':
            filename = f"{self.fileName}.json"
        else:
            filename = f"{self.fileName}.xml"

        if self.secondFrameTree.item(itemiid, 'text') == filename:
            # Warning Message
            messagebox.showwarning("Warning", "Main file name cannot be changed.")
            return

        if self.secondFrameTree.parent(itemiid) != '':
            parentName = self.secondFrameTree.item(self.secondFrameTree.parent(itemiid), 'text')
            selectedColumnName = self.secondFrameTree.item(itemiid, 'text')
            newValue = simpledialog.askstring(title="Rename Entity",prompt="Enter new entity value: ")
            self.editNodeName(entitiesObjects,selectedColumnName,parentName,newValue)
            self.createTreeInSecondaryFrame(self.getColumnNamesFromDict(entitiesObjects))
        else:
            selectedColumnName = self.secondFrameTree.item(itemiid, 'text')
            newValue = simpledialog.askstring(title="Rename Entity",prompt="Enter new entity value: ")
            self.editNodeName(entitiesObjects,selectedColumnName,None,newValue)
            self.createTreeInSecondaryFrame(self.getColumnNamesFromDict(entitiesObjects))

    # Remove Button Action
    def removeNode(self):
        '''
        Remove button action. It will remove the selected node from the treeview and the entity dictionary.
        '''


        global entitiesObjects
        selectedNodeIID = self.secondFrameTree.selection()

        if self.parser == 'JSON':
            filename = f"{self.fileName}.json"
        else:
            filename = f"{self.fileName}.xml"

        for selectedItemIID in selectedNodeIID:
            selectedText = str(self.secondFrameTree.item(selectedItemIID, 'text'))
            selectedText = re.sub(r'\.(\d+)\.', r'."\1".', selectedText)
            selectedText = re.sub(r'\.(\d+)', r'."\1"', selectedText)
            if self.secondFrameTree.parent(selectedItemIID) != '':
                parentName = self.secondFrameTree.item(self.secondFrameTree.parent(selectedItemIID), 'text')
            elif filename == selectedText:
                for i in entitiesObjects:
                    for k,v in i.items():
                        if k == filename:
                            i.pop(k)
                            break
                self.secondFrameTree.delete(selectedItemIID)
                self.ProfileMainFile = False
                continue
            else:
                parentName = None

            if parentName == None:
                for i in entitiesObjects:
                    for k,v in i.items():
                        if k == selectedText:
                            i.pop(k)
                            break
            else:
                for i in entitiesObjects:
                    for k,v in i.items():
                        if k == parentName:
                            for j in v["Columns"]:
                                if j == selectedText:
                                    v["Columns"].remove(j)
                                    break
            self.secondFrameTree.delete(selectedItemIID)
            

    def createTreeInSecondaryFrame(self,objectList, mainObject={}):
        '''
        Initialize the treeview in the secondary frame.

        :param objectList: The list of the entities.

        '''

        global fileListFrame
        fileListFrame = JSONTreeFrame(self, second_json_tree_data=objectList, mainObject=mainObject)
        self.secondFrameTree = fileListFrame.tree
        self.secondFrameTree.tag_configure('TkTextFont', font=self.customFont)
        fileListFrame.heading('#0', text='Selected Entities',anchor=tk.W)
        fileListFrame.grid(column=1, row=0, sticky=(tk.N, tk.S, tk.E, tk.W))
        fileListFrame.grid_columnconfigure(0, minsize=350, weight=1)
        fileListFrame.column("#0", minwidth=200, width=1000)
        self.button_List()
        fileListFrame.horizontalScrollbar()

        # Update Help Box based on cursor position.
        self.secondFrameTree.bind("<Motion>", lambda event: self.helpDesc(event=event))

        
    def flattenJSON(self,dictionary, parent_key=False, separator='.'):
        '''
        Flatten the JSON file and add '.' seperator between the keys. Used to create nodes in the treeview for second frame.

        :param dictionary: The dictionary of the JSON file.
        :param parent_key: The parent key of the dictionary.
        :param separator: The seperator between the keys.

        '''

        items = []
        if isinstance(dictionary, list):
            dictt = dictionary
            # Check if the list is not a dict or list and convert to a dictionary with index as key
            if not isinstance(dictionary[0], collectionsAbc.Mapping):
                dictt = {str(i): v for i, v in enumerate(dictionary)}
                dictt = dictt.items()
                return "Pure List"

        elif isinstance(dictionary, dict):
            dictt = dictionary.items()

        for key, value in dictt:
            new_key = str(parent_key) + separator + key if parent_key else key
            if isinstance(value, collectionsAbc.MutableMapping):
                if not value.items():
                    items.append((new_key,None))
                else:
                    items.extend(self.flattenJSON(value, new_key, separator).items())
            elif isinstance(value, list):
                if len(value):
                    for k, v in enumerate(value):
                        items.extend(self.flattenJSON({str(k): v}, new_key).items())
                else:
                    items.append((new_key,None))
            else:
                items.append((new_key, value))
        return dict(items)

    def findAndReplace(self,string):
        '''
        Regex function to remove numbers between brackets([~]).

        :param string: The string to be replaced.

        :return: The replaced string.
        
        '''

        regex1 = r"\.[0-9]+\."
        regex2 = r"\.[0-9]+"
        if re.findall(regex1,string) != []:
            newString = re.sub(r"\.[0-9]+", "[]", string)
            return newString
        elif re.findall(regex2,string) != []:
            newString = re.sub(r"\.[0-9]+", "[]", string)
            return newString
        else:
            return string

    def removeBracketsForXML(self, string):
        '''
        Regex function to remove brackets([~]) from the string.

        :param string: The string to be replaced.

        :return: The replaced string.

        '''

        regex = r"\[(.*?)\]"
        subst = "[]"
        result = re.sub(regex, subst, string, 0, re.MULTILINE)
        result = result.replace('"', "")
        return result

    def getColumnNamesFromDict(self, dictionary):
        '''
        Get the column names from the entity meta data. These column names will be used to display the nodes in the secondary frame.

        :param dictionary: The meta data dictionary.

        :return: The list of column names.

        '''

        columnNames = []
        for i in dictionary:
            for k,v in i.items():
                columnNames.append({k:v["Columns"]})
        return columnNames
    
    def addToSelectionList(self):
        '''
        Main function to add the selected node to the selection list.
        '''

        # This function has 2 stages. At first it assumes that a entity is already created even if it is not. Then it first tries to add selected nodes from first frame to that entity. If the entity is missing then a exception is raised and as part of exception handling it will create a new entity and add the selected nodes to that entity. If the entity is already created then it will add the selected nodes to that entity.

        selectedNodesIID = self.tree.selection()
        for itemIID in selectedNodesIID:

            # At this point we have itemIID which is not root node, and probably has many layers of parent elements
            if self.tree.item(itemIID, 'values') not in parent:
                
                if len(self.tree.item(itemIID, 'values')) > 1:
                    selectedNodeText = " ".join(self.tree.item(itemIID, 'values'))
                else:
                    selectedNodeText = str(self.tree.item(itemIID, 'values')[0])

                currentID = itemIID
                parentName = ''
                while True:
                    if self.tree.parent(currentID) != '':
                        if str(self.tree.item(self.tree.parent(currentID), 'values')[0])[0] == '[':
                            pName = str(self.tree.item(self.tree.parent(currentID), 'values')[0]) + '.'
                        else:
                            pName = self.tree.item(self.tree.parent(currentID), 'values')[0] + '.'
                        
                        if parentName != '':
                            if parentName[0] == '[':
                                pName = pName[:-1]
                        
                        parentName = pName + parentName
                        if parentName != '':
                            if parentName[-1] == '.':
                                parentName = parentName[:-1]
                        currentID = self.tree.parent(currentID)
                        continue
                    else:
                        break

                if selectedNodeText[0] == '[':
                    pathOfSelectedNode = parentName + selectedNodeText
                elif parentName == '':
                    pathOfSelectedNode = selectedNodeText
                else:
                    pathOfSelectedNode = parentName + '.' + selectedNodeText
                
                pathOfSelectedNode = re.sub(r"\[(.*?)\]", "[*]", pathOfSelectedNode, 0, re.MULTILINE)
                jsonPathSplit = pathOfSelectedNode.split('.')
                jsonPathSplitList = []
                for pathString in jsonPathSplit:
                    if ":" in pathString or "#" in pathString or "@" in pathString:
                        if pathString[-3:] == "[*]":
                            jsonPathSplitList.append(f'"{pathString[:-3]}"[*]')
                        else:
                            jsonPathSplitList.append(f'"{pathString}"')
                    elif " " in pathString:
                        jsonPathSplitList.append(f'"{pathString}"')
                    else:
                        jsonPathSplitList.append(pathString)

                pathOfSelectedNode = '.'.join(jsonPathSplitList)    

                pathOfSelectedNode = re.sub(r'\.(\d+)\.', r'."\1".', pathOfSelectedNode)
                pathOfSelectedNode = re.sub(r'\.(\d+)', r'."\1"', pathOfSelectedNode)
                jsonpathExpression = parse(pathOfSelectedNode)
                jsonFound = jsonpathExpression.find(self.data)

                result = jsonFound[0].value
                pathOfSelectedNode = re.sub(r"\[(.*?)\]", "[]", pathOfSelectedNode, 0, re.MULTILINE)

                global finalPath
                if isinstance(result, dict):
                    result = self.flattenJSON(result)
                    allKeys = list(result.keys())
                    allKeys = [self.findAndReplace(x) for x in allKeys]
                    finalPath = [str(pathOfSelectedNode)+'.'+ str(key) for key in allKeys]
                elif isinstance(result, list):
                    result = jsonFound[0].value[0]
                    result = self.flattenJSON(result)
                    if result == "Pure List":
                        result = jsonFound[0].value
                        finalPath = [str(pathOfSelectedNode) + '[]' + '[]']
                    else:
                        allKeys = result.keys()
                        allKeys = [self.findAndReplace(x) for x in allKeys]
                        finalPath = [str(pathOfSelectedNode) + '[]' + '.' + str(key) for key in allKeys]
                else:
                    finalPath.append(pathOfSelectedNode)
        
        # Important Note: Passing a list via append method or fixing it as value to a dict key, actually only passes a reference to dict object about the list. If the original list is cleared then the list mentioned in the dict will be cleared as well. Therefore, in the dict below, a copy of original list is passed in the dict object using columnNames[:]. This protects the passed in list from being cleared when the original list is cleared.
        
        # Get selected entities from 2nd tree
        try:
            selectedSecondTree = self.secondFrameTree.selection()[0]

            # Get parent name if any node is selected
            if self.secondFrameTree.parent(selectedSecondTree):
                selectedSecondTree = self.secondFrameTree.item(self.secondFrameTree.parent(selectedSecondTree), 'text')

            # Get node name if parent is not there
            elif self.secondFrameTree.parent(selectedSecondTree) == '':
                selectedSecondTree = self.secondFrameTree.item(selectedSecondTree, 'text')

            for index,i in enumerate(entitiesObjects):
                for k,v in i.items():
                    if k == selectedSecondTree:
                        if self.parser == 'XML':
                            pushList = [self.removeBracketsForXML(x) for x in finalPath[:]]
                        else:
                            pushList = finalPath[:]
                        
                        entitiesObjects[index][k]["Columns"] = list(set(entitiesObjects[index][k]["Columns"] + pushList))

            finalPath.clear()
            self.createTreeInSecondaryFrame(self.getColumnNamesFromDict(entitiesObjects), entitiesObjects)
        
        # If no entity is created then create a new entity and add the selected nodes to that entity
        except AttributeError:
            if self.parser == 'XML':
                pushList = [self.removeBracketsForXML(x) for x in finalPath[:]]
                pushList = list(set(pushList))
            else:
                pushList = list(set(finalPath[:]))

            selectedNodes = {
                f'Entity_{len(entitiesObjects)}_{self.fileName}': {
                    "Columns":pushList,
                    "ChangedNames":[],
                    "Trim": self.trim_value.get(),
                }
            }
            entitiesObjects.append(selectedNodes)
            finalPath.clear()
            self.createTreeInSecondaryFrame(self.getColumnNamesFromDict(entitiesObjects), entitiesObjects)
        
        # If no entity is created then create a new entity and add the selected nodes to that entity
        except IndexError:
            if self.parser == 'XML':
                pushList = [self.removeBracketsForXML(x) for x in finalPath[:]]
                pushList = list(set(pushList))
            else:
                pushList = list(set(finalPath[:]))

            selectedNodes = {
                f'Entity_{len(entitiesObjects)}_{self.fileName}': {
                    "Columns":pushList,
                    "ChangedNames":[],
                    "Trim": self.trim_value.get(),
                }
            }
            entitiesObjects.append(selectedNodes)
            finalPath.clear()
            self.createTreeInSecondaryFrame(self.getColumnNamesFromDict(entitiesObjects), entitiesObjects)

    def helpDesc(self, title="Create or Add Entities", desc="Select a node from the treeview and press 'Add' to add it to the list of entities.",event=None):
        '''
        Help description for the user.

        :param title: Title of the help window.
        :param desc: Description of the help window.
        :param event: Event object (not used).
        
        '''

        self.help_title.set(title)
        self.help_desc.set(desc)
        if event != None:
            curItem = event.widget.identify_row(event.y)
            if event.widget.item(curItem, 'tag') == ('red_fg',):
                self.help_title.set("Node has more than 64 characters")
                self.help_desc.set("Please rename the node to a shorter name or the name will be trimmed to 64 characters while parsing.")

    def button_List(self):
        '''
        Method to create the list of buttons. Buttons created are 'Add', 'Remove', 'Edit' and 'Finish'.
        
        '''

        self.bottom_frame = tk.Frame(self)
        self.bottom_frame.grid(column=1, row=2, sticky=(tk.N, tk.S, tk.E, tk.W))

        self.removeBtn = tk.Button(self.bottom_frame, text="Remove", height = 1, width = 7,command=self.removeNode,font=self.customFont)
        self.removeBtn.pack(side=tk.LEFT, padx=10, pady=10)

        self.removeBtn.bind("<Enter>", lambda event: self.helpDesc("Remove Button", "Remove selected node or entity from the 'Selected Entities' list."))
        self.removeBtn.bind("<Leave>", lambda event: self.helpDesc())

        self.editBtn = tk.Button(self.bottom_frame, text="Edit", height = 1, width = 7,command=self.editButtonEvent,font=self.customFont)
        self.editBtn.pack(side=tk.LEFT, padx=10, pady=10)
        self.editBtn.bind("<Enter>", lambda event: self.helpDesc("Edit Button", "Edit the name of selected entity or node from the 'Selected Entities' list."))
        self.editBtn.bind("<Leave>", lambda event: self.helpDesc())

        self.finishBtn = tk.Button(self.bottom_frame, text="Finish", height = 1, width = 7,command=self.sendFinalEntities,font=self.customFont)
        self.finishBtn.pack(side=tk.LEFT, padx=10, pady=10)
        self.finishBtn.bind("<Enter>", lambda event: self.helpDesc("Finish Button", "Submit the list of entities to the parser."))
        self.finishBtn.bind("<Leave>", lambda event: self.helpDesc())

    def horizontalScrollbar(self):      
        self.hsb = ttk.Scrollbar(self.tree, orient=tk.HORIZONTAL,command=self.tree.xview)
        self.tree.configure(xscrollcommand=self.hsb.set)
        self.hsb.pack(side=tk.BOTTOM, fill='x')
        self.columnconfigure(0, weight=1)
        self.rowconfigure(0, weight=1)
    
    def addMainFileAsEntity(self):
        '''
        Option to add the main file as an entity. This is done by creating a new entity and adding the main file name as part of the entity.

        '''

        if self.ProfileMainFile == True:
            # Show warning message
            messagebox.showwarning("Warning", "Main file is already added as an entity.")
            return
        
        if self.parser == 'JSON':
            filename = f'{self.fileName}.json'
        else:
            filename = f'{self.fileName}.xml'

        self.mainFile = {
            filename: {
                'ProfileMainFile': True,
                "Columns": [],
                "ChangedNames":[]
            }
        }
        entitiesObjects.append(self.mainFile)
        self.createTreeInSecondaryFrame(self.getColumnNamesFromDict(entitiesObjects))
        self.ProfileMainFile = True

    # Small Widgets used in the GUI and Search Widgets
    # ==============================================
    def expand_all(self, event=None):
        for item in self.get_all_children(self.tree):
            self.tree.item(item, open=True)

    def collapse_all(self, event=None):
        for item in self.get_all_children(self.tree):
            self.tree.item(item, open=False)
    
    def trim_to_64_characters(self):
        self.trim_value.set(not self.trim_value.get())
        global global_trim_value
        global_trim_value = self.trim_value.get()

    def find_window(self, event=None):
        self.search_box = tk.Entry(self.master)
        self.search_box.pack()
        self.search_box.bind('<Key>', self.find_word)

    def find_word(self, event=None):
        search_text = self.search_box.get()
        self.find(search_text)

    def find(self, search_text):
        if not search_text:
            return
        self.collapse_all(None)
        for item_id in self.get_all_children(self.tree):
            item_text = self.tree.item(item_id, 'text')
            item_text = str(item_text)
            if search_text.lower() in item_text.lower():
                self.tree.see(item_id)

    def get_all_children(self, tree, item=""):
        children = tree.get_children(item)
        for child in children:
            children += self.get_all_children(tree, child)
        return children

    def select_listbox_item(self, event):
        w = event.widget
        index = int(w.curselection()[0])
        value = w.get(index)
        self.set_table_data_from_json_path(value)
        self.sub_win.destroy()  # close window

    # Main entry method to add JSON data in Treeview
    def set_table_data_from_json(self, file_data):
        assert type(file_data) in (list, dict)
        self.delete_all_nodes()
        self.insert_nodes(file_data)

    # Main entry method to add JSON data in secondary frame Treeview
    def set_table_data_for_second_frame(self, second_json_tree_data, mainObject):
        assert type(second_json_tree_data) in (list, dict)
        self.delete_all_nodes()
        self.insert_nodes_in_second_frame(second_json_tree_data, mainObject)

    def set_table_data_from_json_path(self, file_path):
        self.data = self.load_json_data(file_path, self.parser, self.encoding)
        self.set_table_data_from_json(self.data)
        fileName = file_path.split('\\')[-1]
        self.fileName = fileName.split('.')[0]

    def delete_all_nodes(self):
        for i in self.tree.get_children():
            self.tree.delete(i)

    def insert_nodes(self, data):
        parent = ""
        if isinstance(data, list):
            for index, value in enumerate(data):
                self.insert_node(parent, str('[' + str(index) + ']'), value)
        elif isinstance(data, dict):
            for (key, value) in data.items():
                self.insert_node(parent, key, value)
    
    def insert_nodes_in_second_frame(self, data, mainObject):
        for i in data:
            if isinstance(i, dict):
                for key,value in i.items():
                    try:
                        # Check if key exist in main object array
                        keyObject = [x for x in mainObject if x.get(key) is not None][0]
                        if keyObject.get(key) is not None:
                            trimValue = keyObject.get(key).get('Trim')
                    except:
                        trimValue = global_trim_value
                    self.insert_node_for_second_frame(parent, key, value, trimValue)

    @staticmethod
    def get_unique_list(seq):
        seen = []
        return [x for x in seq if x not in seen and not seen.append(x)]

    @staticmethod
    def load_json_data(file_path, parser, encoding):
        try:
            with open(file_path, encoding=encoding) as f:
                if parser == 'JSON':
                    return json.load(f)
                else:
                    xmlJson = xmltodict.parse(f.read())
                    file_data = json.dumps(xmlJson)
                    file_data = json.loads(file_data)
                    return file_data
        except UnicodeDecodeError:
            with open(file_path, encoding=encoding) as f:
                if parser == 'JSON':
                    return json.load(f)
                else:
                    xmlJson = xmltodict.parse(f.read())
                    file_data = json.dumps(xmlJson)
                    file_data = json.loads(file_data)
                    return file_data
    # ==============================================

# Main funtion to initialize the GUI
def view_data(maxDepth,parser,iconPath,encoding,json_file=None, file_data=None, initial_dir=None, columnNameList=None):
    global root
    root = tk.Tk()
    if parser == 'JSON':
        root.title('JSON Viewer Parser')
    else:
        root.title('XML Viewer Parser')
    root.geometry("750x550")
    root.iconbitmap(iconPath)
    menubar = tk.Menu(root)

    if json_file:
        app = JSONTreeFrame(root,encoding,maxDepth,parser=parser, file_path=json_file, initial_dir=initial_dir)
    elif file_data:
        app = JSONTreeFrame(root,encoding,maxDepth,parser=parser, file_data=file_data)
    else:
        app = JSONTreeFrame(root,encoding,maxDepth, parser)

    tool_menu = tk.Menu(menubar, tearoff=0)
    tool_menu.add_command(label="Expand all",accelerator='Ctrl+E', command=app.expand_all)
    tool_menu.add_command(label="Collapse all",accelerator='Ctrl+L', command=app.collapse_all)
    tool_menu.add_command(label="Add file as entity", accelerator='Ctrl+M', command=lambda: app.addMainFileAsEntity())
    defaultVar = tk.IntVar(value=1)
    tool_menu.add_checkbutton(label="Trim to 64 characters", command=lambda: app.trim_to_64_characters(), variable=defaultVar)
    menubar.add_cascade(label="Tools", menu=tool_menu)

    fileName = json_file.split('\\')[-1]

    app.heading('#0', text=fileName,anchor=tk.W)

    app.grid(column=0, row=0, sticky=(tk.N, tk.S, tk.E, tk.W))
    root.columnconfigure(0, weight=4)
    root.rowconfigure(0, weight=1)
    app.init_search_box()
    app.helpBox()
    root.config(menu=menubar)
    root.bind_all("<Control-e>", lambda e: app.expand_all(event=e))
    root.bind_all("<Control-l>", lambda e: app.collapse_all(event=e))
    root.bind_all("<Control-m>", lambda e: app.addMainFileAsEntity())
    root.mainloop()

def jsonView(filePath, depth, parser, iconPath, encoding):
    entitiesObjects.clear()
    view_data(depth,parser,iconPath,encoding,json_file=filePath)
    return entitiesObjects
