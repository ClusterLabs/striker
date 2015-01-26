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

DROP SCHEMA IF EXISTS history cascade;
DROP TYPE   IF EXISTS status  cascade;
DROP TYPE   IF EXISTS mode    cascade;
DROP TYPE   IF EXISTS level   cascade;

DROP FUNCTION  IF EXISTS history_node();

-- ----------------------------------------------------------------------
-- End of File
