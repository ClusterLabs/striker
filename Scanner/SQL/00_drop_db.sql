\echo To load this file: psql -U postgres -d template1 -f 00_drop_db
\echo Drop existing instances to create new and clean
\echo NOTE: May need to  sudo service postgresql restart
\echo       if DB reports connections to the DB.

DROP DATABASE IF EXISTS scanner ;
CREATE DATABASE scanner WITH OWNER striker;
-- ----------------------------------------------------------------------
-- End of File
