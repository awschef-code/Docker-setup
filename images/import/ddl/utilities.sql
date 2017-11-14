DELIMITER $$
DROP FUNCTION IF EXISTS next_slot$$
CREATE FUNCTION next_slot(uuidstr varchar(255)) RETURNS INT DETERMINISTIC
BEGIN
	DECLARE slot INT;
        select id from Slot where uuid=uuidstr INTO slot;
        IF slot is null THEN
	   insert into Slot (uuid) values (uuidstr);
	   select LAST_INSERT_ID() INTO slot;
        END IF;
        RETURN slot;
END $$

DROP PROCEDURE IF EXISTS disable_xfs_linux$$
CREATE PROCEDURE disable_xfs_linux()
BEGIN

  DECLARE done INT DEFAULT 0;
  DECLARE os_id INT;
  DECLARE c CURSOR FOR SELECT id from VMOperatingSystem WHERE name like 'Linux%x32';
  DECLARE CONTINUE HANDLER FOR SQLSTATE '02000' SET done = 1;

  OPEN c;
  REPEAT
  FETCH c INTO os_id;
  IF NOT done THEN

     delete from VMOperatingSystem_VMFileSystem where VMOperatingSystem_id = os_id;
     insert into VMOperatingSystem_VMFileSystem values
		(os_id,1),
		(os_id,6),
		(os_id,9);

  END IF;
  UNTIL done END REPEAT;
  CLOSE c;

END$$

DROP PROCEDURE IF EXISTS enable_xfs_linux$$
CREATE PROCEDURE enable_xfs_linux()
BEGIN

  DECLARE done INT DEFAULT 0;
  DECLARE os_id INT;
  DECLARE c CURSOR FOR SELECT id from VMOperatingSystem WHERE name like 'Linux%x64';
  DECLARE CONTINUE HANDLER FOR SQLSTATE '02000' SET done = 1;

  OPEN c;
  REPEAT
  FETCH c INTO os_id;
  IF NOT done THEN

     delete from VMOperatingSystem_VMFileSystem where VMOperatingSystem_id = os_id;
     insert into VMOperatingSystem_VMFileSystem values
                (os_id,1),
                (os_id,9),
		(os_id,6),
		(os_id,2),
                (os_id,10);

  END IF;
  UNTIL done END REPEAT;
  CLOSE c;

END$$

DROP PROCEDURE IF EXISTS create_string_property_definition$$
CREATE PROCEDURE create_string_property_definition(pdef_name varchar(255), pdef_value varchar(255), pdef_required int)
BEGIN

   select ifnull(max(id),0)+1 from PropertyDefinition into @pdef_id;
   select id from PropertyType where name='string-any' into @type_id;

   insert into PropertyDefinition (id,name,displayName,minRequired,maxAllowed,readable,writable,propertyType_id)
   values (@pdef_id,pdef_name,pdef_name,pdef_required,1,1,1,@type_id);

   IF NOT pdef_value IS NULL THEN

      select ifnull(max(id),0)+1 from AssetProperty into @prop_id;
      insert into AssetProperty (id,name,stringValue,propertyDefinition_id)
      values (@prop_id,pdef_name,pdef_value,@pdef_id);

      insert into PropertyDefinition_defaultValues 
      values (@pdef_id, @prop_id);

   END IF;

END$$

DROP PROCEDURE IF EXISTS create_binary_property_definition$$
CREATE PROCEDURE create_binary_property_definition(pdef_name varchar(255), pdef_required int)
BEGIN

   select ifnull(max(id),0)+1 from PropertyDefinition into @pdef_id;
   select id from PropertyType where name='binary' into @type_id;

   insert into PropertyDefinition (id,name,displayName,minRequired,maxAllowed,readable,writable,propertyType_id)
   values (@pdef_id,pdef_name,pdef_name,pdef_required,1,1,1,@type_id);

END$$

DROP PROCEDURE IF EXISTS create_encrypted_property_definition$$
CREATE PROCEDURE create_encrypted_property_definition(pdef_name varchar(255), pdef_required int)
BEGIN

   select ifnull(max(id),0)+1 from PropertyDefinition into @pdef_id;
   select id from PropertyType where name='encrypted' into @type_id;

   insert into PropertyDefinition (id,name,displayName,minRequired,maxAllowed,readable,writable,propertyType_id)
   values (@pdef_id,pdef_name,pdef_name,pdef_required,1,1,1,@type_id);

END$$

DROP PROCEDURE IF EXISTS create_integer_property_definition$$
CREATE PROCEDURE create_integer_property_definition(pdef_name varchar(255), pdef_value int, pdef_required int)
BEGIN

   select ifnull(max(id),0)+1 from PropertyDefinition into @pdef_id;
   select id from PropertyType where name='integer-any' into @type_id;

   insert into PropertyDefinition (id,name,displayName,minRequired,maxAllowed,readable,writable,propertyType_id)
   values (@pdef_id,pdef_name,pdef_name,pdef_required,1,1,1,@type_id);

   IF NOT pdef_value IS NULL THEN

      select ifnull(max(id),0)+1 from AssetProperty into @prop_id;
      insert into AssetProperty (id,name,intValue,propertyDefinition_id)
      values (@prop_id,pdef_name,pdef_value,@pdef_id);

      insert into PropertyDefinition_defaultValues 
      values (@pdef_id, @prop_id);

   END IF;

