--
-- MySQL upgrade script from 10.2.4 to 10.2.5
--

-- DE2185: Mark default firewall policies as not removable
-- Agility_Default-Inbound
SELECT id FROM Slot WHERE uuid='c0211eee-9b6e-4d1c-9a29-4bbe8304ea89' INTO @fw_slot_id;
UPDATE VMPolicy SET removable=false WHERE slot_id=@fw_slot_id AND deleted=false;
-- Agility_Default-WinRM-Inbound
SELECT id FROM Slot WHERE uuid='4ae1f03f-5538-4444-9b4e-f792f59156c7' INTO @fw_slot_id;
UPDATE VMPolicy SET removable=false WHERE slot_id=@fw_slot_id AND deleted=false;
-- Agility_Default-Outbound
SELECT id FROM Slot WHERE uuid='02c903b6-d20b-4e38-ad5c-b7fba9c569fd' INTO @fw_slot_id;
UPDATE VMPolicy SET removable=false WHERE slot_id=@fw_slot_id AND deleted=false;
