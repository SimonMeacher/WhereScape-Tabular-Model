# --    (c) WhereScape Inc 2020. WhereScape Inc permits you to copy this module solely for use with the RED software, and to modify this module            -- #
# --    for the purposes of using that modified module with the RED software, but does not permit copying or modification for any other purpose.           -- #
# --                                                                                                                                                       -- #
#=====================================================================================================
# Module Name      :    WslCloudFileBrowser
# DBMS Name        :    Generic for all databases
# Description      :    Generic python module used by Browse_File_Parser.py
#                       The Module contains functions to generate GUI the display files on clouds like
#                       Amazon S3,Azure Data Lake Storage Gen2,Google Cloud
# Author           :    Wherescape Inc
#======================================================================================================
# Notes / History
# 1.0.0   2022-02-16   First Version
#======================================================================================================

import os
import tkinter as tk
from tkinter import StringVar, ttk
from tkinter import messagebox
import sys
from PIL import Image, ImageTk
import re
import tkinter.font as tkFont
sys.path.append(os.environ.get('WSL_WORKDIR',''))

# Amazon S3
try:
    import boto3
    amazonModule = True
except ImportError:
    amazonModule = False
    pass

# Google Cloud Storage
try:
    from google.cloud import storage
    googleModule = True
except ImportError:
    googleModule = False
    pass


# Azure Data Lake Gen2
try:
    from azure.storage.filedatalake import DataLakeServiceClient
    azureModule = True
except ImportError:
    azureModule = False
    pass


# Common function to separate the file name, file extension and file size
# This function is used by all the file browsers (S3, GCP, AZ)
def fileProcessing(fileDataObjects, prefix):
    """
    Function to separate the file name, file extension and file size.

    Parameters
    ----------
    fileDataObjects : list
        List of file objects returned by the file browser.
    prefix : str
        Prefix of the file browser.
    
    Returns
    -------
    fileData : list
        List of file objects with file name, file extension and file size.
        
    """

    fileData = []
    fileList = []

    for obj in fileDataObjects:
        key = obj['key']
        prefixLen = len(prefix)
        key = key[prefixLen:]
        firstLevelKey = key.split('/')[0]

        if firstLevelKey not in fileList:
            if firstLevelKey in ['','\n','\r\n']:
                continue
            
            firstLevelKey = firstLevelKey.replace('//','/')
            firstLevelKey = firstLevelKey.replace('\n','')
            if ":\\" in firstLevelKey:
                ref = re.search(r":\\", firstLevelKey)
                span = ref.span()
                start = firstLevelKey[:span[1]]
                end = firstLevelKey[span[1]:]
                end = end.replace('\\','/')
                firstLevelKey = start + end
            else:
                firstLevelKey = firstLevelKey.replace('\\','/')

            firstLevelKey = firstLevelKey.split('/')[0]
            if firstLevelKey in fileList:
                continue

            if "." not in firstLevelKey:
                extension = 'Folder'
                fileSize = 0
            else:
                extension = firstLevelKey.split('.')[-1]
                fileSize = obj['size']


            fileData.append({'filePath':firstLevelKey,'fileSize':fileSize, 'fileExt':extension})
            fileList.append(firstLevelKey)

    return fileData


# Create a class to handle the bucket
class S3FileBrowser():
    def __init__(self,access_key,secret_key,region_name,bucket_name):
        """
        Initialize the S3FileBrowser class

        :param access_key: AWS access key
        :param secret_key: AWS secret key
        :param region_name: AWS region name
        :param bucket_name: S3 bucket name

        """

        if amazonModule == False:
            print(-2)
            print("Error: boto3 module not found")

        self.access_key = access_key
        self.secret_key = secret_key
        self.region_name = region_name
        self.bucket_name = bucket_name

        # Create an S3 Resource Instance
        try:
            self.resource = boto3.resource(
                's3',
                aws_access_key_id = self.access_key,
                aws_secret_access_key = self.secret_key,
                region_name = self.region_name
            )
        except Exception as e:
            print(-2)
            print("Error in creating S3 resource: "+ str(e))

        # Create an S3 Client Instance
        try:
            self.client = boto3.client(
                's3',
                aws_access_key_id = self.access_key,
                aws_secret_access_key = self.secret_key,
                region_name = self.region_name
            )
        except Exception as e:
            print(-2)
            print("Error in creating S3 client: "+ str(e))

    def listBuckets(self):
        """
        Lists all the buckets in the current account

        :return: List of buckets
        
        """

        try:
            buckets = []
            response = self.client.list_buckets()
            for bucket in response['Buckets']:
                buckets.append(bucket['Name']) 

            return buckets

        except Exception as e:
            print(-2)
            print("No S3 buckets found: "+ str(e))

        
    def checkIfBucketExists(self):
        """
        Checks if the bucket exists in the current account

        :return: True if the bucket exists, False otherwise

        """

        try:
            # Call S3 to list current buckets
            response = self.client.list_buckets()
            for bucket in response['Buckets']:
                if bucket['Name'] == self.bucket_name:
                    return True
            return False

        except Exception as e:
            print(-2)
            print("Error in checking if S3 bucket exists: "+ str(e))


    def listObjects(self,prefix):
        """
        Lists all the objects in the bucket with the given prefix

        :param prefix: Prefix of the objects to be listed

        :return: List of objects
        
        """

        try:
            # Call S3 to list current buckets
            objects = []
            if prefix == '':
                paginator = self.client.get_paginator('list_objects_v2')
                pages = paginator.paginate(Bucket=self.bucket_name)
            else:
                paginator = self.client.get_paginator('list_objects_v2')
                pages = paginator.paginate(Bucket=self.bucket_name,Prefix=prefix)
            
            for page in pages:
                for obj in page['Contents']:
                    objects.append({'key':obj['Key'],'size':obj['Size']}) 
            
            return objects

        except Exception as e:
            print(-2)
            print("Error in listing S3 objects: "+ str(e))

    def getAllObjectsFromBucket(self):
        """
        Lists all the objects in the bucket

        :return: List of objects

        """

        try:
            objects = []
            bucketClient = self.resource.Bucket(self.bucket_name)
            for s3_file in bucketClient.objects.all():
                objects.append({'key':s3_file.key,'size':s3_file.size})
            
            return objects

        except Exception as e:
            print(-2)
            print("Error in listing S3 objects: "+ str(e))

    def downloadObject(self, objectName):
        """
        Downloads the object from the bucket to the local directory with the same name.
        Local Directory = WSL_WORKDIR.

        :param objectName: Name of the object to be downloaded

        :return: Path of the downloaded object

        """

        try:
            fileName = objectName.split('/')[-1]
            download_file_path = os.path.join(os.environ.get('WSL_WORKDIR',''), fileName)
            os.makedirs(os.path.dirname(download_file_path), exist_ok=True)
            self.client.download_file(self.bucket_name,objectName, download_file_path)

            return download_file_path
        
        except Exception as e:
            print(-2)
            print("Error in downloading S3 object: "+ str(e))

    def getS3ProcessedFiles(self, prefix):
        """
        Lists all the objects in the bucket with the given prefix.

        :param prefix: Prefix of the objects to be listed

        :return: List of objects with file path, file extension and file size

        """

        try:
            if prefix == '':
                objects = self.getAllObjectsFromBucket()
            else:
                objects = self.listObjects(prefix)

            fileData = fileProcessing(objects, prefix)

            return fileData
        except Exception as e:
            print(-2)
            print("Error in listing processed S3 objects: "+ str(e))

