-- This is the database schema for the 'remote-access Scan Agent'.

CREATE TABLE apc_pdus (
	apc_pdu_uuid				uuid				primary key,	-- This is set by the target, not by us!
	apc_pdu_host_uuid			uuid				not null,
	apc_pdu_serial_number			text				not null,
	apc_pdu_model_number			text				not null,
	apc_pdu_manufacture_date		text,
	apc_pdu_firmware_version		text,
	apc_pdu_hardware_version		text,
	apc_pdu_ipv4_address			text				not null,
	apc_pdu_mac_address			text				not null,
	apc_pdu_mtu_size			numeric				not null,
	apc_pdu_link_speed			numeric				not null,	-- in bits-per-second, set to '0' when we lose access
	apc_pdu_phase_count			numeric				not null,
	apc_pdu_outlet_count			numeric				not null,
	apc_pdu_note				text,
	modified_date				timestamp with time zone	not null,
	
	FOREIGN KEY(apc_pdu_host_uuid) REFERENCES hosts(host_uuid)
);
ALTER TABLE apc_pdus OWNER TO #!variable!user!#;

CREATE TABLE history.apc_pdus (
	history_id				bigserial,
	apc_pdu_uuid				uuid,
	apc_pdu_host_uuid			uuid,
	apc_pdu_serial_number			text,
	apc_pdu_model_number			text,
	apc_pdu_manufacture_date		text,
	apc_pdu_firmware_version		text,
	apc_pdu_hardware_version		text,
	apc_pdu_ipv4_address			text,
	apc_pdu_mac_address			text,
	apc_pdu_mtu_size			numeric,
	apc_pdu_link_speed			numeric,
	apc_pdu_phase_count			numeric,
	apc_pdu_outlet_count			numeric,
	apc_pdu_note				text,
	modified_date				timestamp with time zone	not null
);
ALTER TABLE history.apc_pdus OWNER TO #!variable!user!#;

CREATE FUNCTION history_apc_pdus() RETURNS trigger
AS $$
DECLARE
	history_apc_pdus RECORD;
BEGIN
	SELECT INTO history_apc_pdus * FROM apc_pdus WHERE apc_pdu_uuid=new.apc_pdu_uuid;
	INSERT INTO history.apc_pdus
		(apc_pdu_uuid,
		 apc_pdu_host_uuid, 
		 apc_pdu_serial_number, 
		 apc_pdu_model_number, 
		 apc_pdu_manufacture_date, 
		 apc_pdu_firmware_version, 
		 apc_pdu_hardware_version, 
		 apc_pdu_ipv4_address, 
		 apc_pdu_mac_address, 
		 apc_pdu_mtu_size, 
		 apc_pdu_link_speed, 
		 apc_pdu_phase_count, 
		 apc_pdu_outlet_count, 
		 apc_pdus_note, 
		 modified_date)
	VALUES
		(history_apc_pdus.apc_pdu_uuid,
		 history_apc_pdus.apc_pdu_host_uuid, 
		 history_apc_pdus.apc_pdu_serial_number, 
		 history_apc_pdus.apc_pdu_model_number, 
		 history_apc_pdus.apc_pdu_manufacture_date, 
		 history_apc_pdus.apc_pdu_firmware_version, 
		 history_apc_pdus.apc_pdu_hardware_version, 
		 history_apc_pdus.apc_pdu_ipv4_address, 
		 history_apc_pdus.apc_pdu_mac_address, 
		 history_apc_pdus.apc_pdu_mtu_size, 
		 history_apc_pdus.apc_pdu_link_speed, 
		 history_apc_pdus.apc_pdu_phase_count, 
		 history_apc_pdus.apc_pdu_outlet_count, 
		 history_apc_pdus.apc_pdus_note, 
		 history_apc_pdus.modified_date);
	RETURN NULL;
END;
$$
LANGUAGE plpgsql;
ALTER FUNCTION history_apc_pdus() OWNER TO #!variable!user!#;

CREATE TRIGGER trigger_apc_pdus
	AFTER INSERT OR UPDATE ON apc_pdus
	FOR EACH ROW EXECUTE PROCEDURE history_apc_pdus();


-- Phases on the PDU
CREATE TABLE apc_pdu_phases (
	apc_pdu_phase_uuid			uuid				primary key,
	apc_pdu_phase_apc_pdu_uuid		uuid				not null,
	apc_pdu_phase_host_uuid			uuid				not null,
	apc_pdu_phase_number			text				not null,
	apc_pdu_phase_current_amperage		numeric				not null,	-- Max, low/high warn and high critical will be read from the PDU in the given pass.
	apc_pdu_phase_max_amperage		numeric,
	apc_pdu_phase_note			text,						-- Set to 'DELETED' if it goes away
	modified_date				timestamp with time zone	not null,
	
	FOREIGN KEY(apc_pdu_phase_apc_pdu_uuid) REFERENCES apc_pdus(apc_pdu_uuid)
);
ALTER TABLE apc_pdu_phases OWNER TO #!variable!user!#;

