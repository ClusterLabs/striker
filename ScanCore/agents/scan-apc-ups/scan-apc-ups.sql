-- This is the database schema for the 'APC UPS Scan Agent'.

CREATE TABLE apc_ups (
	apc_ups_id			bigserial			primary key,
	apc_ups_host_id			bigint				not null,
	apc_ups_fqdn			text,
	apc_ups_ip			text,
	apc_ups_ac_restore_delay	numeric,
	apc_ups_shutdown_delay		numeric,
	apc_ups_firmware_version	text,
	apc_ups_health			numeric,
	apc_ups_high_transfer_voltage	numeric,
	apc_ups_low_transfer_voltage	numeric,
	apc_ups_last_transfer_reason	numeric,
	apc_ups_manufactured_date	text,
	apc_ups_model			text,
	apc_ups_temperature_units	text,
	apc_ups_serial_number		text,
	apc_ups_nmc_firmware_version	text,
	apc_ups_nmc_serial_number	text,
	apc_ups_nmc_mac_address		text,
	modified_date			timestamp with time zone	not null,
	
	FOREIGN KEY(apc_ups_host_id) REFERENCES hosts(host_id)
);
ALTER TABLE apc_ups OWNER TO #!variable!user!#;

CREATE TABLE history.apc_ups (
	history_id			bigserial,
	apc_ups_id			bigint,
	apc_ups_host_id			bigint,
	apc_ups_fqdn			text,
	apc_ups_ip			text,
	apc_ups_ac_restore_delay	numeric,
	apc_ups_shutdown_delay		numeric,
	apc_ups_firmware_version	text,
	apc_ups_health			numeric,
	apc_ups_high_transfer_voltage	numeric,
	apc_ups_low_transfer_voltage	numeric,
	apc_ups_last_transfer_reason	numeric,
	apc_ups_manufactured_date	text,
	apc_ups_model			text,
	apc_ups_temperature_units	text,
	apc_ups_serial_number		text,
	apc_ups_nmc_firmware_version	text,
	apc_ups_nmc_serial_number	text,
	apc_ups_nmc_mac_address		text,
	modified_date			timestamp with time zone	not null
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
		 apc_ups_host_id, 
		 apc_ups_fqdn, 
		 apc_ups_ip, 
		 apc_ups_ac_restore_delay, 
		 apc_ups_shutdown_delay, 
		 apc_ups_firmware_version, 
		 apc_ups_health, 
		 apc_ups_high_transfer_voltage, 
		 apc_ups_low_transfer_voltage, 
		 apc_ups_last_transfer_reason, 
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
		 history_apc_ups.apc_ups_host_id, 
		 history_apc_ups.apc_ups_fqdn,
		 history_apc_ups.apc_ups_ip,
		 history_apc_ups.apc_ups_ac_restore_delay, 
		 history_apc_ups.apc_ups_shutdown_delay, 
		 history_apc_ups.apc_ups_firmware_version, 
		 history_apc_ups.apc_ups_health, 
		 history_apc_ups.apc_ups_high_transfer_voltage, 
		 history_apc_ups.apc_ups_low_transfer_voltage, 
		 history_apc_ups.apc_ups_last_transfer_reason, 
		 history_apc_ups.apc_ups_manufactured_date, 
		 history_apc_ups.apc_ups_model, 
		 history_apc_ups.apc_ups_temperature_units, 
		 history_apc_ups.apc_ups_serial_number, 
		 history_apc_ups.apc_ups_nmc_firmware_version,
		 history_apc_ups.apc_ups_nmc_serial_number,
		 history_apc_ups.apc_ups_nmc_mac_address,
		 history_apc_ups.modified_date);
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
	apc_ups_battery_health			numeric,
	apc_ups_battery_model			text,
	apc_ups_battery_percentage_charge	numeric,
	apc_ups_battery_last_replacement_date	text,
	apc_ups_battery_state			numeric,
	apc_ups_battery_temperature		numeric,
	apc_ups_battery_alarm_temperature	numeric,
	apc_ups_battery_voltage			numeric,
	modified_date				timestamp with time zone	not null,
	
	FOREIGN KEY(apc_ups_battery_apc_ups_id) REFERENCES apc_ups(apc_ups_id)
);
ALTER TABLE apc_ups_battery OWNER TO #!variable!user!#;

