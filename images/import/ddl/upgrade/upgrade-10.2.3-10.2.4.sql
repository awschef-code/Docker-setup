-- this script upgrades the agility Algorithm
-- from values NULL or 'PBKDF2WithHmacSHA1'
-- to                  'PBKDF2WithHmacSHA256'
-- if another value was set the script does not change it

USE cloud;

DELIMITER $$
DROP PROCEDURE IF EXISTS Migrate_Security_Algorithm_to_SHA2 $$
CREATE PROCEDURE Migrate_Security_Algorithm_to_SHA2()
BEGIN
	SELECT min(id)
	FROM   cloud.VMProperty
	WHERE  name    = 'Security.Digest.Algorithm'
	AND    ((value = 'PBKDF2WithHmacSHA1') OR (value = '') OR (value IS NULL))
	INTO @algorithm_id;
	IF (@algorithm_id IS NOT NULL) THEN
		UPDATE cloud.VMProperty  SET value = 'PBKDF2WithHmacSHA256' WHERE id = @algorithm_id;
	END IF;
END $$
DELIMITER ;
CALL Migrate_Security_Algorithm_to_SHA2();

COMMIT;
