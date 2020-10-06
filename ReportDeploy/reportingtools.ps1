param(
      [string] $ArtefactoPath,
	   [string] $Reporte,
      [string] $Datasoruce,
	   [string] $Ruta,
	   [string] $username,
	   [string] $password,
     [string]$UpdateDataSource    
	 )

$ArtefactoPathN = $ArtefactoPath
$ReporteN = $Reporte
$DatasoruceN = $Datasoruce
$RutaN = $Ruta
$usernameN = $username
$passwordN = $password
$UpdateDataSourceN = $UpdateDataSource
function DeployAllItems()
{
    Write-Host "Refreshing reports"
    Write-Host "LocalReportsPath: $LocalReportsPath";
    Write-Host "ReportServerUri: $ReportServerUri";
    Write-Host "DataSource Folder: $DataSourceFolder";
    Write-Host "DataSet Folder: $DataSetFolder";
    Write-Host "Reports Folder: $ReportsFolder";
    Write-Host "DataSource UserName: $DataSourceUserName";
    #Create SSRS Data Source , Dataset and Report Folders

    ##########################################
    #Create DataSource Folder
    Write-Verbose ""

    Write-Host "Entrando a la funcion DeployAllItems"

    try
    {
        $proxy.CreateFolder($DataSourceFolderName, $ReportsParentFolder, $null)
        Write-Verbose "Created new folder: $DataSourceFolderName"
    }
    catch [System.Web.Services.Protocols.SoapException]
    {
        if ($_.Exception.Detail.InnerText -match "[^rsItemAlreadyExists400]")
        {
            Write-Verbose "Folder: $DataSourceFolderName already exists."
        }
        else
        {
            $msg = "Error creating folder: $DataSourceFolderName. Msg: '{0}'" -f $_.Exception.Detail.InnerText
            Write-Error $msg
        }
    }

    ##########################################
    ##########################################
    #Create DataSet Folder
    Write-Verbose ""
    try
    {
        $proxy.CreateFolder($DataSetFolderName, $ReportsParentFolder, $null)
        Write-Verbose "Created new folder: $DataSetFolderName"
    }
    catch [System.Web.Services.Protocols.SoapException]
    {
        if ($_.Exception.Detail.InnerText -match "[^rsItemAlreadyExists400]")
        {
            Write-Verbose "Folder: $DataSetFolderName already exists."
        }
        else
        {
            $msg = "Error creating folder: $DataSetFolderName. Msg: '{0}'" -f $_.Exception.Detail.InnerText
            Write-Error $msg
        }
    }

    ##########################################
    ##########################################
    #Create Report Folder
    Write-Verbose ""
    try
    {
        $proxy.CreateFolder($ReportsFolderName, $ReportsParentFolder, $null)
        Write-Verbose "Created new folder: $ReportsFolderName"
    }
    catch [System.Web.Services.Protocols.SoapException]
    {
        if ($_.Exception.Detail.InnerText -match "[^rsItemAlreadyExists400]")
        {
            Write-Verbose "Folder: $ReportsFolderName already exists."
        }
        else
        {
            $msg = "Error creating folder: $ReportsFolderName. Msg: '{0}'" -f $_.Exception.Detail.InnerText
            Write-Error $msg
        }
    }

    ##########################################
    #Create-SSRS-Report-Folders;
    if($UpdateDataSourceN -eq $true)
	{
	get-childitem $LocalReportsPath *.rds | DeployDataSources;
	}
    get-childitem $LocalReportsPath *.rsd | DeployDataSet;
    get-childitem $LocalReportsPath *.rdl | DeployReports;
}

function DeployDataSources()
{
    Write-Host "Refreshing Datasources." ;
    Write-Host "Entrando a la funcion DeployDataSources"
    #Create SSRS Reports Folder
    try{ 
        $allitems = $proxy.ListChildren("/",$true); 
    }catch{ 
        throw $_.Exception; 
    }

    foreach ($o in $input)
    {
	
        
	
	    
        $dataSourceInfo = $proxy.GetItemType("$DataSourceFolder/$($o.BaseName)");

        Write-Host "Creating DataSource $DataSourceFolder/$($o.BaseName)…";


        [xml]$XmlDataSourceDefinition = Get-Content $o.FullName -Encoding ASCII; 
		
        
        $xmlDataSourceName = $XmlDataSourceDefinition.RptDataSource | where {$_ | get-member ConnectionProperties};
        
        try{ 
            $type = $proxy.GetType().Namespace; 
        }catch{ 
            throw $_.Exception; 
        }
        
        $dataSourceDefinitionType = ($type + '.DataSourceDefinition');
        $dataSourceDefinition = new-object ($dataSourceDefinitionType);
        $dataSourceDefinition.Extension = $xmlDataSourceName.ConnectionProperties.Extension;
         $dataSourceDefinition.ConnectString = $xmlDataSourceName.ConnectionProperties.ConnectString;

        $credentialRetrievalDataType = ($type + '.CredentialRetrievalEnum');
        $credentialRetrieval = new-object ($credentialRetrievalDataType);
        $credentialRetrieval.value__ = 1;# Stored
        #$dataSourceDefinition.WindowsIntegratedSecurity = $true

        #$dataSourceDefinition.CredentialRetrieval = "Integrated";
        #$dataSourceDefinition.WindowsCredentials = $true;
        #$dataSourceDefinition.UserName = $DataSourceUserName;
        #$dataSourceDefinition.Password = $DataSourcePassword;

        try{
            #$xmlDataSourceName
            
            #$DataSourceFolder

            #$dataSourceDefinition

            # [void][System.Console]::ReadKey($FALSE)
            $newDataSource = $proxy.CreateDataSource($xmlDataSourceName.Name,$DataSourceFolder,$true,$dataSourceDefinition,$null);
        }catch{ 
            throw $_.Exception; 
        }

        Write-Host "Done.";
    }

    Write-Host "Finished.";
}

