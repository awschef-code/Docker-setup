-- Procedure for adding a VMProperty. Only adds the property if it does not exist.
DELIMITER $$ 
DROP PROCEDURE IF EXISTS insertProperty$$
CREATE PROCEDURE insertProperty
(IN propName VARCHAR(255),
IN propDescription text,
IN val text,
IN override BOOLEAN,
IN hide BOOLEAN)
BEGIN
	DECLARE PropExists int;
	DECLARE ConfigExists int;
	DECLARE PropId int;
	DECLARE ConfigId int;
    SET PropExists = (select count(*) from VMProperty where name = propName);
	IF (PropExists = 0) THEN 
		select IFNULL(max(id),0) into PropId from VMProperty;
		SET PropId = PropId + 1;
		
		insert into VMProperty (id, name, description, value, overridable, hidden) 
		values (PropId, propName, propDescription, val, override, hide);
		
		select id into ConfigId from VMConfig where name ='AgilityManager';
		
		SET ConfigExists = (select count(*) from VMConfig_properties where VMConfig_id = ConfigId and VMProperty_id = PropId);
		
		IF (ConfigExists = 0) THEN
			insert into VMConfig_properties (VMConfig_id,VMProperty_id)
			values (ConfigId, PropId);
		ELSEIF (ConfigExists > 1) THEN
			select concat("WARNING: Multiple rows for property " ,propName , " were found in VMConfig_properties.") as WARNING;
		END IF;
	ELSEIF (PropExists > 1) THEN
		select concat("WARNING: Multiple rows for property " ,propName , " were found in VMProperty.") as WARNING;
	END IF;	
END $$
DELIMITER ;
