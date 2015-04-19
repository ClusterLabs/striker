\echo To load this file: psql -U postgres -d scanner -f create_node.sql
\echo Drop existing instances to create new and clean

\echo Global settings

SET client_encoding = 'UTF8';
SET check_function_bodies = false;
SET client_min_messages = warning;
CREATE LANGUAGE plpgsql;

CREATE SCHEMA history;
ALTER SCHEMA history OWNER to striker;

\echo Create table node

CREATE TABLE node (
node_id		serial	primary key ,
agent_name	text	not null,-- I break the short name off of the FQDN
agent_host      text,
pid             int,
target_name     text,
target_type     text,
target_ip       text,
status          text,
modified_user	int	not null,
modified_date	timestamp with time zone	not null	default now()
);

ALTER TABLE node OWNER TO striker;

\echo Create table history.node

CREATE TABLE history.node (
node_id		bigint,
agent_name	text	not null,	-- I break the short name off of the FQDN
agent_host      text,
pid             int,
target_name     text,
target_type     text,
target_ip       text,
status          text,
history_id	serial  primary key,
modified_user	int	not null,
modified_date	timestamp with time zone	not null	default now()
);

ALTER TABLE history.node OWNER TO striker;

\echo Create function history_nodes to populate history.node from node

CREATE FUNCTION history_node() RETURNS trigger
AS $$
DECLARE
	hist_node RECORD;
BEGIN
	SELECT INTO hist_node * FROM node WHERE node_id=new.node_id;
	INSERT INTO history.node
		(node_id,
		 agent_name,
		 agent_host,
                 pid,
		 target_name,
                 target_type,
                 target_ip,
		 status,
		 modified_user)
	VALUES
		(hist_node.node_id,
		 hist_node.agent_name,
		 hist_node.agent_host,
                 hist_node.pid,
                 hist_node.target_name,
                 hist_node.target_type,
                 hist_node.target_ip,
		 hist_node.status,
		 hist_node.modified_user);
	RETURN NULL;
END;
$$
LANGUAGE plpgsql;

 ALTER FUNCTION history_node() OWNER TO striker;

\echo Create trigger trigger_node using function history_nodes

CREATE TRIGGER trigger_node 
       AFTER INSERT OR UPDATE ON node 
       FOR EACH ROW EXECUTE PROCEDURE history_node();


\echo Create an enum data type for the status field.
\echo Ordinary agent readings use OK, DEBUG, WARNING or CRISIS.
\echo Node Servers may be DEAD, TIMEOUT or OK.
\echo AUTO BOOT may be TRUE or FALSE.

CREATE TYPE status AS ENUM ( 'OK', 'DEBUG', 'WARNING', 'CRISIS', 'DEAD', 'TIMEOUT', 'TRUE', 'FALSE' );

-- ----------------------------------------------------------------------
-- End of File