function DeployDataSet()
{
    Write-Host "Refreshing DataSets." ;
    Write-Host "Entrando a la funcion DeployDataSet"

    try{ 
        $allitems = $proxy.ListChildren("/",$true); 
    }catch{ 
        throw $_.Exception; 
    }

    foreach ($o in $input)
    {
        $dataSetInfo = $proxy.GetItemType("$DataSetFolder/$($o.BaseName)");

        Write-Host "Creating DataSet $DataSetFolder/$($o.BaseName)…";

        $stream = [System.IO.File]::ReadAllBytes( $($o.FullName));

        $warnings =@();

        #Create dataset item in the server
        try{ 
            $newDataSet = $proxy.CreateCatalogItem("DataSet","$($o.BaseName)","$DataSetFolder",$true,$stream,$null,[ref]$warnings);
        }catch{ 
            throw $_.Exception; 
        }

        #relink dataset to datasource

        Write-Host "Updating Datasource reference";
        [xml]$XmlDataSetDefinition = Get-Content $o.FullName -Encoding ASCII;
        $xmlDataSourceReference = $XmlDataSetDefinition.SharedDataSet.DataSet | where {$_ | get-member Query};

        try{ 
            $dataSetDataSources = $proxy.GetItemDataSources("$($newDataSet.Path)"); 
        }catch{ 
            throw $_.Exception; 
        }

        foreach ($dataSetDataSource in $dataSetDataSources)
        { 
            #Should only be one!
            $proxyNamespace = $dataSetDataSource.GetType().Namespace;
            $newDataSourceReference = New-Object ("$proxyNamespace.DataSource");
            $newDataSourceReference.Name = $dataSetDataSource.Name;
            $newDataSourceReference.Item = New-Object ("$proxyNamespace.DataSourceReference");
            $newDataSourceReference.Item.Reference = "$DataSourceFolder/$($xmlDataSourceReference.Query.DataSourceReference)";
            $dataSetDataSource.item = $newDataSourceReference.Item;

            try { 
                $proxy.SetItemDataSources("$DataSetFolder/$($o.BaseName)", $newDataSourceReference); 
            }catch{ 
                throw $_.Exception; 
            }
        }

        Write-Host "Done.";
    }

    Write-Host "Finished refreshing DataSets.";
}

