-- This is the database schema for the 'bond' scan agent.

CREATE TABLE bond (
	bond_id				bigserial			primary key,
	bond_host_uuid			uuid,
	bond_name			text				not null,
	bond_mode			numeric				not null,	-- This is the numerical bond type (will translate to the user's language in ScanCore)
	bond_primary_slave		text				not null,
	bond_primary_reselect		text				not null,
	bond_active_slave		text				not null,
	bond_mii_status			text				not null,
	bond_mii_polling_interval	numeric,
	bond_up_delay			numeric,
	bond_down_delay			numeric,
	modified_date			timestamp with time zone	not null,
	
	FOREIGN KEY(bond_host_uuid) REFERENCES hosts(host_uuid)
);
ALTER TABLE bond OWNER TO #!variable!user!#;

CREATE TABLE history.bond (
	history_id			bigserial,
	bond_id				bigint,
	bond_host_uuid			uuid,
	bond_name			text				not null,
	bond_mode			numeric				not null,
	bond_primary_slave		text				not null,
	bond_primary_reselect		text				not null,
	bond_active_slave		text				not null,
	bond_mii_status			text				not null,
	bond_mii_polling_interval	numeric,
	bond_up_delay			numeric,
	bond_down_delay			numeric,
	modified_date			timestamp with time zone	not null
);
ALTER TABLE history.bond OWNER TO #!variable!user!#;

CREATE FUNCTION history_bond() RETURNS trigger
AS $$
DECLARE
	history_bond RECORD;
BEGIN
	SELECT INTO history_bond * FROM bond WHERE bond_id=new.bond_id;
	INSERT INTO history.bond
		(bond_id,
		 bond_host_uuid,
		 bond_name, 
		 bond_mode, 
		 bond_primary_slave, 
		 bond_primary_reselect, 
		 bond_active_slave, 
		 bond_mii_status, 
		 bond_mii_polling_interval, 
		 bond_up_delay, 
		 bond_down_delay, 
		 modified_date)
	VALUES
		(history_bond.bond_id,
		 history_bond.bond_host_uuid,
		 history_bond.bond_name, 
		 history_bond.bond_mode, 
		 history_bond.bond_primary_slave, 
		 history_bond.bond_primary_reselect, 
		 history_bond.bond_active_slave, 
		 history_bond.bond_mii_status, 
		 history_bond.bond_mii_polling_interval, 
		 history_bond.bond_up_delay, 
		 history_bond.bond_down_delay, 
		 history_bond.modified_date);
	RETURN NULL;
END;
$$
LANGUAGE plpgsql;
ALTER FUNCTION history_bond() OWNER TO #!variable!user!#;

CREATE TRIGGER trigger_bond
	AFTER INSERT OR UPDATE ON bond
	FOR EACH ROW EXECUTE PROCEDURE history_bond();
	
	
-- This is where information on interfaces is stored
CREATE TABLE bond_interface (
	bond_interface_id		bigserial,
	bond_interface_bond_id		bigint				not null,
	bond_interface_name		text				not null,
	bond_interface_mii_status	text				not null,
	bond_interface_speed		numeric				not null,	-- Speed in bps
	bond_interface_duplex		text				not null,
	bond_interface_failure_count	numeric				not null,
	bond_interface_mac		text				not null,
	bond_interface_slave_queue_id	text,
	modified_date			timestamp with time zone	not null,
	
	FOREIGN KEY(bond_interface_bond_id) REFERENCES bond(bond_id)
);
ALTER TABLE bond_interface OWNER TO #!variable!user!#;

CREATE TABLE history.bond_interface (
	history_id			bigserial,
	bond_interface_id		bigint				not null,
	bond_interface_bond_id		bigint				not null,
	bond_interface_name		text				not null,
	bond_interface_mii_status	text				not null,
	bond_interface_speed		numeric				not null,	-- Speed in bps
	bond_interface_duplex		text				not null,
	bond_interface_failure_count	numeric				not null,
	bond_interface_mac		text				not null,
	bond_interface_slave_queue_id	text,
	modified_date			timestamp with time zone	not null
);
ALTER TABLE history.bond_interface OWNER TO #!variable!user!#;

CREATE FUNCTION history_bond_interface() RETURNS trigger
AS $$
DECLARE
	history_bond_interface RECORD;
BEGIN
	SELECT INTO history_bond_interface * FROM bond_interface WHERE bond_interface_id=new.bond_interface_id;
	INSERT INTO history.bond_interface
		(bond_interface_id,
		 bond_interface_bond_id,
		 bond_interface_name, 
		 bond_interface_mii_status, 
		 bond_interface_speed, 
		 bond_interface_duplex, 
		 bond_interface_failure_count, 
		 bond_interface_mac, 
		 bond_interface_slave_queue_id, 
		 modified_date)
	VALUES
		(history_bond_interface.bond_interface_id,
		 history_bond_interface.bond_interface_bond_id,
		 history_bond_interface.bond_interface_name, 
		 history_bond_interface.bond_interface_mii_status, 
		 history_bond_interface.bond_interface_speed, 
		 history_bond_interface.bond_interface_duplex, 
		 history_bond_interface.bond_interface_failure_count, 
		 history_bond_interface.bond_interface_mac, 
		 history_bond_interface.bond_interface_slave_queue_id, 
		 history_bond_interface.modified_date);
	RETURN NULL;
END;
$$
LANGUAGE plpgsql;
ALTER FUNCTION history_bond_interface() OWNER TO #!variable!user!#;

CREATE TRIGGER trigger_bond_interface
	AFTER INSERT OR UPDATE ON bond_interface
	FOR EACH ROW EXECUTE PROCEDURE history_bond_interface();
