SOURCE ../utilities.sql

CALL insertProperty('Authentication.ContinueOnAuthenticationFailures','Attempt to authenticate until successful or all providers have been attempted.','false',false,true);
CALL insertProperty('AgilityManager.vSphere.FailFastIPAddrTimeout', 'Time to wait in seconds for an instance to get a valid IP address after an invalid one has been found.', '300', false, false);
CALL insertProperty('AgilityManager.HostnamePreventDuplicates', 'If true this will take into account previously released instance hostnames when formulating new hostnames', 'false', false, false);

CALL create_setup_property('AgilityPlatform.UI.CustomActions.Menu', 'Custom Actions menu title.', 'Custom', false);

-- Remove infoblox service type

SELECT id FROM VMServiceProviderType WHERE name='InfoBloxDDI' INTO @infobloxDDIType;
UPDATE VMServiceProvider SET type_id=null WHERE type_id=@infobloxDDIType;
DELETE FROM VMServiceProviderType_AssetProperty WHERE VMServiceProviderType_id=@infobloxDDIType;
SELECT id FROM AssetType WHERE name='InfobloxDDI' INTO @infobloxDDIAT;
DELETE FROM AssetType_PropertyDefinition where AssetType_id=@infobloxDDIAT;
DELETE FROM AssetType where id=@infobloxDDIAT;
DELETE FROM VMServiceProviderType WHERE id=@infobloxDDIType;

-- Remove any duplicate rows in Policy table that are both marked latest for DE1875.
DELETE p1 FROM VMPolicy p1, VMPolicy p2 WHERE p1.id > p2.id AND p1.name = p2.name and p1.latest = true and p2.latest = true and p1.slot_id = p2.slot_id;

-- Converting MEMORY tables to InnoDB tables. 
ALTER TABLE metric.ContainerMembership ENGINE=Innodb;
ALTER TABLE metric.query_items ENGINE=Innodb;
ALTER TABLE metric.query_metric_items ENGINE=Innodb;
ALTER TABLE metric.report_query_metric_items ENGINE=Innodb;
ALTER TABLE event.AssetMembership ENGINE=Innodb;
