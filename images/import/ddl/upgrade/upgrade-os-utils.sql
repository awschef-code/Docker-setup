-- Used to add new OSes to the OS Taxonomy
-- if os name already exists in taxonomy, we won't add it -- just return the id for future use as parent_id
-- if os doesn't exist, we add it at max_id +1
-- we return the id used for future use as parent_id

DELIMITER $$
DROP PROCEDURE IF EXISTS `Add_OS_to_VMOS` $$
CREATE PROCEDURE `Add_OS_to_VMOS` (
					  IN type_id INT,
					  IN parent_id INT,
					  IN os_name VARCHAR(255),
					  IN os_dname VARCHAR(255),
					  OUT used_id INT
					  )
BEGIN
   DECLARE next_id INT;
   SELECT min(id) FROM VMOperatingSystem WHERE name = os_name INTO used_id;
   SELECT max(id) + 1 from VMOperatingSystem INTO next_id;
   SELECT IFNULL(used_id,next_id) INTO used_id;
   insert into VMOperatingSystem (id,name,displayName,ostype,parent_id)
      select used_id,os_name,os_dname,type_id,parent_id from dual where not exists (select * from VMOperatingSystem where name = os_name or id = used_id );
   -- AP-16448 no longer limit 32-bit linux through the VMOperatingSystem_VMFileSystem table
   -- IF os_name like 'Linux%x32' THEN CALL Add_NonXFS_to_Linux32_VMOS_FS(used_id); END IF;
END$$

DELIMITER ;
