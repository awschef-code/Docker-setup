
DROP PROCEDURE IF EXISTS addPrimaryKeyIfMissing;
DELIMITER //
CREATE PROCEDURE addPrimaryKeyIfMissing(tableSchema VARCHAR(255), tableName VARCHAR(255), pkColumns VARCHAR(255))
DETERMINISTIC
READS SQL DATA
BEGIN
  SET @recCount = (SELECT count(*)
					 FROM information_schema.table_constraints
				    WHERE table_name = tableName
					  AND table_schema = tableSchema
					  AND constraint_name = 'PRIMARY');

  IF @recCount = 0 THEN
    SET @columns = (select GROUP_CONCAT(column_name) from information_schema.columns where TABLE_SCHEMA = tableSchema and TABLE_NAME = tableName);
    SET @dupsDDL = concat("select count(*) from (select 1 from ",tableSchema,".",tableName, " group by ",@columns," having count(*) >1) A into @dups");
    PREPARE STMTdup FROM @dupsDDL;
    EXECUTE STMTdup;
    IF @dups != 0 THEN
       SELECT concat("Found ",@dups," Duplicate rows in table ",tableSchema,".", tableName, " removing them via a temporary table.") AS "";
       CALL removeDuplicateRows(tableSchema,tableName);
    END IF;

    SELECT  concat("Adding Primary Key for ", tableSchema , ".", tableName) AS "";
    SET @ddl = CONCAT('ALTER TABLE ', tableSchema , '.', tableName, ' ADD PRIMARY KEY (', pkColumns, ')');
    PREPARE STMT FROM @ddl;
    EXECUTE STMT;
  ELSE
    SELECT concat("PRIMARY KEY already exists for ", tableSchema , '.', tableName) AS "";
  END IF;
END //
DELIMITER ;


DROP PROCEDURE IF EXISTS dropIndexIfExists;
DELIMITER //
CREATE PROCEDURE dropIndexIfExists(tableSchema VARCHAR(255), tableName VARCHAR(255), indexName VARCHAR(255))
DETERMINISTIC
READS SQL DATA
BEGIN
  SET @recCount = (SELECT count(*)
					 FROM information_schema.statistics
				    WHERE table_name = tableName
					  AND table_schema = tableSchema
					  AND index_name = indexName);

  IF @recCount > 0 THEN
    SELECT  concat("Droping Index ", indexName, " on " , tableSchema , ".", tableName) AS "";
    SET @ddl = CONCAT('ALTER TABLE ', tableSchema , '.', tableName, ' DROP INDEX ', indexName);
    PREPARE STMT FROM @ddl;
    EXECUTE STMT;
  END IF;
END //
DELIMITER ;

DROP PROCEDURE IF EXISTS createIndex;
DELIMITER //
CREATE PROCEDURE createIndex(tableSchema VARCHAR(255), tableName VARCHAR(255), indexName VARCHAR(255), indexColumns VARCHAR(255), indexOptions VARCHAR(255))
DETERMINISTIC
READS SQL DATA
BEGIN
  SET @recCount = (SELECT count(*)
					 FROM information_schema.statistics
				    WHERE table_name = tableName
					  AND table_schema = tableSchema
					  AND index_name = indexName);

  IF @recCount = 0 THEN
    SELECT  concat("Creating Unique Index ", indexName, " on " , tableSchema , ".", tableName) AS "";
    SET @ddl = CONCAT('ALTER TABLE ', tableSchema , '.', tableName, ' ADD ', indexOptions, ' INDEX ', indexName , ' (', indexColumns, ')');
    PREPARE STMT FROM @ddl;
    EXECUTE STMT;
  END IF;
END //
DELIMITER ;

-- ################# Procedure to remove duplicate rows from a table ####################
DROP PROCEDURE IF EXISTS removeDuplicateRows;
DELIMITER //
CREATE PROCEDURE removeDuplicateRows(tabSchema VARCHAR(255), tabName VARCHAR(255))
DETERMINISTIC
READS SQL DATA
BEGIN
   SET @createDDL = concat("CREATE TABLE IF NOT EXISTS ",tabSchema,".dupCleanupTmp LIKE ",tabSchema,".",tabName);
   PREPARE STMTcreate FROM @createDDL;
   EXECUTE STMTcreate;

   SET @copyDDL = concat("INSERT INTO ",tabSchema,".dupCleanupTmp SELECT distinct * FROM ",tabSchema,".",tabName);
   PREPARE STMTcopy FROM @copyDDL;
   EXECUTE STMTcopy;

   SET @deleteDDL = concat("DELETE FROM ",tabSchema,".",tabName);
   PREPARE STMTdel FROM @deleteDDL;
   EXECUTE STMTdel;

   SET @insertDDL = concat("INSERT INTO ",tabSchema,".",tabName," SELECT * FROM ",tabSchema,".dupCleanupTmp");
   PREPARE STMTin FROM @insertDDL;
   EXECUTE STMTin;

   SET @dropDDL = concat("DROP TABLE ",tabSchema,".dupCleanupTmp");
   PREPARE STMTdrop FROM @dropDDL;
   EXECUTE STMTdrop;