class AZFileBrowser():
    def __init__(self,storage_account_name, storage_account_key, file_system_name):
        """
        Initialize the AZFileBrowser class

        :param storage_account_name: Storage account name
        :param storage_account_key: Storage account key
        :param file_system_name: File system name

        """
        if azureModule == False:
            print(-2)
            print("Error: azure-storage module not found")
        
        self.storage_account_name = storage_account_name
        self.storage_account_key = storage_account_key
        self.file_system_name = file_system_name

        try:
            self.client = DataLakeServiceClient(account_url="{}://{}.dfs.core.windows.net".format(
                "https", self.storage_account_name), credential=self.storage_account_key)
        except Exception as e:
            print(-2)
            print("Error in creating Azure Data Lake Service Client: "+ str(e))

    def listDirectoryContents(self, prefix):
        """
        Lists all the objects in the directory with the given prefix.

        :param prefix: Prefix of the objects to be listed

        :return: List of objects with file path and file size

        """

        try:
            files = []
            file_system_client = self.client.get_file_system_client(file_system=self.file_system_name)
            paths = file_system_client.get_paths(path=prefix)
            for path in paths:
                files.append({'key':path.name,'size': path.content_length})      

            return files

        except Exception as e:
            print(-2)
            print("Error in listing Azure Data Lake directory contents: "+ str(e))
    
    def downloadFile(self, fileName):
        """
        Downloads the file from the directory to the local directory with the same name.\n
        Local Directory = WSL_WORKDIR.

        :param fileName: Name of the file to be downloaded

        :return: Path of the downloaded file

        """

        try:
            local_path = os.path.join(os.environ.get('WSL_WORKDIR',''), fileName.split('/')[-1])
            file_system_client = self.client.get_file_system_client(file_system=self.file_system_name)
            file_dir_path = fileName.split('/')[:-1]
            file_dir_path = '/'.join(file_dir_path) 

            # If file is stored at base level in the file system.
            # file_dir_path should be "/".
            # For Reference, request send by client is:
            # https://adlg2demo2.blob.core.windows.net/adfilesystem/srcdir/cities_AtoK_s.txt
            # <----Client----><----FileSystem----><----FileDir----><----FileName---->
            if fileName[-1] == "/":
                file_dir_path = fileName[:-1]
            elif "/" not in fileName:
                file_dir_path = "/"

            directory_client = file_system_client.get_directory_client(file_dir_path)
            local_file = open(local_path,'wb')
            file_client = directory_client.get_file_client(str(fileName.split('/')[-1]))
            download = file_client.download_file()
            downloaded_bytes = download.readall()
            local_file.write(downloaded_bytes)
            local_file.close()
        
            return local_path

        except Exception as e:
            print(-2)
            print("Error in downloading Azure Data Lake file: "+ str(e))

    def getAzureProcessedFiles(self, prefix):
        """
        Lists all the objects in the directory with the given prefix.

        :param prefix: Prefix of the objects to be listed

        :return: List of objects with file path and file size

        """

        try:
            files = self.listDirectoryContents(prefix)
                
            fileData = fileProcessing(files, prefix)

            return fileData
        except Exception as e:
            print(-2)
            print("Error in listing processed Azure Data Lake directory contents: "+ str(e))

