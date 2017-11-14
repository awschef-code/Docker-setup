use cloud;

DELIMITER $$


DROP PROCEDURE IF EXISTS createPrimaryKey$$
CREATE PROCEDURE createPrimaryKey(IN cschema VARCHAR(256), IN cname VARCHAR(256), IN tschema VARCHAR(256), IN tname VARCHAR(256))
BEGIN

   DECLARE done INT DEFAULT 0;
   DECLARE key_column VARCHAR(256);
   DECLARE comma INT DEFAULT NULL;
   DECLARE pkey VARCHAR(1024);
   DECLARE drop_unique VARCHAR(1024);

   DECLARE c CURSOR FOR SELECT column_name FROM information_schema.key_column_usage WHERE constraint_schema=cschema AND constraint_name=cname
     AND table_schema=tschema AND table_name=tname ORDER BY ordinal_position;

   DECLARE CONTINUE HANDLER FOR SQLSTATE '02000' SET done = 1;

   SET pkey = CONCAT('ALTER TABLE  `',tschema,'`.`',tname,'` ADD PRIMARY KEY (');
   OPEN c;
   REPEAT
   FETCH c INTO key_column;
   IF NOT done THEN

      IF comma IS NULL THEN
        SET pkey = CONCAT(pkey,key_column);
        SET comma = 1;
      ELSE
        SET pkey = CONCAT(pkey,',',key_column);
      END IF;

   END IF;
   UNTIL done END REPEAT;
   CLOSE c;
   SET pkey=CONCAT(pkey,')');

   SET @sqlstatement = pkey;
   PREPARE sqlquery FROM @sqlstatement;
   EXECUTE sqlquery;
   DEALLOCATE PREPARE sqlquery;

   -- drop unique key
   SET drop_unique = CONCAT('ALTER TABLE  ',tschema,'.',tname,' DROP INDEX  `',cname,'`');
   SET @sqlstatement = drop_unique;
   PREPARE sqlquery FROM @sqlstatement;
   EXECUTE sqlquery;
   DEALLOCATE PREPARE sqlquery;

END$$


DROP PROCEDURE IF EXISTS createPrimaryKeys$$
CREATE PROCEDURE createPrimaryKeys()
BEGIN

  DECLARE done INT DEFAULT 0;
  DECLARE cschema VARCHAR(256);
  DECLARE cname VARCHAR(256);
  DECLARE tschema VARCHAR(256);
  DECLARE tname VARCHAR(256);

  DECLARE c CURSOR FOR SELECT constraint_schema,constraint_name,table_schema,table_name FROM information_schema.table_constraints WHERE constraint_type='UNIQUE' AND table_name NOT IN (
     SELECT table_name FROM information_schema.table_constraints WHERE constraint_type='PRIMARY KEY');

  DECLARE CONTINUE HANDLER FOR SQLSTATE '02000' SET done = 1;

  OPEN c;
  REPEAT
  FETCH c INTO cschema, cname, tschema, tname;
  IF NOT done THEN

      CALL createPrimaryKey(cschema,cname,tschema,tname);

  END IF;
  UNTIL done END REPEAT;
  CLOSE c;

END$$

DELIMITER ;
