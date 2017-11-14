--
-- This scripts earlier existed as part of upgrade-9.1.1-9.1.2.sql. These scripts where never included as part of the upgrade. Added them back
--


source utilities.sql
source ../insertProperty.sql

select max(id)+1 FROM VMProperty into @nextId;
INSERT INTO VMProperty (id,name,description,value,overridable) (
    select @nextId, 'Security.ExpireAuthTokenWindow','Authentication token expiration timeout in minutes.','1440',false
  FROM   dual
  WHERE NOT EXISTS (
    SELECT * FROM VMProperty
    WHERE name = 'Security.ExpireAuthTokenWindow'));

SELECT id from VMProperty where name = 'Security.ExpireAuthTokenWindow' into @propId;

INSERT INTO VMConfig_properties (VMConfig_id, VMProperty_id) (
    select 1,@propId
  FROM   dual
  WHERE NOT EXISTS (
    SELECT * FROM VMConfig_properties
    WHERE VMConfig_id = 1 and VMProperty_id = @propId));

--
-- Add WinRM port firewall policy
--
DELIMITER $$
DROP PROCEDURE IF EXISTS add_winrm_port_policy$$
CREATE PROCEDURE add_winrm_port_policy()
BEGIN
    SELECT id FROM Slot WHERE UUID='4ae1f03f-5538-4444-9b4e-f792f59156c7' INTO @slotId;
    IF @slotId IS NULL THEN
      SELECT id FROM VMContainer WHERE uuid='#TOP#' INTO @rootId;
      SELECT id FROM VMPolicyType WHERE name='Firewall' INTO @networkAclType;
      SELECT max(id)+1 FROM VMPolicy INTO @nextPolicyId;

      INSERT INTO VMPolicy (id,uuid,name,description,type_id,filter,definition,parent_id, version,latest,slot_id,publishComment,publisher_id) VALUES
      (@nextPolicyId, UUID(), "Agility_DefaultWinRM-Inbound", "Input ports required to be open for communication with Agility for WinRM instances", @networkAclType, null,
"<AccessList>
   <direction>Input</direction>
   <protocols>
     <name>Agility_Default_Inbound_WinRM</name>
     <description>Agility_Default_Inbound_WinRM</description>
     <minPort>5986</minPort>
     <maxPort>5986</maxPort>
     <protocol>tcp</protocol>
     <prefixes>0.0.0.0/0</prefixes>
     <allowed>true</allowed>
   </protocols>
   <protocols>
     <name>Agility_Default_Inbound_DHCP</name>
     <description>Agility_Default_Inbound_DHCP</description>
     <minPort>68</minPort>
     <maxPort>68</maxPort>
     <protocol>udp</protocol>
     <prefixes>0.0.0.0/0</prefixes>
     <allowed>true</allowed>
   </protocols>
 </AccessList>", @rootId, 1, 1, next_slot("4ae1f03f-5538-4444-9b4e-f792f59156c7"), "Default Installation", 1);
  END IF;
END $$

DELIMITER ;

CALL add_winrm_port_policy();

DROP PROCEDURE IF EXISTS add_winrm_port_policy;


-- Upgrade 9.1.1 database to 9.1.2
use cloud;

--
--  Add property to define Debug Diagnostics Directory
--
CALL insertProperty('DiagnosticsDumpDir','Directory used for Debug Diagnostics Dumps','/var/spool/agility/diagnostics',false,false);
--
--  Add property to allow configurable EC2 retries
--
CALL insertProperty('AgilityManager.EC2.PollRetries','Number of retry attempts while waiting for EC2 Operation to finish','90',false,false);

-- change columns types to support change from SHA1 to SHA256
ALTER TABLE cloud.VMAuthToken MODIFY COLUMN token    TEXT;
ALTER TABLE cloud.AuditLog    MODIFY COLUMN itemName TEXT;
