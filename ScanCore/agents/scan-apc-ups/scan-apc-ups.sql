-- This is the database schema for the 'APC UPS Scan Agent'.

CREATE TABLE apc_ups (
	apc_ups_id			bigserial			primary key,
	apc_ups_host_id			biginteger,
	apc_ups_fqdn			text,
	apc_ups_ip			text,
	apc_ups_status			text,
	apc_ups_ac_restore_delay	double precision,
	apc_ups_firmware_version	text,
	apc_ups_health			integer,
	apc_ups_high_transfer_voltage	integer,
	apc_ups_last_transfer_reason	integer,
	apc_ups_low_transger_voltage	integer,
	apc_ups_manufactured_date	text,
	apc_ups_model			text,
	apc_ups_temperature_units	integer,
	apc_ups_serial_number		text,
	apc_ups_nmc_firmware_version	text,
	apc_ups_nmc_serial_number	text,
	apc_ups_nmc_mac_address		text,
	modified_date	timestamp with time zone	not null	default now(),
	
	FOREIGN KEY(apc_ups_host_id) REFERENCES hosts(host_id)
);
ALTER TABLE apc_ups OWNER TO #!variable!user!#;

CREATE TABLE history.apc_ups (
	apc_ups_id			biginteger,
	apc_ups_history_id		bigserial,
	apc_ups_fqdn			text,
	apc_ups_ip			text,
	apc_ups_status			text,
	apc_ups_ac_restore_delay	double precision,
	apc_ups_firmware_version	text,
	apc_ups_health			integer,
	apc_ups_high_transfer_voltage	integer,
	apc_ups_last_transfer_reason	integer,
	apc_ups_low_transger_voltage	integer,
	apc_ups_manufactured_date	text,
	apc_ups_model			text,
	apc_ups_temperature_units	integer,
	apc_ups_serial_number		text,
	apc_ups_nmc_firmware_version	text,
	apc_ups_nmc_serial_number	text,
	apc_ups_nmc_mac_address		text,
	modified_date	timestamp with time zone	not null	default now()
);
ALTER TABLE history.apc_ups OWNER TO #!variable!user!#;

CREATE FUNCTION history_apc_ups() RETURNS trigger
AS $$
DECLARE
	history_apc_ups RECORD;
BEGIN
	SELECT INTO history_apc_ups * FROM apc_ups WHERE apc_ups_id=new.apc_ups_id;
	INSERT INTO history.apc_ups
		(apc_ups_id,
		apc_ups_fqdn,
		apc_ups_bcn_ip,
		apc_ups_ifn_ip,
		apc_ups_status,
		apc_ups_ac_restore_delay, 
		apc_ups_firmware_version, 
		apc_ups_health, 
		apc_ups_high_transfer_voltage, 
		apc_ups_last_transfer_reason, 
		apc_ups_low_transger_voltage, 
		apc_ups_manufactured_date, 
		apc_ups_model, 
		apc_ups_temperature_units, 
		apc_ups_serial_number, 
		apc_ups_nmc_firmware_version,
		apc_ups_nmc_serial_number,
		apc_ups_nmc_mac_address,
		modified_date)
	VALUES
		(history_apc_ups.apc_ups_id,
		history_apc_ups.apc_ups_fqdn,
		history_apc_ups.apc_ups_bcn_ip,
		history_apc_ups.apc_ups_ifn_ip,
		history_apc_ups.apc_ups_status,
		history_apc_ups.apc_ups_ac_restore_delay, 
		history_apc_ups.apc_ups_firmware_version, 
		history_apc_ups.apc_ups_health, 
		history_apc_ups.apc_ups_high_transfer_voltage, 
		history_apc_ups.apc_ups_last_transfer_reason, 
		history_apc_ups.apc_ups_low_transger_voltage, 
		history_apc_ups.apc_ups_manufactured_date, 
		history_apc_ups.apc_ups_model, 
		history_apc_ups.apc_ups_temperature_units, 
		history_apc_ups.apc_ups_serial_number, 
		history_apc_ups.apc_ups_nmc_firmware_version,
		history_apc_ups.apc_ups_nmc_serial_number,
		history_apc_ups.apc_ups_nmc_mac_address,
		history_apc_ups.modified_user);
	RETURN NULL;