END //
DELIMITER ;

-- ################# Procedure to update cm_* cloud tables ####################
DROP PROCEDURE IF EXISTS updateClonedCMTables;
DELIMITER //
CREATE PROCEDURE updateClonedCMTables()
DETERMINISTIC
READS SQL DATA
BEGIN
    DECLARE done INT DEFAULT FALSE;
    DECLARE tabName VARCHAR(255);
    DECLARE tableCursor CURSOR for SELECT t.table_name FROM information_schema.tables t LEFT JOIN information_schema.table_constraints c ON t.table_schema = c.table_schema AND t.table_name = c.table_name
    WHERE t.table_type = 'BASE TABLE' AND t.table_schema = 'cloud' AND t.table_name like 'cm\_%' GROUP BY t.table_name HAVING sum(if(c.constraint_type='PRIMARY KEY', 1, 0)) = 0;
    DECLARE CONTINUE HANDLER FOR NOT FOUND SET done = TRUE;

    OPEN tableCursor;
       tableLoop: LOOP
          FETCH tableCursor INTO tabName;
          IF done THEN
            CLOSE tableCursor;
            LEAVE tableLoop;
          END IF;
          CALL addPrimaryKeyIfMissing("cloud",tabName,"container_id,instance_id,template_id");
   END LOOP;
END //
DELIMITER ;



DROP TABLE IF EXISTS cloud.TempConstraintTable;