CREATE TABLE history.apc_ups_battery (
	history_id				bigserial,
	apc_ups_battery_id			bigint				not null,
	apc_ups_battery_apc_ups_id		bigint				not null,
	apc_ups_battery_replacement_date	text,
	apc_ups_battery_health			numeric,
	apc_ups_battery_model			text,
	apc_ups_battery_percentage_charge	numeric,
	apc_ups_battery_last_replacement_date	text,
	apc_ups_battery_state			numeric,
	apc_ups_battery_temperature		numeric,
	apc_ups_battery_alarm_temperature	numeric,
	apc_ups_battery_voltage			numeric,
	modified_date				timestamp with time zone	not null
);
ALTER TABLE history.apc_ups_battery OWNER TO #!variable!user!#;

CREATE FUNCTION history_apc_ups_battery() RETURNS trigger
AS $$
DECLARE
	history_apc_ups_battery RECORD;
BEGIN
	SELECT INTO history_apc_ups_battery * FROM apc_ups_battery WHERE apc_ups_battery_id=new.apc_ups_battery_id;
	INSERT INTO history.apc_ups_battery
		(apc_ups_battery_id,
		 apc_ups_battery_apc_ups_id,
		 apc_ups_battery_replacement_date,
		 apc_ups_battery_health,
		 apc_ups_battery_model,
		 apc_ups_battery_percentage_charge,
		 apc_ups_battery_last_replacement_date,
		 apc_ups_battery_state,
		 apc_ups_battery_temperature,
		 apc_ups_battery_alarm_temperature,
		 apc_ups_battery_voltage,
		 modified_date)
	VALUES
		(history_apc_ups_battery.apc_ups_battery_id,
		 history_apc_ups_battery.apc_ups_battery_apc_ups_id,
		 history_apc_ups_battery.apc_ups_battery_replacement_date,
		 history_apc_ups_battery.apc_ups_battery_health,
		 history_apc_ups_battery.apc_ups_battery_model,
		 history_apc_ups_battery.apc_ups_battery_percentage_charge,
		 history_apc_ups_battery.apc_ups_battery_last_replacement_date,
		 history_apc_ups_battery.apc_ups_battery_state,
		 history_apc_ups_battery.apc_ups_battery_temperature,
		 history_apc_ups_battery.apc_ups_battery_alarm_temperature,
		 history_apc_ups_battery.apc_ups_battery_voltage,
		 history_apc_ups_battery.modified_date);
	RETURN NULL;
END;
$$
LANGUAGE plpgsql;
ALTER FUNCTION history_apc_ups_battery() OWNER TO #!variable!user!#;

CREATE TRIGGER trigger_apc_ups_battery
	AFTER INSERT OR UPDATE ON apc_ups_battery
	FOR EACH ROW EXECUTE PROCEDURE history_apc_ups_battery();


-- Input power
CREATE TABLE apc_ups_input (
	apc_ups_input_id			bigserial			primary key,
	apc_ups_input_apc_ups_id		bigint				not null,
	apc_ups_input_frequency			numeric,
	apc_ups_input_sensitivity		numeric,
	apc_ups_input_voltage			numeric,
	apc_ups_input_1m_maximum_input_voltage	numeric,
	apc_ups_input_1m_minimum_input_voltage	numeric,
	modified_date				timestamp with time zone	not null,
	
	FOREIGN KEY(apc_ups_input_apc_ups_id) REFERENCES apc_ups(apc_ups_id)
);
ALTER TABLE apc_ups_input OWNER TO #!variable!user!#;

CREATE TABLE history.apc_ups_input (
	history_id				bigserial,
	apc_ups_input_id			bigint				not null,
	apc_ups_input_apc_ups_id		bigint				not null,
	apc_ups_input_frequency			numeric,
	apc_ups_input_sensitivity		numeric,
	apc_ups_input_voltage			numeric,
	apc_ups_input_1m_maximum_input_voltage	numeric,
	apc_ups_input_1m_minimum_input_voltage	numeric,
	modified_date				timestamp with time zone	not null
);
ALTER TABLE history.apc_ups_input OWNER TO #!variable!user!#;

CREATE FUNCTION history_apc_ups_input() RETURNS trigger
AS $$
DECLARE
	history_apc_ups_input RECORD;
