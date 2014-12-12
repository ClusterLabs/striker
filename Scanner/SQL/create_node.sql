\echo To load this file: psql -U postgres -d scanner -f create_node.sql
\echo Drop existing instances to create new and clean

DROP EXTENSION IF EXISTS plpgsql      cascade;

DROP TABLE  IF EXISTS node	      cascade;
DROP TABLE  IF EXISTS history.node    cascade;
DROP SCHEMA IF EXISTS history	      cascade;
DROP TYPE   IF EXISTS status;

DROP FUNCTION  IF EXISTS history_node();

\echo Global settings

SET client_encoding = 'UTF8';
SET check_function_bodies = false;
SET client_min_messages = warning;
CREATE LANGUAGE plpgsql;

CREATE SCHEMA history;
ALTER SCHEMA history OWNER to alteeve;

\echo Create table node

CREATE TABLE node (
node_id		serial	primary key ,
node_name	text	not null,-- I break the short name off of the FQDN
node_description text,
pid             int,
status          text,
modified_user	int	not null,
modified_date	timestamp with time zone	not null	default now()
);

ALTER TABLE node OWNER TO alteeve;

\echo Create table history.node

CREATE TABLE history.node (
node_id		bigint,
node_name	text	not null,	-- I break the short name off of the FQDN
node_description text,
pid             int,
status          text,
history_id	serial  primary key,
modified_user	int	not null,
modified_date	timestamp with time zone	not null	default now()
);

ALTER TABLE node OWNER TO alteeve;

\echo Create function history_nodes to populate history.node from node

CREATE FUNCTION history_node() RETURNS trigger
AS $$
DECLARE
	hist_node RECORD;
BEGIN
	SELECT INTO hist_node * FROM node WHERE node_id=new.node_id;
	INSERT INTO history.node
		(node_id,
		 node_name,
		 node_description,
                 pid,
		 status,
		 modified_user)
	VALUES
		(hist_node.node_id,
		 hist_node.node_name,
		 hist_node.node_description,
                 hist_node.pid,
		 hist_node.status,
		 hist_node.modified_user);
	RETURN NULL;
END;
$$
LANGUAGE plpgsql;

 ALTER FUNCTION history_node() OWNER TO alteeve;

\echo Create trigger trigger_node using function history_nodes

-- CREATE TRIGGER trigger_node 
-- AFTER INSERT OR UPDATE ON node 
-- FOR EACH ROW EXECUTE PROCEDURE history_node();


\echo Create an enum data type for the status field.
CREATE TYPE status AS ENUM ( 'OK', 'DEBUG', 'WARNING', 'CRISIS' );

