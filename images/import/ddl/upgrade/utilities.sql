-- This file is to allow attempts to include utilities.sql in files such as
-- ../networkServiceTypeProperties.sql to work even when the current working
-- directory of mysql is in this directory, as it is for upgrades, instead of
-- the parent directory.  It's unfortunate in mysql that paths are relative to
-- the CWD of the process instead of the including file.

-- TODO: Find a better solution such as reworking all of the SQL files so that
-- they are always run with the same CWD.  A good CWD might be the parent "ddl"
-- directory.

SOURCE ../utilities.sql;
