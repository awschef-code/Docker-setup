#
#
# Update Stored procedure for container membership stats to bypass deleted assets
#
#

use metric;

DELIMITER $$

DROP PROCEDURE IF EXISTS UpdateSubcontainerChildren$$

CREATE PROCEDURE UpdateSubcontainerChildren(IN parentId INT(11))
BEGIN
    DECLARE done INT DEFAULT 0;
    DECLARE m_container_id INT DEFAULT 0;

    DECLARE c_i CURSOR FOR 
      SELECT id FROM cloud.VMContainer WHERE parent_id=parentId and deleted=0;
       
    DECLARE CONTINUE HANDLER FOR SQLSTATE '02000' SET done = 1;

    SET TRANSACTION ISOLATION LEVEL READ UNCOMMITTED;
    START TRANSACTION;
   
    OPEN c_i;
    REPEAT
       FETCH c_i INTO m_container_id;
       IF NOT done THEN
         INSERT INTO metric.ContainerMembership(container_id, cloud_id, service_instance_id, instance_id, template_id) 
             (SELECT parentId, cloud_id, service_instance_id, instance_id, template_id FROM ContainerMembership 
               WHERE container_id = m_container_id);
       END IF;
    UNTIL done END REPEAT;
    COMMIT;
END $$

DROP PROCEDURE IF EXISTS UpdateContainerClouds$$
	    
CREATE PROCEDURE UpdateContainerClouds(IN parentId INT(11))
BEGIN
    DECLARE done INT DEFAULT 0;
    DECLARE m_cloud_id INT DEFAULT 0;

    DECLARE c_i CURSOR FOR 
      SELECT id FROM cloud.VMCloud WHERE parent_id=parentId and deleted=0;
       
    DECLARE CONTINUE HANDLER FOR SQLSTATE '02000' SET done = 1;

    SET TRANSACTION ISOLATION LEVEL READ UNCOMMITTED;
    START TRANSACTION;
   
    OPEN c_i;
    REPEAT
       FETCH c_i INTO m_cloud_id;
       IF NOT done THEN
         INSERT INTO metric.ContainerMembership(container_id, cloud_id, service_instance_id, instance_id, template_id) 
             values(parentId, m_cloud_id, 0, 0, 0);
       END IF;
    UNTIL done END REPEAT;
    COMMIT;
END $$
	    
DROP PROCEDURE IF EXISTS UpdateContainerTemplates$$
	    
CREATE PROCEDURE UpdateContainerTemplates(IN parentId INT(11))
BEGIN
    DECLARE done INT DEFAULT 0;
    DECLARE m_cloud_id INT DEFAULT 0;
    DECLARE m_template_id INT DEFAULT 0;

    DECLARE c_i CURSOR FOR 
      SELECT id,cloud_id FROM cloud.VMTemplate 
         WHERE parent_id=parentId AND cloud_id IS NOT NULL and deleted=0;
       
    DECLARE CONTINUE HANDLER FOR SQLSTATE '02000' SET done = 1;

    SET TRANSACTION ISOLATION LEVEL READ UNCOMMITTED;
    START TRANSACTION;
   
    OPEN c_i;
    REPEAT
       FETCH c_i INTO m_template_id, m_cloud_id;
       IF NOT done THEN
         INSERT INTO metric.ContainerMembership(container_id, cloud_id, service_instance_id, instance_id, template_id) 
             values(parentId, m_cloud_id, 0, 0, m_template_id);
       END IF;
    UNTIL done END REPEAT;
    COMMIT;
END $$
	    
DROP PROCEDURE IF EXISTS UpdateContainerInstances$$
	    
CREATE PROCEDURE UpdateContainerInstances(IN parentId INT(11))
BEGIN
    DECLARE done INT DEFAULT 0;
    DECLARE m_cloud_id INT DEFAULT 0;
    DECLARE m_template_id INT DEFAULT 0;
    DECLARE m_instance_id INT DEFAULT 0;

    DECLARE c_i CURSOR FOR 
      SELECT i.cloud_id,i.id,i.template_id FROM cloud.VMInstance i
		INNER JOIN cloud.VMTemplate_VMInstance ti ON i.template_id=ti.VMTemplate_id AND i.id=ti.instances_id
		INNER JOIN cloud.VMTemplate t ON i.template_id=t.id
		WHERE t.parent_id=parentId;
       
    DECLARE CONTINUE HANDLER FOR SQLSTATE '02000' SET done = 1;

    SET TRANSACTION ISOLATION LEVEL READ UNCOMMITTED;
    START TRANSACTION;
   
    OPEN c_i;
    REPEAT
       FETCH c_i INTO m_cloud_id,m_instance_id,m_template_id;
       IF NOT done THEN
         INSERT INTO metric.ContainerMembership(container_id, cloud_id, service_instance_id, instance_id, template_id) 
             values(parentId, m_cloud_id, 0, m_instance_id, m_template_id);
       END IF;
    UNTIL done END REPEAT;
    COMMIT;