class GCSFileBrowser():
    def __init__(self, projectName, bucketName):
        """
        Initialize the GCSFileBrowser class

        :param projectName: Project name
        :param bucketName: Bucket name
        
        """
        if googleModule == False:
            print(-2)
            print("Error: google-cloud-storage module not found")

        self.projectName = projectName
        self.bucketName = bucketName

        try:
            # https://cloud.google.com/storage/docs/reference/libraries#windows
            self.client = storage.Client(project=self.projectName)

        except Exception as e:
            print(-2)
            print("Error in creating GCS Client: "+ str(e))

    def list_buckets(self):
        """
        Lists all the buckets in the project.

        :return: List of buckets
        
        """
        
        try:
            bucketNames = []
            buckets = self.client.list_buckets()

            for bucket in buckets:
                bucketNames.append(bucket.name)
            
            return bucketNames
        
        except Exception as e:
            print(-2)
            print("Error in listing GCS buckets: "+ str(e))

    def listBlobs(self, prefix):
        """
        Lists all the objects in the bucket with the given prefix.

        :param prefix: Prefix of the objects to be listed.

        :return: List of objects with file path and file size.
        
        """

        try:
            # Note: Client.list_blobs requires at least package version 1.17.0.
            blobList = []
            blobs = self.client.list_blobs(self.bucketName, prefix=prefix)
            for blob in blobs:
                blobList.append({'key':blob.name,'size':blob.size})

            return blobList
        
        except Exception as e:
            print(-2)
            print("Error in listing GCS blobs: "+ str(e))

    def downloadBlob(self, prefix, localFileName):
        """
        Downloads the file from the bucket to the local directory with the same name.\n
        Local Directory = WSL_WORKDIR.

        :param prefix: Prefix of the file to be downloaded
        :param localFileName: Name of the file to be downloaded

        :return: Path of the downloaded file

        """

        try:
            blobs = self.client.list_blobs(self.bucketName, prefix=prefix)
            for blob in blobs:
                blob.download_to_filename(str(os.environ.get('WSL_WORKDIR','')) + localFileName)
            return str(os.environ.get('WSL_WORKDIR','')) + localFileName
        
        except Exception as e:
            print(-2)
            print("Error in downloading GCS blob: "+ str(e))
    
    def getGCPProcessedFiles(self, prefix):
        """
        Lists all the objects in the bucket with the given prefix.

        :param prefix: Prefix of the objects to be listed.

        :return: List of objects with file path and file size.

        """

        try:
            blobs = self.listBlobs(prefix)

            fileData = fileProcessing(blobs, prefix)

            return fileData
        
        except Exception as e:
            print(-2)
            print("Error in listing Processed GCS blobs: "+ str(e))