CREATE TABLE history.apc_pdu_phases (
	history_id				bigserial,
	apc_pdu_phase_uuid			uuid,
	apc_pdu_phase_apc_pdu_uuid		uuid,
	apc_pdu_phase_host_uuid			uuid,
	apc_pdu_phase_number			text,
	apc_pdu_phase_current_amperage		numeric,
	apc_pdu_phase_max_amperage		numeric,
	apc_pdu_phase_note			text,
	modified_date				timestamp with time zone
);
ALTER TABLE history.apc_pdu_phases OWNER TO #!variable!user!#;

CREATE FUNCTION history_apc_pdu_phases() RETURNS trigger
AS $$
DECLARE
	history_apc_pdu_phases RECORD;
BEGIN
	SELECT INTO history_apc_pdu_phases * FROM apc_pdu_phases WHERE apc_pdu_phase_uuid=new.apc_pdu_phase_uuid;
	INSERT INTO history.apc_pdu_phases
		(apc_pdu_phase_uuid, 
		 apc_pdu_phase_apc_pdu_uuid,
		 apc_pdu_phase_host_uuid,
		 apc_pdu_phase_number, 
		 apc_pdu_phase_current_amperage, 
		 apc_pdu_phase_max_amperage, 
		 apc_pdu_phase_note, 
		 modified_date)
	VALUES
		(history_apc_pdu_phases.apc_pdu_phase_uuid,
		 history_apc_pdu_phases.apc_pdu_phase_apc_pdu_uuid,
		 history_apc_pdu_phases.apc_pdu_phase_host_uuid,
		 history_apc_pdu_phases.apc_pdu_phase_number, 
		 history_apc_pdu_phases.apc_pdu_phase_current_amperage, 
		 history_apc_pdu_phases.apc_pdu_phase_max_amperage, 
		 history_apc_pdu_phases.apc_pdu_phase_note, 
		 history_apc_pdu_phases.modified_date);
	RETURN NULL;
END;
$$
LANGUAGE plpgsql;
ALTER FUNCTION history_apc_pdu_phases() OWNER TO #!variable!user!#;

CREATE TRIGGER trigger_apc_pdu_phases
	AFTER INSERT OR UPDATE ON apc_pdu_phases
	FOR EACH ROW EXECUTE PROCEDURE history_apc_pdu_phases();



-- Phases on the PDU
CREATE TABLE apc_pdu_outlets (
	apc_pdu_outlet_uuid			uuid				primary key,
	apc_pdu_outlet_apc_pdu_uuid		uuid				not null,
	apc_pdu_outlet_host_uuid		uuid				not null,
	apc_pdu_outlet_number			text				not null,
	apc_pdu_outlet_name			text,
	apc_pdu_outlet_on_phase			text				not null,
	apc_pdu_outlet_state			text,						-- on / off
	apc_pdu_outlet_note			text,						-- Set to 'DELETED' if it goes away
	modified_date				timestamp with time zone	not null,
	
	FOREIGN KEY(apc_pdu_outlet_apc_pdu_uuid) REFERENCES apc_pdus(apc_pdu_uuid)
);
ALTER TABLE apc_pdu_outlets OWNER TO #!variable!user!#;

CREATE TABLE history.apc_pdu_outlets (
	history_id				bigserial,
	apc_pdu_outlet_uuid			uuid,
	apc_pdu_outlet_apc_pdu_uuid		uuid,
	apc_pdu_outlet_host_uuid		uuid,
	apc_pdu_outlet_number			text,
	apc_pdu_outlet_name			text,
	apc_pdu_outlet_on_phase			text,
	apc_pdu_outlet_state			text,
	apc_pdu_outlet_note			text,
	modified_date				timestamp with time zone
);
ALTER TABLE history.apc_pdu_outlets OWNER TO #!variable!user!#;

CREATE FUNCTION history_apc_pdu_outlets() RETURNS trigger
AS $$
DECLARE
	history_apc_pdu_outlets RECORD;