END $$
    
DROP PROCEDURE IF EXISTS UpdateContainerServiceInstances$$

CREATE PROCEDURE UpdateContainerServiceInstances(IN parentId INT(11))
BEGIN
    DECLARE done INT DEFAULT 0;
    DECLARE m_service_instance_id INT DEFAULT 0;

    DECLARE c_i CURSOR FOR 
      SELECT i.id FROM cloud.VMServiceInstance i WHERE i.parent_id=parentId and i.deleted=0;

    DECLARE CONTINUE HANDLER FOR SQLSTATE '02000' SET done = 1;

    SET TRANSACTION ISOLATION LEVEL READ UNCOMMITTED;
    START TRANSACTION;

    OPEN c_i;
    REPEAT
       FETCH c_i INTO m_service_instance_id;
       IF NOT done THEN
         INSERT INTO metric.ContainerMembership(container_id, cloud_id, service_instance_id, instance_id, template_id) 
             values(parentId, 0, m_service_instance_id, 0, 0);
       END IF;
    UNTIL done END REPEAT;
    COMMIT;
END $$

DROP PROCEDURE IF EXISTS UpdateContainerStackTemplates$$
 
CREATE PROCEDURE UpdateContainerStackTemplates(IN parentId INT(11))
BEGIN
    DECLARE done INT DEFAULT 0;
    DECLARE m_cloud_id INT DEFAULT 0;
    DECLARE m_template_id INT DEFAULT 0;

    DECLARE c_i CURSOR FOR 
      SELECT t.cloud_id,t.id FROM cloud.VMTemplate t
		INNER JOIN cloud.VMStack s ON t.parent_id=s.parent_id
		WHERE s.parent_id=parentId AND t.cloud_id IS NOT NULL and s.deleted=0;
       
    DECLARE CONTINUE HANDLER FOR SQLSTATE '02000' SET done = 1;

    SET TRANSACTION ISOLATION LEVEL READ UNCOMMITTED;
    START TRANSACTION;
   
    OPEN c_i;
    REPEAT
       FETCH c_i INTO m_cloud_id,m_template_id;
       IF NOT done THEN
         INSERT INTO metric.ContainerMembership(container_id, cloud_id, service_instance_id, instance_id, template_id) 
             values(parentId, m_cloud_id, 0, 0, m_template_id);
       END IF;
    UNTIL done END REPEAT;
    COMMIT;
END $$
		
DROP PROCEDURE IF EXISTS UpdateContainerStackInstances$$
	    
CREATE PROCEDURE UpdateContainerStackInstances(IN parentId INT(11))
BEGIN
    DECLARE done INT DEFAULT 0;
    DECLARE m_cloud_id INT DEFAULT 0;
    DECLARE m_template_id INT DEFAULT 0;
    DECLARE m_instance_id INT DEFAULT 0;

    DECLARE c_i CURSOR FOR 
      SELECT i.cloud_id,i.id,i.template_id FROM cloud.VMInstance i
		INNER JOIN cloud.VMTemplate t ON i.template_id=t.id
		INNER JOIN cloud.VMStack s ON t.parent_id=s.parent_id
		WHERE s.parent_id=parentId and s.deleted=0;
       
    DECLARE CONTINUE HANDLER FOR SQLSTATE '02000' SET done = 1;

    SET TRANSACTION ISOLATION LEVEL READ UNCOMMITTED;
    START TRANSACTION;
   
    OPEN c_i;
    REPEAT
       FETCH c_i INTO m_cloud_id,m_instance_id,m_template_id;
       IF NOT done THEN
         INSERT INTO metric.ContainerMembership(container_id, cloud_id, service_instance_id, instance_id, template_id) 
             values(parentId, m_cloud_id, 0, m_instance_id, m_template_id);
       END IF;
    UNTIL done END REPEAT;
    COMMIT;
END $$

DELIMITER ;