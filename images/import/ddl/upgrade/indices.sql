
DROP PROCEDURE IF EXISTS setAutoIncrementColumnAsPrimaryKey;
DELIMITER //
CREATE PROCEDURE setAutoIncrementColumnAsPrimaryKey(tableSchema VARCHAR(50), tableName VARCHAR(50))
DETERMINISTIC
READS SQL DATA
this_proc:BEGIN
  SET @tableExists = (SELECT count(*) from information_schema.tables
      where table_name = tableName and table_schema = tableSchema);
  IF @tableExists = 0 THEN
     LEAVE this_proc;
  END IF;


  SET @recCount = (SELECT count(*)
                     FROM information_schema.columns
                    WHERE table_name = tableName
                	    AND table_schema = tableSchema
                	    AND column_name = 'id'
                	    AND column_key = 'PRI');

  IF @recCount = 0 THEN
	SET @pkRecCount = (SELECT count(*)
					     FROM information_schema.table_constraints
						WHERE table_name = tableName
					      AND table_schema = tableSchema
					      AND constraint_name = 'PRIMARY');
    IF @pkRecCount >  1 THEN
		SELECT  concat("Dropping old PRIMARY KEY column for ", tableSchema , ".", tableName) AS "";
		SET @ddlPK = CONCAT('ALTER TABLE ', tableSchema , '.', tableName, ' DROP PRIMARY KEY');
		PREPARE STMT FROM @ddlPK;
		EXECUTE STMT;
    END IF;
    SELECT  concat("Adding AUTO INCREMENT PRIMARY KEY column for ", tableSchema , ".", tableName) AS "";
    SET @ddl = CONCAT('ALTER TABLE ', tableSchema , '.', tableName, ' ADD COLUMN id INT NOT NULL AUTO_INCREMENT PRIMARY KEY ');
    PREPARE STMT FROM @ddl;
    EXECUTE STMT;
  ELSE
	SELECT concat("No changes needed, AUTO INCREMENT PRIMARY KEY Column already exists for ", tableSchema , ".", tableName) AS "";
  END IF;
END //
DELIMITER ;

-- ################# Procedure to update metric_t & m_* metric tables ####################
DROP PROCEDURE IF EXISTS updateClonedMetricTables;
DELIMITER //
CREATE PROCEDURE updateClonedMetricTables()
DETERMINISTIC
READS SQL DATA
BEGIN
    DECLARE done INT DEFAULT FALSE;
    DECLARE tabName VARCHAR(255);
    DECLARE tableCursor CURSOR for SELECT t.table_name FROM information_schema.tables t LEFT JOIN information_schema.table_constraints c ON t.table_schema = c.table_schema AND t.table_name = c.table_name
    WHERE t.table_type = 'BASE TABLE' AND t.table_schema = 'metric' AND (t.table_name like 'm\_%' OR t.table_name="metric_t") GROUP BY t.table_name HAVING sum(if(c.constraint_type='PRIMARY KEY', 1, 0)) = 0;
    DECLARE CONTINUE HANDLER FOR NOT FOUND SET done = TRUE;

    OPEN tableCursor;
       tableLoop: LOOP
          FETCH tableCursor INTO tabName;
          IF done THEN
            CLOSE tableCursor;
            LEAVE tableLoop;
          END IF;
          SELECT  concat("Adding AUTO INCREMENT column as part of PRIMARY KEY for metric.", tabName) AS "";
          SET @ddl = CONCAT('ALTER TABLE metric.', tabName, ' ADD COLUMN id INT NOT NULL AUTO_INCREMENT, ADD PRIMARY KEY (id, item_id, duration, tstamp)');
          PREPARE STMT FROM @ddl;
          EXECUTE STMT;
   END LOOP;
END //
DELIMITER ;

CALL setAutoIncrementColumnAsPrimaryKey("cloud", "AssetType_editors");
CALL setAutoIncrementColumnAsPrimaryKey("cloud", "CmResource_properties");
CALL setAutoIncrementColumnAsPrimaryKey("cloud", "CmRepository_paths");
CALL setAutoIncrementColumnAsPrimaryKey("cloud", "CpProduct_requirements");
CALL setAutoIncrementColumnAsPrimaryKey("cloud", "VMFileSystem_supportedRaidLevels");
CALL setAutoIncrementColumnAsPrimaryKey("cloud", "VMFileSystem_Devices");
CALL setAutoIncrementColumnAsPrimaryKey("cloud", "VMProperty_availableOptions");
CALL setAutoIncrementColumnAsPrimaryKey("cloud", "VMProtocol_prefixes");
CALL setAutoIncrementColumnAsPrimaryKey("cloud", "VMRepository_usage");
CALL setAutoIncrementColumnAsPrimaryKey("cloud", "VMRepositoryType_supportedUsage");
CALL setAutoIncrementColumnAsPrimaryKey("cloud", "VMRepositoryType_providerOptions");
CALL setAutoIncrementColumnAsPrimaryKey("cloud", "VMNotification_products");
CALL setAutoIncrementColumnAsPrimaryKey("cloud", "UserTask_comments");
CALL setAutoIncrementColumnAsPrimaryKey("cloud", "UserTask_actions");
CALL setAutoIncrementColumnAsPrimaryKey("cloud", "VMOperatingSystem_VMFileSystem");
CALL setAutoIncrementColumnAsPrimaryKey("cloud", "VMRepository_properties");
CALL setAutoIncrementColumnAsPrimaryKey("cloud", "EventTypes");

-- update any metric.m_* tables that were cloned off of metric_t
CALL updateClonedMetricTables;