function DeployReports()
{
    Write-Host "Refreshing Reports.";
    Write-Host "Entrando a la funcion DeployReports"
	Write-Host "Iniciando.........."

    try{ 
        $allitems = $proxy.ListChildren("/",$true); 
    }catch{ 
        throw $_.Exception; 
    }

    $folderInfo = $proxy.GetItemType("$ReportsFolder");

    $totalReportes = 0;

    # Iterate each report file
    foreach ($o in $input)
    {
        Write-Host "Reporte #$($totalReportes)"
		
	    [xml]$xmlreport = Get-Content $o.FullName -Encoding ASCII; 

		
		
		Write-Host "Updating datasource and datasets on report"
		foreach ($d in $xmlreport.Report.DataSets.DataSet){
			$myname = $d.Query.DataSourceName 
			$Datasourceobj = $xmlreport.Report.DataSources.Datasource | where {$_.Name -eq "$myname"}
		
			
		    if($Datasourceobj.DataSourceReference){
				$Datasourceobj.name = $Datasourceobj.DataSourceReference 
				$d.Query.DataSourceName = $Datasourceobj.DataSourceReference 
			}

		} 
	
	    $xmlreport.Save($o.FullName)

        #Write-Host "Checking report $Folder/$($o.BaseName) exists on server.";
        try{ 
            $reportInfo = $proxy.GetItemType("$ReportsFolder/$($o.BaseName)"); 
        }catch{ 
            throw $_.Exception; 
        }

        Write-Host "Creating report $ReportsFolder/$($o.BaseName)…";

        $stream = [System.IO.File]::ReadAllBytes( $($o.FullName));


        $warnings =@();
        try{
			$newReport = $proxy.CreateCatalogItem("Report","$($o.BaseName)","$ReportsFolder",$true,$stream,$null,[ref]$warnings);

        }catch{
            throw $_.Exception; 
        }

        #relink report to datasource
        Write-Host "Updating Datasource references";

        try{ 
            $reportDataSources = $proxy.GetItemDataSources("$ReportsFolder/$($o.BaseName)"); 
        }catch{ 
            throw $_.Exception; 
        }

        # [void][System.Console]::ReadKey($FALSE)
        #Write-host ($reportDataSources | Format-Table | Out-String) -ForegroundColor Red
        # [void][System.Console]::ReadKey($FALSE)
        

        foreach ($reportDataSource in $reportDataSources)
        {
		   
            $serverDataSourceItem = $allitems | where {($_.TypeName -eq "DataSource") -and ($_.Path -eq "$DataSourceFolder/$($reportDataSource.Name)")};
            if ($serverDataSourceItem){
				$proxyNamespace = $reportDataSource.GetType().Namespace;
				$newDataSourceReference = New-Object ("$proxyNamespace.DataSource");
				$newDataSourceReference.Name = $reportDatasource.Name;
				$newDataSourceReference.Item = New-Object ("$proxyNamespace.DataSourceReference");
				$newDataSourceReference.Item.Reference = $serverDataSourceItem.Path;
				#$newDataSourceReference.Item.Reference = "/DataSources/SAGA";
				$reportDataSource.item = $newDataSourceReference.Item;

				try{
					$proxy.SetItemDataSources("$ReportsFolder/$($o.BaseName)", $newDataSourceReference); 
				}catch{ 
					throw $_.Exception; 
				}
			}
        }

        #relink report to shared datasets
        Write-Host "Updating DataSet references";

        [xml]$XmlReportDefinition = Get-Content $o.FullName -Encoding ASCII;


        if ($XmlReportDefinition.Report.DataSets.Dataset.count > 0)
        {
		 
            $SharedDataSets = $XmlReportDefinition.Report.DataSets.Dataset | where {$_ | get-member SharedDataSet};

            $DataSetReferences = @();

            try{ 
                $reportDataSetReferences = $proxy.GetItemReferences("$ReportsFolder/$($o.BaseName)", "DataSet") | where {$_.Reference -eq $null}; 
            }catch{ 
                throw $_.Exception; 
            }

            $newDataSetReferences = @();

            foreach ($reportDataSetReference in $reportDataSetReferences)
            {
                $serverDataSetReference = $allitems | where {($_.TypeName -eq "DataSet") -and ($_.Path -eq "$DataSetFolder/$($reportDataSetReference.Name)")};
                $proxynamespace =$reportDataSetReference.Gettype().NameSpace;
                $newDataSetReference = New-Object ("$proxyNamespace.ItemReference");
                $newDataSetReference.Name = $serverDataSetReference.Name;
                $newDataSetReference.Reference = $serverDataSetReference.Path;
				Write-host "Dataset: " $serverDataSetReference.Path 
				#$newDataSetReference.Reference = "/DataSources/SAGA";
                $newDataSetReferences += $newDataSetReference;
				#write-host "Here: " ($reportDataSource | Format-Table | Out-String) -ForegroundColor Magenta
            }

            try{ 
                $DataSetReferences += $proxy.SetItemReferences("$ReportsFolder/$($o.BaseName)", $newDataSetReferences);
            }catch{ 
                throw $_.Exception; 
            }

        }

        Write-Host "Applying…";
        #try{ $proxy.SetPolicies("$ReportsFolder/$($o.BaseName)",$newPolicies); }catch{ throw $_.Exception; }
        Write-Host "Done.";
        $totalReportes = $totalReportes + 1;
    }

    Write-Host "Finished refreshing Reports.";
}

Write-Host "Inicia el script"

#Entry Point & Globals
$LocalReportsPath = "$($ArtefactoPathN)";
# $ReportServerUri = "http://ssisvm/ReportServer/ReportService2010.asmx?wsdl";
$ReportServerUri = "$($RutaN)";
$ReportsParentFolder = "/";

$DataSourceFolderName = "$($DatasoruceN)";
$DataSetFolderName = "";
$ReportsFolderName = "$($ReporteN)";


$DataSourceFolder = $ReportsParentFolder + $DataSourceFolderName ;
$DataSetFolder =  $ReportsParentFolder + $DataSetFolderName ;
$ReportsFolder =  $ReportsParentFolder + $ReportsFolderName ;

$username = "$($usernameN)"
$password = "$($passwordN)"
$cred = New-Object System.Management.Automation.PSCredential -ArgumentList ($username,(ConvertTo-SecureString -String $password -AsPlainText -Force))

try{
    #Create Proxy
    $global:proxy = New-WebServiceProxy -Uri $ReportServerUri -Credential $cred -ErrorAction Stop;
    $valReportsServerUri = ($proxy -ne $null);
}
catch {
    $valProxyError = $_.Exception.Message;
}

DeployAllItems;
 