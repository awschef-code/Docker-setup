use cloud;

CREATE TABLE IF NOT EXISTS `ProcessInstanceInfo` (
  `InstanceId` bigint(20) NOT NULL AUTO_INCREMENT,
  `lastModificationDate` datetime DEFAULT NULL,
  `lastReadDate` datetime DEFAULT NULL,
  `processId` varchar(255) DEFAULT NULL,
  `processInstanceByteArray` longblob,
  `startDate` datetime DEFAULT NULL,
  `state` int(11) NOT NULL,
  `OPTLOCK` int(11) DEFAULT NULL,
  PRIMARY KEY (`InstanceId`)
) ENGINE=InnoDB;

CREATE TABLE IF NOT EXISTS `EventTypes` (
  `InstanceId` bigint(20) NOT NULL,
  `eventTypes` varchar(255) DEFAULT NULL,
  `id` int(11) NOT NULL AUTO_INCREMENT,
  PRIMARY KEY (`id`),
  KEY `FKB0E5621F7665489A` (`InstanceId`),
  CONSTRAINT `FKB0E5621F7665489A` FOREIGN KEY (`InstanceId`) REFERENCES `ProcessInstanceInfo` (`InstanceId`)
) ENGINE=InnoDB;