END$$

DROP PROCEDURE IF EXISTS create_boolean_property_definition$$
CREATE PROCEDURE create_boolean_property_definition(pdef_name varchar(255), pdef_value int, pdef_required int)
BEGIN

   select ifnull(max(id),0)+1 from PropertyDefinition into @pdef_id;
   select id from PropertyType where name='boolean' into @type_id;

   insert into PropertyDefinition (id,name,displayName,minRequired,maxAllowed,readable,writable,propertyType_id)
   values (@pdef_id,pdef_name,pdef_name,pdef_required,1,1,1,@type_id);

   IF NOT pdef_value IS NULL THEN

      select ifnull(max(id),0)+1 from AssetProperty into @prop_id;
      insert into AssetProperty (id,name,booleanValue,propertyDefinition_id)
      values (@prop_id,pdef_name,pdef_value,@pdef_id);

      insert into PropertyDefinition_defaultValues 
      values (@pdef_id, @prop_id);

   END IF;

END$$

DROP PROCEDURE IF EXISTS create_setup_property$$
CREATE PROCEDURE create_setup_property(prop_name varchar(255), prop_desc varchar(255), prop_value varchar(255), prop_hidden int)
BEGIN

-- select 'create_setup_property' as '', prop_name as '', prop_value as '';

   delete from VMConfig_properties
      where  VMProperty_id in ( select id from VMProperty where name=prop_name);
   delete from VMProperty where name=prop_name;

   insert into VMProperty (id,name,description,value,hidden,overridable)
      select max(id)+1, prop_name, prop_desc, prop_value, @prop_hidden, false from VMProperty;
   insert into VMConfig_properties (VMConfig_id,VMProperty_id)
      select 1,id from VMProperty where name=prop_name;

END$$

DROP PROCEDURE IF EXISTS update_setup_property$$
CREATE PROCEDURE update_setup_property(prop_name varchar(255), prop_value varchar(255))
BEGIN

-- select 'update_setup_property' as '', prop_name as '', prop_value as '';

   update VMProperty set value=prop_value where name=prop_name;

END$$


DROP PROCEDURE IF EXISTS create_setup_property$$
CREATE PROCEDURE create_setup_property(prop_name varchar(255), prop_desc varchar(255), prop_value varchar(255), prop_hidden int)
BEGIN

-- select 'create_setup_property' as '', prop_name as '', prop_value as '';

   delete from VMConfig_properties
      where  VMProperty_id in ( select id from VMProperty where name=prop_name);
   delete from VMProperty where name=prop_name;

   insert into VMProperty (id,name,description,value,hidden,overridable)
      select max(id)+1, prop_name, prop_desc, prop_value, @prop_hidden, false from VMProperty;
   insert into VMConfig_properties (VMConfig_id,VMProperty_id)
      select 1,id from VMProperty where name=prop_name;

END$$

DROP PROCEDURE IF EXISTS update_setup_property$$
CREATE PROCEDURE update_setup_property(prop_name varchar(255), prop_value varchar(255))
BEGIN

-- select 'update_setup_property' as '', prop_name as '', prop_value as '';

   update VMProperty set value=prop_value where name=prop_name;

END$$


DROP PROCEDURE IF EXISTS findReferences$$
CREATE PROCEDURE findReferences(IN tableName VARCHAR(128), IN id INT(11))
BEGIN

  DECLARE done INT DEFAULT 0;
  DECLARE tname VARCHAR(128);
  DECLARE colName VARCHAR(128);
  DECLARE find_sql VARCHAR(256);

  DECLARE c CURSOR FOR SELECT TABLE_NAME,COLUMN_NAME  FROM information_schema.KEY_COLUMN_USAGE 
   WHERE REFERENCED_TABLE_NAME = tableName;
   
  DECLARE CONTINUE HANDLER FOR SQLSTATE '02000' SET done = 1;

  OPEN c;
  REPEAT
  FETCH c INTO tname, colName;
  IF NOT done THEN

      SET find_sql = CONCAT('SELECT \'',tname,'\',`',colName,'` FROM  `',tname,'` where `',colName,'` = ',id);
      SET @sqlstatement = find_sql;
      PREPARE sqlquery FROM @sqlstatement;
      EXECUTE sqlquery;
      DEALLOCATE PREPARE sqlquery;

  END IF;
  UNTIL done END REPEAT;
  CLOSE c;

END$$

DROP FUNCTION IF EXISTS table_exists$$
CREATE FUNCTION table_exists(schema_name text, tbl_name text) RETURNS BOOLEAN
BEGIN

   RETURN EXISTS (SELECT * FROM information_schema.tables
                  WHERE table_schema = schema_name
                  AND   table_name   = tbl_name);

END$$

DELIMITER ;
