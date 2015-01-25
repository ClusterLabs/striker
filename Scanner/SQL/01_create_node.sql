\echo To load this file: psql -U postgres -d scanner -f create_node.sql
\echo Drop existing instances to create new and clean

--DROP EXTENSION IF EXISTS plpgsql      cascade;

DROP TABLE  IF EXISTS node	      	cascade;
DROP TABLE  IF EXISTS alerts	      	cascade;
DROP TABLE  IF EXISTS agent_data      	cascade;
DROP TABLE  IF EXISTS alert_listeners   cascade;
DROP TABLE  IF EXISTS snmp_apc_ups      cascade;
DROP TABLE  IF EXISTS ipmi_temp	      	cascade;
DROP TABLE  IF EXISTS raid_temp	      	cascade;
DROP TABLE  IF EXISTS node_node_id_seq	      cascade;
DROP TABLE  IF EXISTS alert_listeners_id_seq  cascade;
DROP TABLE  IF EXISTS snmp_apc_ups_id_seq     cascade;
DROP TABLE  IF EXISTS ipmi_temp_id_seq	      cascade;
DROP TABLE  IF EXISTS raid_temp_id_seq	      cascade;
DROP TABLE  IF EXISTS history.node    		cascade;
DROP TABLE  IF EXISTS history.alert_listeners	cascade;
DROP TABLE  IF EXISTS history.snmp_apc_ups	cascade;
DROP TABLE  IF EXISTS history.ipmi_temp		cascade;
DROP TABLE  IF EXISTS history.raid_temp		cascade;

DROP SCHEMA IF EXISTS history	      cascade;
DROP TYPE   IF EXISTS status;
DROP TYPE   IF EXISTS mode;

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

ALTER TABLE node OWNER TO alteeve;

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

ALTER TABLE history.node OWNER TO alteeve;

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

 ALTER FUNCTION history_node() OWNER TO alteeve;

\echo Create trigger trigger_node using function history_nodes

CREATE TRIGGER trigger_node 
       AFTER INSERT OR UPDATE ON node 
       FOR EACH ROW EXECUTE PROCEDURE history_node();


\echo Create an enum data type for the status field.
CREATE TYPE status AS ENUM ( 'OK', 'DEBUG', 'WARNING', 'CRISIS', 'DEAD' );

