\echo To load this file: psql -U postgres -d template1 -f 00_drop_db
\echo Drop existing instances to create new and clean

DROP DATABASE IF EXISTS scanner ;
CREATE DATABASE scanner WITH OWNER alteeve;
-- ----------------------------------------------------------------------
-- End of File
