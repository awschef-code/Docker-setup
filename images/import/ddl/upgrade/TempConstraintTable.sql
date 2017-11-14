-- Procedures for the setup of a table to hold foreign key constraints. 
-- By using this we can greatly improve performance over using INFORMATION_SCHEMA.KEY_COLUMN_USAGE

-- This is the only procedure you really need to call. Just pass in the table you want the foreign
-- key dependency info for and this procedure will use the PopulateTempConstraintTable procedure
-- to fill in all the dependencies of the tables that are dependent on the provided table.
DELIMITER $$ 
DROP PROCEDURE IF EXISTS SetupTempConstraintTable$$
CREATE PROCEDURE SetupTempConstraintTable(IN tableNameIn VARCHAR(255))
BEGIN
	CREATE TABLE IF NOT EXISTS TempConstraintTable
    (TABLE_NAME VARCHAR(255),
    COLUMN_NAME VARCHAR(255),
    REFERENCED_TABLE_NAME VARCHAR(255),
    REFERENCED_COLUMN_NAME VARCHAR(255),
    PRIMARY KEY (TABLE_NAME, COLUMN_NAME, REFERENCED_TABLE_NAME, REFERENCED_COLUMN_NAME));
    
    INSERT INTO TempConstraintTable 
		SELECT DISTINCT TABLE_NAME,COLUMN_NAME,REFERENCED_TABLE_NAME,REFERENCED_COLUMN_NAME FROM INFORMATION_SCHEMA.KEY_COLUMN_USAGE i
        WHERE REFERENCED_TABLE_NAME = tableNameIn AND TABLE_NAME != REFERENCED_TABLE_NAME AND NOT EXISTS (SELECT 1 FROM TempConstraintTable t
			WHERE t.REFERENCED_TABLE_NAME = i.REFERENCED_TABLE_NAME AND t.REFERENCED_COLUMN_NAME = i.REFERENCED_COLUMN_NAME 
            AND t.TABLE_NAME = i.TABLE_NAME AND t.COLUMN_NAME = i.COLUMN_NAME);
	COMMIT;
    
    CALL PopulateTempConstraintTable(tableNameIn);
    
END $$
DELIMITER ;

-- NOTE: This procedure requires there to be rows in the TempConstraintTable for the table name you are passing in.
-- It is recomended that you do not call this procedure directly and instead use the SetupTempConstraintTable
-- procedure that calls this one.
DELIMITER $$ 
DROP PROCEDURE IF EXISTS PopulateTempConstraintTable$$
CREATE PROCEDURE PopulateTempConstraintTable
(IN tableNameIn VARCHAR(255))
populateTable: BEGIN
    DECLARE done INT DEFAULT FALSE;
    DECLARE tableName VARCHAR(255);
    DECLARE dependencyTablesCur CURSOR FOR SELECT DISTINCT TABLE_NAME FROM TempConstraintTable WHERE REFERENCED_TABLE_NAME = tableNameIn;
    DECLARE CONTINUE HANDLER FOR NOT FOUND SET done = TRUE;
    
    OPEN dependencyTablesCur;
	-- cleanup further dependencies
	depenencyTablesLoop: LOOP
		FETCH dependencyTablesCur INTO tableName;
        IF done THEN
			CLOSE dependencyTablesCur;
			LEAVE depenencyTablesLoop;
		END IF;
	
        -- no more dependencies found for this table so try the next one.
		IF (SELECT NOT EXISTS(SELECT 1 FROM INFORMATION_SCHEMA.KEY_COLUMN_USAGE WHERE REFERENCED_TABLE_NAME = tableName	AND TABLE_NAME != REFERENCED_TABLE_NAME)) THEN
			ITERATE depenencyTablesLoop;
		-- there are dependencies for this table so add them and check for more
		ELSE
			INSERT INTO TempConstraintTable 
				SELECT DISTINCT TABLE_NAME,COLUMN_NAME,REFERENCED_TABLE_NAME,REFERENCED_COLUMN_NAME FROM INFORMATION_SCHEMA.KEY_COLUMN_USAGE i
				WHERE REFERENCED_TABLE_NAME = tableName AND TABLE_NAME != REFERENCED_TABLE_NAME AND NOT EXISTS (SELECT 1 FROM TempConstraintTable t
					WHERE t.REFERENCED_TABLE_NAME = i.REFERENCED_TABLE_NAME AND t.REFERENCED_COLUMN_NAME = i.REFERENCED_COLUMN_NAME 
					AND t.TABLE_NAME = i.TABLE_NAME AND t.COLUMN_NAME = i.COLUMN_NAME);
			COMMIT;
            CALL PopulateTempConstraintTable(tableName);
		END IF;
	END LOOP;
END $$
DELIMITER ;
 