class FileBrowserUI():
    def __init__(self, redIcon=None):
        self.root = tk.Tk()
        self.root.geometry("800x610")
        self.root.resizable(True,True)
        self.root.grid_columnconfigure(0, weight=1)
        self.root.grid_rowconfigure(0, weight=1)
        self.root.configure(background='#ffffff')
        self.root.bind('<Escape>', lambda e: self.root.destroy())
        self.selectedFiles = []
        self.downloadLocation = []
        self.prefix = ''
        self.currentFilePath = StringVar()
        self.downloadingStatus = StringVar()
        self.downloadingStatus.set("")
        self.currentFilePath.set(self.prefix)
        self.fileTypeList = StringVar()
        self.browseDetails = StringVar()
        self.browseDetails.set("")
        self.customFont = tkFont.Font(family="Tahoma", size=10)
        style = ttk.Style()
        style.configure("Treeview.Heading", font=self.customFont)
        self.redIcon = redIcon

        # Icons
        self.root.iconbitmap(self.redIcon)

        mainIconPath = os.path.join(os.environ.get('WSL_BINDIR',''))

        if os.path.exists(os.path.join(mainIconPath, 'Icons')):
            # Folder Icon
            self.folderIcon = ImageTk.PhotoImage(Image.open(os.path.join(mainIconPath, "Icons\Group.ico")).resize((18,18)))
            
            # File Icon for txt or any other unknown file type
            self.fileIcon = ImageTk.PhotoImage(Image.open(os.path.join(mainIconPath, "Icons\File.ico")).resize((18,18)))

            # CSV Icon
            if os.path.exists(os.path.join(mainIconPath, "Icons\FileCsv.ico"))==True:
                self.csvIcon = ImageTk.PhotoImage(Image.open(os.path.join(mainIconPath, "Icons\File.ico")).resize((18,18)))
            else:
                self.csvIcon = ImageTk.PhotoImage(Image.open(os.path.join(mainIconPath, "Icons\File.ico")).resize((18,18)))

            # Excel Icon
            if os.path.exists(os.path.join(mainIconPath, "Icons\FileExcel.ico"))==True:
                self.excelIcon = ImageTk.PhotoImage(Image.open(os.path.join(mainIconPath, "Icons\FileExcel.ico")).resize((18,18)))
            else:
                self.excelIcon = ImageTk.PhotoImage(Image.open(os.path.join(mainIconPath, "Icons\File.ico")).resize((18,18)))

            # JSON Icon
            if os.path.exists(os.path.join(mainIconPath, "Icons\FileJson.ico"))==True:
                self.jsonIcon = ImageTk.PhotoImage(Image.open(os.path.join(mainIconPath, "Icons\FileJson.ico")).resize((18,18)))
            else:
                self.jsonIcon = ImageTk.PhotoImage(Image.open(os.path.join(mainIconPath, "Icons\File.ico")).resize((18,18)))

            # Parquet Icon
            if os.path.exists(os.path.join(mainIconPath, "Icons\FileParquet.ico"))==True:
                self.parquetIcon = ImageTk.PhotoImage(Image.open(os.path.join(mainIconPath, "Icons\FileParquet.ico")).resize((18,18)))
            else:
                self.parquetIcon = ImageTk.PhotoImage(Image.open(os.path.join(mainIconPath, "Icons\File.ico")).resize((18,18)))

            # XML Icon
            if os.path.exists(os.path.join(mainIconPath, "Icons\FileXml.ico"))==True:
                self.xmlIcon = ImageTk.PhotoImage(Image.open(os.path.join(mainIconPath, "Icons\FileXml.ico")).resize((18,18)))
            else:
                self.xmlIcon = ImageTk.PhotoImage(Image.open(os.path.join(mainIconPath, "Icons\File.ico")).resize((18,18)))

            # Avro Icon
            if os.path.exists(os.path.join(mainIconPath, "Icons\FileAvro.ico"))==True:
                self.avroIcon = ImageTk.PhotoImage(Image.open(os.path.join(mainIconPath, "Icons\FileAvro.ico")).resize((18,18)))
            else:
                self.avroIcon = ImageTk.PhotoImage(Image.open(os.path.join(mainIconPath, "Icons\File.ico")).resize((18,18)))
        else:
            self.folderIcon = None
            self.fileIcon = None
            self.csvIcon = None
            self.excelIcon = None
            self.jsonIcon = None
            self.parquetIcon = None
            self.xmlIcon = None
            self.avroIcon = None

        # Create menu bar
        self.menuBar = tk.Menu(self.root)
        self.root.config(menu=self.menuBar)

        # Create File menu
        self.fileMenu = tk.Menu(self.menuBar, tearoff=0)
        self.menuBar.add_cascade(label="File", menu=self.fileMenu)
        self.fileMenu.add_command(label="Exit", command=self.root.destroy)

        # Create Help menu
        self.helpMenu = tk.Menu(self.menuBar, tearoff=0)
        self.menuBar.add_cascade(label="Help", menu=self.helpMenu)

    def azureConnection(self,storageAccountName, storageAccountKey, fileSystemName):
        self.storageAccountName = storageAccountName
        self.storageAccountKey = storageAccountKey
        self.fileSystemName = fileSystemName
        self.connectionType = "AZ"

        # Create Azure Client in the file browser.
        self.azureClient = AZFileBrowser(storageAccountName,storageAccountKey,fileSystemName)
        self.root.title("Azure Data Lake Gen2 File Browser")

    def gcpConnection(self, projectName, bucketName):
        self.projectName = projectName
        self.bucketName = bucketName
        self.connectionType = "GCP"

        # Create GCP Client in the file browser.
        self.gcpClient = GCSFileBrowser(projectName, bucketName)
        self.root.title("Google Cloud Storage File Browser")

    def s3Connection(self, accessKey,secretKey, regionName, bucketName):
        self.accessKey = accessKey
        self.secretKey = secretKey
        self.regionName = regionName
        self.bucketName = bucketName
        self.connectionType = "S3"

        # Create S3 Client in the file browser.
        self.s3Client = S3FileBrowser(accessKey,secretKey,regionName,bucketName)
        self.root.title("Amazon S3 File Browser")

        
    def addButtonClick(self):
        self.focusedFiles = self.fileBrowserTreeview.selection()

        for file in self.focusedFiles:
            selectedFiles = [filenames[0] for filenames in self.selectedFiles]
            fileType = self.fileBrowserTreeview.item(file)['values'][1]
            fileName = self.fileBrowserTreeview.item(file)['values'][0]

            # if fileType == "Folder":
            #     messagebox.showinfo("Error", "You cannot add folders to the list.")
            #     continue

            if str(self.currentFilePath.get()) + str(fileName) not in selectedFiles:
                self.selectedFileTreeview.insert("", "end", values=self.fileBrowserTreeview.item(file)['values'])
                self.selectedFiles.append((str(self.currentFilePath.get()) + str(fileName), self.fileBrowserTreeview.item(file)['values'][2]))
            else:
                messagebox.showwarning("Warning", f"File {str(self.fileBrowserTreeview.item(file)['values'][0])} already exists")
                
    def removeButtonClick(self):
        self.focusedFiles = self.selectedFileTreeview.selection()

        for file in self.focusedFiles:            
            self.selectedFiles.remove((str(self.currentFilePath.get()) + self.selectedFileTreeview.item(file)['values'][0], self.selectedFileTreeview.item(file)['values'][2]))
            self.selectedFileTreeview.delete(file)

    def refreshButtonClick(self):
        if self.connectionType == "S3":
            self.fileData = self.s3Client.getS3ProcessedFiles(self.currentFilePath.get())
        elif self.connectionType == "GCP":
            self.fileData = self.gcpClient.getGCPProcessedFiles(self.currentFilePath.get())
        elif self.connectionType == "AZ":
            self.fileData = self.azureClient.getAzureProcessedFiles(self.currentFilePath.get())

        self.fileBrowserTreeview.delete(*self.fileBrowserTreeview.get_children())

        filesForLabel = 0
        foldersForLabel = 0
        for file in self.fileData:
            if file['fileExt'].lower() == 'folder':
                icon = self.folderIcon
                foldersForLabel += 1
            elif file['fileExt'].lower() == 'csv':
                icon = self.csvIcon
                filesForLabel += 1
            elif file['fileExt'].lower() == 'xlsx':
                icon = self.excelIcon
                filesForLabel += 1
            elif file['fileExt'].lower() == 'json':
                icon = self.jsonIcon
                filesForLabel += 1
            elif file['fileExt'].lower() == 'parquet':
                icon = self.parquetIcon
                filesForLabel += 1
            elif file['fileExt'].lower() == 'xml':
                icon = self.xmlIcon
                filesForLabel += 1
            elif file['fileExt'].lower() == 'avro':
                icon = self.avroIcon
                filesForLabel += 1
            else:
                icon = self.fileIcon
                filesForLabel += 1
        
            if icon == None:
                self.fileBrowserTreeview.insert("", "end", values=(file['filePath'],file['fileExt'],file['fileSize']))
            else:
                self.fileBrowserTreeview.insert("", "end", values=(file['filePath'],file['fileExt'],file['fileSize']), image=icon)

        self.browseDetails.set(f"Browse Details: {filesForLabel} File and {foldersForLabel} Folder Found")
    
    def treeview_sort_column(self,treeview: ttk.Treeview, col, reverse: bool):
        try:
            data_list = [
                (int(treeview.set(k, col)), k) for k in treeview.get_children("")
            ]
        except Exception:
            data_list = [(treeview.set(k, col), k) for k in treeview.get_children("")]

        data_list.sort(reverse=reverse)

        # rearrange items in sorted positions
        for index, (val, k) in enumerate(data_list):
            treeview.move(k, "", index)

        # reverse sort next time
        treeview.heading(
            column=col,
            text=col,
            command=lambda _col=col: self.treeview_sort_column(
                treeview, _col, not reverse
            ),
        )

    def createFileBrowser(self):
        # Create main frame
        self.mainFrame = tk.Frame(self.root)
        # self.mainFrame.pack(fill=tk.BOTH, expand=True)
        self.mainFrame.grid(row=0, column=0, sticky=tk.NSEW)
        self.mainFrame.grid_columnconfigure(0, weight=1)
        self.mainFrame.grid_rowconfigure(0, weight=1)

        # File Path label Frame
        self.filePathLabelFrame = tk.Frame(self.mainFrame)
        # self.filePathLabelFrame.pack(fill=tk.X, expand=False, ipady=5)
        self.filePathLabelFrame.grid(row=0, column=0, sticky=tk.NSEW)
        self.filePathLabelFrame.grid_columnconfigure(0, weight=1)
        self.filePathLabelFrame.grid_rowconfigure(0, weight=1)

        # File Path label
        self.filePathLabel = tk.Label(self.filePathLabelFrame, text=f"File Path: ./{self.currentFilePath.get()}", font=self.customFont)
        self.filePathLabel.pack(side=tk.LEFT, fill=tk.X, expand=False)

        # path buttons Back
        self.backButton = tk.Button(self.filePathLabelFrame, text="Back", command=self.backButtonClick,width=10, font=self.customFont)
        self.backButton.pack(side=tk.RIGHT, fill=tk.X, expand=False, padx=28, pady=8)

        # Create file browser frame
        self.fileBrowserFrame = tk.Frame(self.mainFrame)
        # self.fileBrowserFrame.pack(fill=tk.BOTH, expand=True)
        self.fileBrowserFrame.grid(row=1, column=0, sticky=tk.NSEW)
        self.fileBrowserFrame.grid_columnconfigure(0, weight=1)
        self.fileBrowserFrame.grid_rowconfigure(0, weight=1)

        # Create file browser treeview
        self.fileBrowserTreeview = ttk.Treeview(self.fileBrowserFrame, columns=('File','Type','Size'), height=10, padding=[-15,0,0,0])
        self.fileBrowserTreeview.tag_configure('TkTextFont', font=self.customFont)

        self.fileBrowserTreeview.heading('File', text='File', anchor=tk.W,)
        self.fileBrowserTreeview.heading('Type', text='Type',)
        self.fileBrowserTreeview.heading('Size', text='Size',)

        columns = ('File','Type','Size')
        for col in columns:
            self.fileBrowserTreeview.heading(col, command=lambda _col=col: \
                     self.treeview_sort_column(self.fileBrowserTreeview, _col, False))

        # self.fileBrowserTreeview.pack(fill=tk.BOTH, expand=True,side=tk.LEFT,padx=8,pady=4)
        self.fileBrowserTreeview.grid(row=0, column=0, sticky=tk.NSEW, padx=8, pady=4)
        self.fileBrowserTreeview.grid_columnconfigure(0, weight=1)
        self.fileBrowserTreeview.grid_rowconfigure(0, weight=1)

        self.fileBrowserTreeview.bind("<Double-1>", self.OnDoubleClick)

        self.fileBrowserTreeview.column('#0', stretch=tk.NO, minwidth=30, width=35, anchor=tk.E)
        self.fileBrowserTreeview.column('File', stretch=tk.NO, minwidth=30, width=240, anchor=tk.W)
        self.fileBrowserTreeview.column('Type', stretch=tk.NO, minwidth=35, width=220, anchor=tk.W)
        self.fileBrowserTreeview.column('Size', stretch=tk.NO, minwidth=35, width=260, anchor=tk.W)

        # Create file browser scrollbar
        self.fileBrowserScrollbar = ttk.Scrollbar(self.fileBrowserFrame, orient=tk.VERTICAL, command=self.fileBrowserTreeview.yview)
        # self.fileBrowserScrollbar.pack(side=tk.RIGHT, fill=tk.Y, expand=False, anchor=tk.SE)
        self.fileBrowserScrollbar.grid(row=0, column=1, sticky=tk.NSEW)
        self.fileBrowserScrollbar.grid_columnconfigure(0, weight=1)
        self.fileBrowserScrollbar.grid_rowconfigure(0, weight=1)

        # Create Buttons frame
        self.buttonsFrame = tk.Frame(self.mainFrame)
        # self.buttonsFrame.pack(fill=tk.BOTH, expand=False)
        self.buttonsFrame.grid(row=2, column=0, sticky=tk.NSEW)
        self.buttonsFrame.grid_columnconfigure(0, weight=1)
        self.buttonsFrame.grid_rowconfigure(0, weight=1)

        # Add button
        self.addButton = tk.Button(self.buttonsFrame, text="Add", command=self.addButtonClick,width=10,font=self.customFont)
        self.addButton.pack(side=tk.LEFT, padx=15, pady=1)

        # Remove button
        self.removeButton = tk.Button(self.buttonsFrame, text="Remove", command=self.removeButtonClick,width=10, font=self.customFont)
        self.removeButton.pack(side=tk.LEFT, padx=15, pady=1)

        # Refresh Button
        self.refreshButton = tk.Button(self.buttonsFrame, text="Refresh", command=self.refreshButtonClick,width=10, font=self.customFont)
        self.refreshButton.pack(side=tk.LEFT, padx=15, pady=1)

        # Create lable at right side
        self.browseDetailsLabel = tk.Label(self.buttonsFrame, textvariable=self.browseDetails, font=self.customFont)
        self.browseDetailsLabel.pack(side=tk.RIGHT, fill=tk.X, expand=False, padx=50, pady=1)

        # Create selected file frame
        self.selectedFileFrame = tk.Frame(self.mainFrame)
        # self.selectedFileFrame.pack(fill=tk.BOTH, expand=False)
        self.selectedFileFrame.grid(row=3, column=0, sticky=tk.NSEW)
        self.selectedFileFrame.grid_columnconfigure(0, weight=1)
        self.selectedFileFrame.grid_rowconfigure(0, weight=1)

        # Create treeview for selected file
        self.selectedFileTreeview = ttk.Treeview(self.selectedFileFrame, columns=('File','Type','Size'), show='headings')
        self.selectedFileTreeview.heading('File', text='File')
        self.selectedFileTreeview.heading('Type', text='Type')
        self.selectedFileTreeview.heading('Size', text='Size')
        self.selectedFileTreeview.tag_configure('TkTextFont', font=self.customFont)

        self.selectedFileTreeview.column('File', stretch=tk.NO, minwidth=30, width=246, anchor=tk.W)
        self.selectedFileTreeview.column('Type', stretch=tk.NO, minwidth=35, width=225, anchor=tk.W)
        self.selectedFileTreeview.column('Size', stretch=tk.NO, minwidth=35, width=269, anchor=tk.W)

        # self.selectedFileTreeview.pack(fill=tk.BOTH, expand=True,side=tk.LEFT,padx=8,pady=4)
        self.selectedFileTreeview.grid(row=0, column=0, sticky=tk.NSEW, padx=8, pady=4)
        self.selectedFileTreeview.grid_columnconfigure(0, weight=1)
        self.selectedFileTreeview.grid_rowconfigure(0, weight=1)

        # Create selected file scrollbar
        self.selectedFileScrollbar = ttk.Scrollbar(self.selectedFileFrame, orient=tk.VERTICAL, command=self.selectedFileTreeview.yview)

        # self.selectedFileScrollbar.pack(side=tk.RIGHT, fill=tk.Y, expand=False, anchor=tk.SE)
        self.selectedFileScrollbar.grid(row=0, column=1, sticky=tk.NSEW)
        self.selectedFileScrollbar.grid_columnconfigure(0, weight=1)
        self.selectedFileScrollbar.grid_rowconfigure(0, weight=1)


        # Ok and Cancel Button Frame
        self.okCancelFrame = tk.Frame(self.mainFrame)
        # self.okCancelFrame.pack(fill=tk.BOTH, expand=False, side=tk.BOTTOM, padx=10)
        self.okCancelFrame.grid(row=4, column=0, sticky=tk.NSEW)
        self.okCancelFrame.grid_columnconfigure(0, weight=1)
        self.okCancelFrame.grid_rowconfigure(0, weight=1)

        # Initialize download Bar
        self.createDownloadBar()

        # Ok button
        self.okButton = tk.Button(self.okCancelFrame, text="OK", command=self.okButtonClick, width=10, height=1, font=self.customFont)
        self.okButton.pack(side=tk.RIGHT, padx=15, pady=5)

        # Cancel button
        self.cancelButton = tk.Button(self.okCancelFrame, text="Cancel", command=self.cancelButtonClick, width=10, height=1, font=self.customFont)
        self.cancelButton.pack(side=tk.RIGHT, padx=15, pady=5)

    def createDownloadBar(self):
        # Download Bar Frame
        # self.downloadBarFrame = tk.Frame(self.mainFrame)
        # self.downloadBarFrame.pack(fill=tk.BOTH, expand=True, side=tk.LEFT)

        # Create inderminate download bar
        self.downloadBar = ttk.Progressbar(self.okCancelFrame, orient=tk.HORIZONTAL, length=200, mode='determinate')
        self.downloadBar.pack(fill=tk.X, expand=False, side=tk.LEFT, padx=8, pady=8)

        # Create download bar label
        self.downloadBarLabel = tk.Label(self.okCancelFrame,textvariable=self.downloadingStatus,font=self.customFont)
        self.downloadBarLabel.pack(fill=tk.X, expand=True, side=tk.LEFT, padx=8, pady=8)


    def OnDoubleClick(self, event):
        try:
            item = self.fileBrowserTreeview.selection()[0]
            clickedItemType = self.fileBrowserTreeview.item(item, "values")[1]
            if clickedItemType != "Folder":
                messagebox.showinfo("Error", "Please select a folder")
                return
            clickedItem = self.fileBrowserTreeview.item(item,"values")[0]
        

            if str(self.currentFilePath.get()) == "":
                prefix = str(clickedItem) + "/"
            else:
                if self.currentFilePath.get()[-1] == "/" and len(self.currentFilePath.get()) == 1:
                    prefix = str(clickedItem)
                elif self.currentFilePath.get()[-1] == "/":
                    prefix = str(self.currentFilePath.get()) + str(clickedItem) + "/"
                else:
                    prefix = str(self.currentFilePath.get()) + "/" + str(clickedItem) + "/"

            if self.connectionType == "S3":
                fileData = self.s3Client.getS3ProcessedFiles(prefix)
            elif self.connectionType == "GCP":
                fileData = self.gcpClient.getGCPProcessedFiles(prefix)
            elif self.connectionType == "AZ":
                fileData = self.azureClient.getAzureProcessedFiles(prefix)

            if fileData != []:
                self.fileBrowserTreeview.delete(*self.fileBrowserTreeview.get_children())
                filesForLabel = 0
                foldersForLabel = 0
                for file in fileData:
                    if file['fileExt'].lower() == 'folder':
                        icon = self.folderIcon
                        foldersForLabel += 1
                    elif file['fileExt'].lower() == 'csv':
                        icon = self.csvIcon
                        filesForLabel += 1
                    elif file['fileExt'].lower() == 'xlsx':
                        icon = self.excelIcon
                        filesForLabel += 1
                    elif file['fileExt'].lower() == 'json':
                        icon = self.jsonIcon
                        filesForLabel += 1
                    elif file['fileExt'].lower() == 'parquet':
                        icon = self.parquetIcon
                        filesForLabel += 1
                    elif file['fileExt'].lower() == 'xml':
                        icon = self.xmlIcon
                        filesForLabel += 1
                    elif file['fileExt'].lower() == 'avro':
                        icon = self.avroIcon
                        filesForLabel += 1
                    else:
                        icon = self.fileIcon
                        filesForLabel += 1

                    if icon == None:
                        self.fileBrowserTreeview.insert("", "end", values=(file['filePath'],file['fileExt'],file['fileSize']))
                    else:
                        self.fileBrowserTreeview.insert("", "end", values=(file['filePath'],file['fileExt'],file['fileSize']), image=icon)

            self.prefix = prefix
            self.currentFilePath.set(prefix)
            self.filePathLabel.config(text=f"File Path: ./{prefix}",font=self.customFont)
            self.browseDetails.set(f"Browse Details: {filesForLabel} File and {foldersForLabel} Folder Found")
        except Exception:
            pass

    def backButtonClick(self):

        self.prefix = self.currentFilePath.get()
        self.prefix = self.prefix.split("/")

        if self.prefix[-1] == "":
            self.prefix = self.prefix[:-2]
        else:
            self.prefix = self.prefix[:-1]

        self.prefix = "/".join(self.prefix)
        
        if self.prefix == "":
            if self.connectionType == "S3":
                self.prefix = ""
            elif self.connectionType == "GCP":
                self.prefix = ""

        if self.prefix != "":
            if self.prefix[-1] != '/':
                self.prefix += '/'

        self.currentFilePath.set(self.prefix)
        self.filePathLabel.config(text=f"File Path: ./{self.prefix}", font=self.customFont)

        if self.connectionType == "S3":
            fileData = self.s3Client.getS3ProcessedFiles(self.prefix)
        elif self.connectionType == "GCP":
            fileData = self.gcpClient.getGCPProcessedFiles(self.prefix)
        elif self.connectionType == "AZ":
            fileData = self.azureClient.getAzureProcessedFiles(self.prefix)

        self.fileBrowserTreeview.delete(*self.fileBrowserTreeview.get_children())
        filesForLabel = 0
        foldersForLabel = 0
        for file in fileData:
            if file['fileExt'].lower() == 'folder':
                icon = self.folderIcon
                foldersForLabel += 1
            elif file['fileExt'].lower() == 'csv':
                icon = self.csvIcon
                filesForLabel += 1
            elif file['fileExt'].lower() == 'xlsx':
                icon = self.excelIcon
                filesForLabel += 1
            elif file['fileExt'].lower() == 'json':
                icon = self.jsonIcon
                filesForLabel += 1
            elif file['fileExt'].lower() == 'parquet':
                icon = self.parquetIcon
                filesForLabel += 1
            elif file['fileExt'].lower() == 'xml':
                icon = self.xmlIcon
                filesForLabel += 1
            elif file['fileExt'].lower() == 'avro':
                icon = self.avroIcon
                filesForLabel += 1
            else:
                icon = self.fileIcon
                filesForLabel += 1

            if icon == None:
                self.fileBrowserTreeview.insert("", "end", values=(file['filePath'],file['fileExt'],file['fileSize']))
            else:
                self.fileBrowserTreeview.insert("", "end", values=(file['filePath'],file['fileExt'],file['fileSize']), image=icon)
        
        self.browseDetails.set(f"Browse Details: {filesForLabel} File and {foldersForLabel} Folder Found")

    def okButtonClick(self):

        if self.connectionType == "S3":
            if len(self.selectedFiles) == 0:
                messagebox.showerror("Error","Please add atleast one file to continue")
                return
            self.downloadBar.maximum = len(self.selectedFiles)
            for index, file in enumerate(self.selectedFiles):
                fileName = file[0]
                self.downloadingStatus.set(f"Downloading {index + 1} of {len(self.selectedFiles)}")
                pr = index + 1
                self.downloadBar['value'] = (pr / len(self.selectedFiles))*100
                self.root.update()
                self.root.update_idletasks()
                location = self.s3Client.downloadObject(fileName)
                self.downloadLocation.append({"localPath":location,"cloudPath":fileName})

            self.downloadBar['value'] = (len(self.selectedFiles) / len(self.selectedFiles))*100
            self.root.destroy()

        elif self.connectionType == "GCP":
            if len(self.selectedFiles) == 0:
                messagebox.showerror("Error","Please add atleast one file to continue")
                return
            self.downloadBar.maximum = len(self.selectedFiles)
            for index, file in enumerate(self.selectedFiles):
                fileName = file[0]
                localFileName = fileName.split("/")[-1]
                self.downloadingStatus.set(f"Downloading {index + 1} of {len(self.selectedFiles)}")
                pr = index + 1
                self.downloadBar['value'] = (pr / len(self.selectedFiles))*100
                self.root.update()
                self.root.update_idletasks()
                location = self.gcpClient.downloadBlob(fileName,localFileName)
                self.downloadLocation.append({'localPath':location,'cloudPath':fileName})

            self.downloadBar['value'] = (len(self.selectedFiles) / len(self.selectedFiles))*100
            self.root.destroy()
        
        elif self.connectionType == "AZ":
            if len(self.selectedFiles) == 0:
                messagebox.showerror("Error","Please add atleast one file to continue")
                return
            self.downloadBar.maximum = len(self.selectedFiles)
            for index, file in enumerate(self.selectedFiles):
                fileName = file[0]
                localFileName = fileName.split("/")[-1]
                self.downloadingStatus.set(f"Downloading {index + 1} of {len(self.selectedFiles)}")
                pr = index + 1
                self.downloadBar['value'] = (pr / len(self.selectedFiles))*100
                self.root.update()
                self.root.update_idletasks()
                location = self.azureClient.downloadFile(fileName)
                self.downloadLocation.append({'localPath':location,'cloudPath':fileName})

            self.downloadBar['value'] = (len(self.selectedFiles) / len(self.selectedFiles))*100
            self.root.destroy()

    def cancelButtonClick(self):
        self.root.destroy()

    def fileBrowserTreeviewClick(self, event):
        self.fileBrowserTreeview.delete(*self.fileBrowserTreeview.get_children())
        for file in self.fileData:
                if file['fileExt'].lower() == 'folder':
                    icon = self.folderIcon
                elif file['fileExt'].lower() == 'csv':
                    icon = self.csvIcon
                elif file['fileExt'].lower() == 'xlsx':
                    icon = self.excelIcon
                elif file['fileExt'].lower() == 'json':
                    icon = self.jsonIcon
                elif file['fileExt'].lower() == 'parquet':
                    icon = self.parquetIcon
                elif file['fileExt'].lower() == 'xml':
                    icon = self.xmlIcon
                elif file['fileExt'].lower() == 'avro':
                    icon = self.avroIcon
                else:
                    icon = self.fileIcon

                if icon == None:
                    self.fileBrowserTreeview.insert("", "end", values=(file['filePath'],file['fileExt'],file['fileSize']))
                else:
                    self.fileBrowserTreeview.insert("", "end", values=(file['filePath'],file['fileExt'],file['fileSize']), image=icon)
                
    def loadFilesIntoBrowser(self):
        if self.connectionType == "S3":
            self.fileData = self.s3Client.getS3ProcessedFiles('')
        elif self.connectionType == "GCP":
            self.fileData = self.gcpClient.getGCPProcessedFiles('')
        elif self.connectionType == "AZ":
            self.fileData = self.azureClient.getAzureProcessedFiles('')

        self.fileBrowserTreeview.delete(*self.fileBrowserTreeview.get_children())
        filesForLabel = 0
        foldersForLabel = 0
        for file in self.fileData:

            if file['fileExt'].lower() == 'folder':
                icon = self.folderIcon
                foldersForLabel += 1
            elif file['fileExt'].lower() == 'csv':
                icon = self.csvIcon
                filesForLabel += 1
            elif file['fileExt'].lower() == 'xlsx':
                icon = self.excelIcon
                filesForLabel += 1
            elif file['fileExt'].lower() == 'json':
                icon = self.jsonIcon
                filesForLabel += 1
            elif file['fileExt'].lower() == 'parquet':
                icon = self.parquetIcon
                filesForLabel += 1
            elif file['fileExt'].lower() == 'xml':
                icon = self.xmlIcon
                filesForLabel += 1
            elif file['fileExt'].lower() == 'avro':
                icon = self.avroIcon
                filesForLabel += 1
            else:
                icon = self.fileIcon
                filesForLabel += 1

            if icon == None:
                self.fileBrowserTreeview.insert("", "end", values=(file['filePath'],file['fileExt'],file['fileSize']))
            else:
                self.fileBrowserTreeview.insert("", "end", values=(file['filePath'],file['fileExt'],file['fileSize']), image=icon)

        self.browseDetails.set(f"Browse Details: {filesForLabel} File and {foldersForLabel} Folder Found")