BEGIN
	SELECT INTO history_apc_pdu_outlets * FROM apc_pdu_outlets WHERE apc_pdu_outlet_uuid=new.apc_pdu_outlet_uuid;
	INSERT INTO history.apc_pdu_outlets
		(apc_pdu_outlet_uuid, 
		 apc_pdu_outlet_apc_pdu_uuid,
		 apc_pdu_outlet_host_uuid,
		 apc_pdu_outlet_number, 
		 apc_pdu_outlet_name, 
		 apc_pdu_outlet_on_phase, 
		 apc_pdu_outlet_state, 
		 apc_pdu_outlet_note, 
		 modified_date)
	VALUES
		(history_apc_pdu_outlets.apc_pdu_outlet_uuid,
		 history_apc_pdu_outlets.apc_pdu_outlet_apc_pdu_uuid,
		 history_apc_pdu_outlets.apc_pdu_outlet_host_uuid,
		 history_apc_pdu_outlets.apc_pdu_outlet_number, 
		 history_apc_pdu_outlets.apc_pdu_outlet_name, 
		 history_apc_pdu_outlets.apc_pdu_outlet_on_phase, 
		 history_apc_pdu_outlets.apc_pdu_outlet_state, 
		 history_apc_pdu_outlets.apc_pdu_outlet_note, 
		 history_apc_pdu_outlets.modified_date);
	RETURN NULL;
END;
$$
LANGUAGE plpgsql;
ALTER FUNCTION history_apc_pdu_outlets() OWNER TO #!variable!user!#;

CREATE TRIGGER trigger_apc_pdu_outlets
	AFTER INSERT OR UPDATE ON apc_pdu_outlets
	FOR EACH ROW EXECUTE PROCEDURE history_apc_pdu_outlets();


-- This stores various variables found for a given controller but not explicitely checked for (or that 
-- change frequently).
CREATE TABLE apc_pdu_variables (
	apc_pdu_variable_uuid		uuid				primary key,
	apc_pdu_variable_host_uuid	uuid				not null,
	apc_pdu_variable_source_table	text				not null,
	apc_pdu_variable_source_uuid	uuid				not null,
	apc_pdu_variable_is_temperature	boolean				not null	default FALSE,
	apc_pdu_variable_name		text				not null,
	apc_pdu_variable_value		text,
	modified_date					timestamp with time zone	not null,
	
	FOREIGN KEY(apc_pdu_variable_host_uuid) REFERENCES hosts(host_uuid)
);
ALTER TABLE apc_pdu_variables OWNER TO #!variable!user!#;

CREATE TABLE history.apc_pdu_variables (
	history_id			bigserial,
	apc_pdu_variable_uuid		uuid,
	apc_pdu_variable_host_uuid	uuid,
	apc_pdu_variable_source_table	text,
	apc_pdu_variable_source_uuid	uuid,
	apc_pdu_variable_is_temperature	boolean,
	apc_pdu_variable_name		text,
	apc_pdu_variable_value		text,
	modified_date					timestamp with time zone
);
ALTER TABLE history.apc_pdu_variables OWNER TO #!variable!user!#;

CREATE FUNCTION history_apc_pdu_variables() RETURNS trigger
AS $$
DECLARE
	history_apc_pdu_variables RECORD;
BEGIN
	SELECT INTO history_apc_pdu_variables * FROM apc_pdu_variables WHERE apc_pdu_variable_uuid=new.apc_pdu_variable_uuid;
	INSERT INTO history.apc_pdu_variables
		(apc_pdu_variable_uuid, 
		 apc_pdu_variable_host_uuid, 
		 apc_pdu_variable_source_table, 
		 apc_pdu_variable_source_uuid, 
		 apc_pdu_variable_is_temperature,
		 apc_pdu_variable_name,
		 apc_pdu_variable_value,
		 modified_date)
	VALUES
		(history_apc_pdu_variables.apc_pdu_variable_uuid,
		 history_apc_pdu_variables.apc_pdu_variable_host_uuid, 
		 history_apc_pdu_variables.apc_pdu_variable_source_table, 
		 history_apc_pdu_variables.apc_pdu_variable_source_uuid, 
		 history_apc_pdu_variables.apc_pdu_variable_is_temperature,
		 history_apc_pdu_variables.apc_pdu_variable_name,
		 history_apc_pdu_variables.apc_pdu_variable_value,
		 history_apc_pdu_variables.modified_date);
	RETURN NULL;
END;
$$
LANGUAGE plpgsql;
ALTER FUNCTION history_apc_pdu_variables() OWNER TO #!variable!user!#;

CREATE TRIGGER trigger_apc_pdu_variables
	AFTER INSERT OR UPDATE ON apc_pdu_variables
	FOR EACH ROW EXECUTE PROCEDURE history_apc_pdu_variables();