call addPrimaryKeyIfMissing("activity", "Activity", "started,id");
call addPrimaryKeyIfMissing("activity", "ActivityProperty", "tstamp,id");
call addPrimaryKeyIfMissing("activity", "ActivitySource_properties", "sourceId,propertyId");
call addPrimaryKeyIfMissing("event", "Event", "tstamp,id");
call addPrimaryKeyIfMissing("cloud", "product_version", "major,minor,build,revision(64),installed");
call addPrimaryKeyIfMissing("activity", "ActivitySource", "id");
call dropIndexIfExists("activity", "ActivitySource", "id");
call addPrimaryKeyIfMissing("event", "Asset", "id,typeId");
ALTER TABLE  event.EventProperty CHANGE id id int(11) NOT NULL;
call addPrimaryKeyIfMissing("event", "EventProperty", "tstamp,id");
call dropIndexIfExists("event", "AssetMembership", "parent_id");
call createIndex("event", "AssetMembership", "idxAssetMembership_unq1", "parent_id,parent_type_id,child_id,child_type_id","UNIQUE");
call addPrimaryKeyIfMissing("cloud", "AssetType_PropertyDefinitionGroup", "AssetType_id,propertyDefinitionGroups_id");
call addPrimaryKeyIfMissing("cloud", "AuthGroupMapping_VMUserGroup", "auth_id,group_id");
call addPrimaryKeyIfMissing("cloud", "CmArtifact_VMServiceProvider", "CmArtifact_id,servers_id");
call addPrimaryKeyIfMissing("cloud", "CmRepository_VMServiceProvider", "repositories_id,serviceProviders_id");
call addPrimaryKeyIfMissing("cloud", "CpProduct_CpCategory", "CpProduct_id,categories_id");
call addPrimaryKeyIfMissing("cloud", "DbPageContext_pages", "context_id,page_id");
call addPrimaryKeyIfMissing("cloud", "DbPageLayoutGroup_DbPageControl", "group_id,control_id");
call addPrimaryKeyIfMissing("cloud", "DbPageLayout_DbPageLayoutGroup", "layout_id,group_id");
call addPrimaryKeyIfMissing("cloud", "DbPage_VMUser", "page_id,user_id");
call addPrimaryKeyIfMissing("cloud", "DbPage_VMUserGroup", "page_id,group_id");
call addPrimaryKeyIfMissing("cloud", "RmArtifactRuntimeBinding_RmServiceBinding", "runtime_id,binding_id");
call addPrimaryKeyIfMissing("cloud", "RmAttachment_VMRepository", "RmAttachment_id,repositories_id");
call addPrimaryKeyIfMissing("cloud", "RmDeployer_templates", "deployer_id,template_id");
call addPrimaryKeyIfMissing("cloud", "RmDeploymentArtifactConfig_RmServiceBinding", "runtime_id,binding_id");
call addPrimaryKeyIfMissing("cloud", "RmDesignDeployer_workloads", "deployer_id,workload_id");
call addPrimaryKeyIfMissing("cloud", "RmSolutionDeployment_RmArtifact", "deployment_id,artifact_id");
call addPrimaryKeyIfMissing("cloud", "Task_candidateGroups", "Task_id,VMUserGroup_id");
call addPrimaryKeyIfMissing("cloud", "Task_candidateUsers", "Task_id,VMUser_id");
call addPrimaryKeyIfMissing("cloud", "VMCloudType_customizationScripts", "VMCloudType_id,VMScript_id");
call addPrimaryKeyIfMissing("cloud", "VMCloudType_fileSystems", "VMCloudType_id,VMFileSystem_id");
call addPrimaryKeyIfMissing("cloud", "VMCloudType_VMModel", "models_id");
call addPrimaryKeyIfMissing("cloud", "VMCloud_policies", "VMCloud_id,VMPolicy_id");
call addPrimaryKeyIfMissing("cloud", "VMContainerRights_userGroups", "securityRole_id,userGroup_id");
call addPrimaryKeyIfMissing("cloud", "VMContainerRights_users", "securityRole_id,user_id");
call addPrimaryKeyIfMissing("cloud", "VMContainer_CpProduct", "VMContainer_id,products_id");
call addPrimaryKeyIfMissing("cloud", "VMInstance_VMCredentials", "VMInstance_id,credentials_id");
call addPrimaryKeyIfMissing("cloud", "VMInstance_VMServiceProvider", "VMInstance_id,VMServiceProvider_id");
call addPrimaryKeyIfMissing("cloud", "VMLocation_VMCredentials", "VMLocation_id,VMCredentials_id");
call addPrimaryKeyIfMissing("cloud", "VMLocation_VMImage", "VMLocation_id,VMImage_id");
call addPrimaryKeyIfMissing("cloud", "VMLocation_VMModel", "VMLocation_id,VMModel_id");
call addPrimaryKeyIfMissing("cloud", "VMLocation_VMNetwork", "VMNetwork_id,VMLocation_id");
call addPrimaryKeyIfMissing("cloud", "VMLocation_VMRepository", "VMRepository_id,VMLocation_id");
call addPrimaryKeyIfMissing("cloud", "VMMgmtScriptGroup_VMMgmtScript", "VMMgmtScriptGroup_id,mgmtScripts_id");
call addPrimaryKeyIfMissing("cloud", "VMPackage_VMPackage", "VMPackage_id,dependencies_id");
call addPrimaryKeyIfMissing("cloud", "VMPackage_variables", "PropertyDefinition_id");
call addPrimaryKeyIfMissing("cloud", "VMScriptPropertyReference_AssetType", "VMScriptPropertyReference_id,assetTypes_id");
call addPrimaryKeyIfMissing("cloud", "VMServiceProviderType_AssetType", "VMServiceProviderType_id,serviceTypes_id");
call addPrimaryKeyIfMissing("cloud", "VMServiceProviderType_providerOptions", "VMServiceProviderType_id,providerOptions");
call addPrimaryKeyIfMissing("cloud", "VMServiceProvider_VMLocation", "VMServiceProvider_id,VMLocation_id");
call addPrimaryKeyIfMissing("cloud", "VMServiceProvider_VMNetwork", "VMServiceProvider_id,VMNetwork_id");
call addPrimaryKeyIfMissing("cloud", "VMTargetCloud_models", "VMTargetCloud_id,VMModel_id");
call addPrimaryKeyIfMissing("cloud", "VMUserGroup_VMSecurityRole", "VMUserGroup_id,securityRoles_id");
call addPrimaryKeyIfMissing("cloud", "VMUserGroup_VMUserGroup", "childGroup_id,parentGroup_id");
call addPrimaryKeyIfMissing("cloud", "VMUser_VMUserGroup", "VMUser_id,VMUserGroup_id");
call addPrimaryKeyIfMissing("cloud", "VMWorkload_CmResource", "VMWorkload_id,CmResource_id");


call dropIndexIfExists("metric", "MetricPolicy_MetricItem","policy_id");
call createIndex("metric", "MetricPolicy_MetricItem","idxMetricPolicyMetricItemUniq1", "policy_id,template_id","UNIQUE");
call createIndex("metric", "MetricThreshold_exceeded","idxMetricThresholdExceededUniq1", "uuid","UNIQUE");
call dropIndexIfExists("metric", "query_items","query_id_2");
call createIndex("metric", "query_items","idxQueryItemsUniq1", "query_id,item_id","UNIQUE");
call dropIndexIfExists("metric", "query_metric_items","query_id");
call dropIndexIfExists("metric", "query_metric_items","query_id_2");
call createIndex("metric", "query_metric_items","idxQueryMetricItemsQryInst", "query_id,instance_id","");
call createIndex("metric", "query_metric_items","idxQueryMetricItemsUniq1", "query_id,template_id,instance_id","UNIQUE");
call addPrimaryKeyIfMissing("metric", "report_query_metric_items", "query_id,cloud_id,template_id,instance_id");
call addPrimaryKeyIfMissing("metric", "ContainerMembership", "container_id,cloud_id,template_id,instance_id");

CALL updateClonedCMTables;
