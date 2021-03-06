-- This is the database schema for the 'ipmitool Scan Agent'.

CREATE TABLE ipmitool (
	ipmitool_uuid			uuid				primary key,
	ipmitool_host_uuid		uuid				not null,
	ipmitool_sensor_host		text				not null,	-- The hostname of the machine we pulled the sensor value from. We don't link this to a host_uuid because it is possible the host doesn't doesn't have an entry (yet)
	ipmitool_sensor_name		text				not null,
	ipmitool_sensor_units		text				not null,	-- Temperature (°C), vDC, vAC, watt, amp, percent
	ipmitool_sensor_status		text				not null,
	ipmitool_sensor_high_critical	numeric,
	ipmitool_sensor_high_warning	numeric,
	ipmitool_sensor_low_critical	numeric,
	ipmitool_sensor_low_warning	numeric,
	modified_date			timestamp with time zone	not null,
	
	FOREIGN KEY(ipmitool_host_uuid) REFERENCES hosts(host_uuid)
);
ALTER TABLE ipmitool OWNER TO #!variable!user!#;

CREATE TABLE history.ipmitool (
	history_id			bigserial,
	ipmitool_uuid			uuid,
	ipmitool_host_uuid		uuid,
	ipmitool_sensor_host		text				not null,
	ipmitool_sensor_name		text				not null,
	ipmitool_sensor_units		text				not null,
	ipmitool_sensor_status		text				not null,
	ipmitool_sensor_high_critical	numeric,
	ipmitool_sensor_high_warning	numeric,
	ipmitool_sensor_low_critical	numeric,
	ipmitool_sensor_low_warning	numeric,
	modified_date			timestamp with time zone	not null
);
ALTER TABLE history.ipmitool OWNER TO #!variable!user!#;

CREATE FUNCTION history_ipmitool() RETURNS trigger
AS $$
DECLARE
	history_ipmitool RECORD;
BEGIN
	SELECT INTO history_ipmitool * FROM ipmitool WHERE ipmitool_uuid=new.ipmitool_uuid;
	INSERT INTO history.ipmitool
		(ipmitool_uuid,
		 ipmitool_host_uuid, 
		 ipmitool_sensor_host, 
		 ipmitool_sensor_name, 
		 ipmitool_sensor_units, 
		 ipmitool_sensor_status, 
		 ipmitool_sensor_high_critical, 
		 ipmitool_sensor_high_warning, 
		 ipmitool_sensor_low_critical, 
		 ipmitool_sensor_low_warning, 
		 modified_date)
	VALUES
		(history_ipmitool.ipmitool_uuid,
		 history_ipmitool.ipmitool_host_uuid, 
		 history_ipmitool.ipmitool_sensor_host, 
		 history_ipmitool.ipmitool_sensor_name, 
		 history_ipmitool.ipmitool_sensor_units, 
		 history_ipmitool.ipmitool_sensor_status, 
		 history_ipmitool.ipmitool_sensor_high_critical, 
		 history_ipmitool.ipmitool_sensor_high_warning, 
		 history_ipmitool.ipmitool_sensor_low_critical, 
		 history_ipmitool.ipmitool_sensor_low_warning, 
		 history_ipmitool.modified_date);
	RETURN NULL;
END;
$$
LANGUAGE plpgsql;
ALTER FUNCTION history_ipmitool() OWNER TO #!variable!user!#;

CREATE TRIGGER trigger_ipmitool
	AFTER INSERT OR UPDATE ON ipmitool
	FOR EACH ROW EXECUTE PROCEDURE history_ipmitool();


-- This contains the ever-changing sensor values. This is a separate table to
-- keep the DB as small as possible.
CREATE TABLE ipmitool_value (
	ipmitool_value_id		bigserial			primary key,
	ipmitool_value_ipmitool_uuid	uuid,
	ipmitool_value_sensor_value	numeric,
	modified_date			timestamp with time zone	not null,
	
	FOREIGN KEY(ipmitool_value_ipmitool_uuid) REFERENCES ipmitool(ipmitool_uuid)
);
ALTER TABLE ipmitool_value OWNER TO #!variable!user!#;

CREATE TABLE history.ipmitool_value (
	history_id			bigserial,
	ipmitool_value_id		bigint,
	ipmitool_value_ipmitool_uuid	uuid,
	ipmitool_value_sensor_value	numeric,
	modified_date			timestamp with time zone	not null
);
ALTER TABLE history.ipmitool_value OWNER TO #!variable!user!#;

CREATE FUNCTION history_ipmitool_value() RETURNS trigger
AS $$
DECLARE
	history_ipmitool_value RECORD;
BEGIN
	SELECT INTO history_ipmitool_value * FROM ipmitool_value WHERE ipmitool_value_id=new.ipmitool_value_id;
	INSERT INTO history.ipmitool_value
		(ipmitool_value_id,
		 ipmitool_value_ipmitool_uuid, 
		 ipmitool_value_sensor_value, 
		 modified_date)
	VALUES
		(history_ipmitool_value.ipmitool_value_id,
		 history_ipmitool_value.ipmitool_value_ipmitool_uuid, 
		 history_ipmitool_value.ipmitool_value_sensor_value, 
		 history_ipmitool_value.modified_date);
	RETURN NULL;
END;
$$
LANGUAGE plpgsql;
ALTER FUNCTION history_ipmitool_value() OWNER TO #!variable!user!#;

CREATE TRIGGER trigger_ipmitool_value
	AFTER INSERT OR UPDATE ON ipmitool_value
	FOR EACH ROW EXECUTE PROCEDURE history_ipmitool_value();
