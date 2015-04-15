-- This is the core database schema for ScanCore.

SET client_encoding       = 'UTF8';
SET check_function_bodies = false;
SET client_min_messages   = warning;
CREATE LANGUAGE plpgsql;

CREATE SCHEMA history;
ALTER SCHEMA history OWNER to #!variable!user!#;

CREATE TABLE nodes (
	node_id		serial				primary key,
	node_fqdn	text,
	node_bcn_ip	text,								-- Might want to make this inet or cidr later.
	node_ifn_ip	text,								-- Might want to make this inet or cidr later.
	node_status	text,
	modified_user	integer				not null	default 1,
	modified_date	timestamp with time zone	not null	default now()
);
ALTER TABLE nodes OWNER TO #!variable!user!#;

CREATE TABLE history.nodes (
	node_id		serial,
	history_id	serial,
	node_fqdn	text,
	node_bcn_ip	text,								-- Might want to make this inet or cidr later.
	node_ifn_ip	text,								-- Might want to make this inet or cidr later.
	node_status	text,
	modified_user	int				not null	default 1,
	modified_date	timestamp with time zone	not null	default now()
);
ALTER TABLE history.nodes OWNER TO #!variable!user!#;

CREATE FUNCTION history_nodes() RETURNS trigger
AS $$
DECLARE
	history_nodes RECORD;
BEGIN
	SELECT INTO history_nodes * FROM nodes WHERE node_id=new.node_id;
	INSERT INTO history.nodes
		(node_id,
		node_fqdn,
		node_bcn_ip,
		node_ifn_ip,
		node_status,
		modified_user,
		modified_date)
	VALUES
		(history_nodes.node_id,
		history_nodes.node_fqdn,
		history_nodes.node_bcn_ip,
		history_nodes.node_ifn_ip,
		history_nodes.node_status,
		history_nodes.modified_user,
		history_nodes.modified_user);
	RETURN NULL;
END;
$$
LANGUAGE plpgsql;
ALTER FUNCTION history_nodes() OWNER TO #!variable!user!#;

CREATE TRIGGER trigger_nodes
	AFTER INSERT OR UPDATE ON nodes
	FOR EACH ROW EXECUTE PROCEDURE history_nodes();