END;
$$
LANGUAGE plpgsql;
ALTER FUNCTION history_apc_ups() OWNER TO #!variable!user!#;

CREATE TRIGGER trigger_apc_ups
	AFTER INSERT OR UPDATE ON apc_ups
	FOR EACH ROW EXECUTE PROCEDURE history_apc_ups();

-- Battery stuff
CREATE TABLE apc_ups_battery (
	apc_ups_battery_id			bigserial			primary key,
	apc_ups_battery_apc_ups_id		bigint				not null,
	apc_ups_battery_replacement_date	text,
	apc_ups_battery_health			integer,
	apc_ups_battery_model			text,
	apc_ups_battery_percentage_charge	double precision,
	apc_ups_battery_last_replacement_date	text,
	apc_ups_battery_state			integer,
	apc_ups_battery_temperature		double precision,
	apc_ups_battery_alarm_temperature	integer,
	apc_ups_battery_voltage			double precision,
	modified_date				timestamp with time zone	not null	default now(),
	
	FOREIGN KEY(apc_ups_data_apc_ups_id) REFERENCES apc_ups(apc_ups_data_id)
);
ALTER TABLE apc_ups_battery OWNER TO #!variable!user!#;

CREATE TABLE apc_ups_battery (
	apc_ups_battery_id			bigserial			primary key,
	apc_ups_battery_history_id		bigserial,
	apc_ups_battery_apc_ups_id		bigint				not null,
	apc_ups_battery_replacement_date	text,
	apc_ups_battery_health			integer,
	apc_ups_battery_model			text,
	apc_ups_battery_percentage_charge	double precision,
	apc_ups_battery_last_replacement_date	text,
	apc_ups_battery_state			integer,
	apc_ups_battery_temperature		double precision,
	apc_ups_battery_alarm_temperature	integer,
	apc_ups_battery_voltage			double precision,
	modified_date				timestamp with time zone	not null	default now(),
	
	FOREIGN KEY(apc_ups_data_apc_ups_id) REFERENCES apc_ups(apc_ups_data_id)
);
ALTER TABLE apc_ups_battery OWNER TO #!variable!user!#;




CREATE TABLE apc_ups_input (
	apc_ups_input_id			bigserial			primary key,
	apc_ups_input_apc_ups_id		bigint				not null,
	apc_ups_input_frequency			double precision,
	apc_ups_input_sensitivity		integer,
	apc_ups_input_voltage			double precision,
	apc_ups_input_1m_maximum_input_voltage	double precision,
	apc_ups_input_1m_minimum_input_voltage	double precision,
	modified_date				timestamp with time zone	not null	default now(),
	
	FOREIGN KEY(apc_ups_data_apc_ups_id) REFERENCES apc_ups(apc_ups_data_id)
);
ALTER TABLE apc_ups_input OWNER TO #!variable!user!#;

CREATE TABLE apc_ups_output (
	apc_ups_output_id			bigserial			primary key,
	apc_ups_output_apc_ups_id		bigint				not null,
	apc_ups_output_load_percentage		double precision,
	apc_ups_output_time_on_batties		double precision,
	apc_ups_output_estimated_runtime	double precision,
	apc_ups_output_frequency		double precision,
	apc_ups_output_voltage			double precision,
	modified_date				timestamp with time zone	not null	default now(),
	
	FOREIGN KEY(apc_ups_data_apc_ups_id) REFERENCES apc_ups(apc_ups_data_id)
);
ALTER TABLE apc_ups_output OWNER TO #!variable!user!#;