BEGIN
	SELECT INTO history_apc_ups_input * FROM apc_ups_input WHERE apc_ups_input_id=new.apc_ups_input_id;
	INSERT INTO history.apc_ups_input
		(apc_ups_input_id,
		 apc_ups_input_apc_ups_id,
		 apc_ups_input_frequency, 
		 apc_ups_input_sensitivity, 
		 apc_ups_input_voltage, 
		 apc_ups_input_1m_maximum_input_voltage, 
		 apc_ups_input_1m_minimum_input_voltage, 
		 modified_date)
	VALUES
		(history_apc_ups_input.apc_ups_input_id,
		 history_apc_ups_input.apc_ups_input_apc_ups_id,
		 history_apc_ups_input.apc_ups_input_frequency, 
		 history_apc_ups_input.apc_ups_input_sensitivity, 
		 history_apc_ups_input.apc_ups_input_voltage, 
		 history_apc_ups_input.apc_ups_input_1m_maximum_input_voltage, 
		 history_apc_ups_input.apc_ups_input_1m_minimum_input_voltage, 
		 history_apc_ups_input.modified_date);
	RETURN NULL;
END;
$$
LANGUAGE plpgsql;
ALTER FUNCTION history_apc_ups_input() OWNER TO #!variable!user!#;

CREATE TRIGGER trigger_apc_ups_input
	AFTER INSERT OR UPDATE ON apc_ups_input
	FOR EACH ROW EXECUTE PROCEDURE history_apc_ups_input();


-- Output power
CREATE TABLE apc_ups_output (
	apc_ups_output_id			bigserial			primary key,
	apc_ups_output_apc_ups_id		bigint				not null,
	apc_ups_output_load_percentage		numeric,
	apc_ups_output_time_on_batteries	numeric,
	apc_ups_output_estimated_runtime	numeric,
	apc_ups_output_frequency		numeric,
	apc_ups_output_voltage			numeric,
	apc_ups_output_total_output		numeric,
	modified_date				timestamp with time zone	not null,
	
	FOREIGN KEY(apc_ups_output_apc_ups_id) REFERENCES apc_ups(apc_ups_id)
);
ALTER TABLE apc_ups_output OWNER TO #!variable!user!#;

CREATE TABLE history.apc_ups_output (
	history_id				bigserial,
	apc_ups_output_id			bigint				not null,
	apc_ups_output_apc_ups_id		bigint				not null,
	apc_ups_output_load_percentage		numeric,
	apc_ups_output_time_on_batteries	numeric,
	apc_ups_output_estimated_runtime	numeric,
	apc_ups_output_frequency		numeric,
	apc_ups_output_voltage			numeric,
	apc_ups_output_total_output		numeric,
	modified_date				timestamp with time zone	not null
);
ALTER TABLE history.apc_ups_output OWNER TO #!variable!user!#;

CREATE FUNCTION history_apc_ups_output() RETURNS trigger
AS $$
DECLARE
	history_apc_ups_output RECORD;
BEGIN
	SELECT INTO history_apc_ups_output * FROM apc_ups_output WHERE apc_ups_output_id=new.apc_ups_output_id;
	INSERT INTO history.apc_ups_output
		(apc_ups_output_id,
		 apc_ups_output_apc_ups_id,
		 apc_ups_output_load_percentage, 
		 apc_ups_output_time_on_batteries, 
		 apc_ups_output_estimated_runtime, 
		 apc_ups_output_frequency, 
		 apc_ups_output_voltage, 
		 apc_ups_output_total_output, 
		 modified_date)
	VALUES
		(history_apc_ups_output.apc_ups_output_id,
		 history_apc_ups_output.apc_ups_output_apc_ups_id,
		 history_apc_ups_output.apc_ups_output_load_percentage, 
		 history_apc_ups_output.apc_ups_output_time_on_batteries, 
		 history_apc_ups_output.apc_ups_output_estimated_runtime, 
		 history_apc_ups_output.apc_ups_output_frequency, 
		 history_apc_ups_output.apc_ups_output_voltage, 
		 history_apc_ups_output.apc_ups_output_total_output, 
		 history_apc_ups_output.modified_date);
	RETURN NULL;
END;
$$
LANGUAGE plpgsql;
ALTER FUNCTION history_apc_ups_output() OWNER TO #!variable!user!#;

CREATE TRIGGER trigger_apc_ups_output
	AFTER INSERT OR UPDATE ON apc_ups_output
	FOR EACH ROW EXECUTE PROCEDURE history_apc_ups_output();
