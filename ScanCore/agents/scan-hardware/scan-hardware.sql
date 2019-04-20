-- This is the database schema for the 'hardware Scan Agent'.

CREATE TABLE hardware (
	hardware_uuid			uuid				primary key,
	hardware_host_uuid		uuid				not null,
	hardware_cpu_model		text				not null, 
	hardware_cpu_cores		numeric				not null, 	-- We don't care about individual sockets / chips
	hardware_cpu_threads		numeric				not null, 
	hardware_cpu_bugs		text				not null, 
	hardware_cpu_flags		text				not null,	--  
	hardware_memory_total		numeric				not null,	--  
	hardware_memory_free		numeric				not null,	--  
	hardware_swap_total		numeric				not null,	--  
	hardware_swap_free		numeric				not null,	--  
	hardware_led_id_led		text				not null,	--  
	hardware_led_css_led		text				not null,	--  
	hardware_led_error_led		text				not null,	--  
	modified_date			timestamp with time zone	not null,
	
	FOREIGN KEY(hardware_host_uuid) REFERENCES hosts(host_uuid)
);
ALTER TABLE hardware OWNER TO #!variable!user!#;

CREATE TABLE history.hardware (
	history_id			bigserial,
	hardware_uuid			uuid,
	hardware_host_uuid		uuid,
	hardware_cpu_model		text, 
	hardware_cpu_cores		numeric, 
	hardware_cpu_threads		numeric, 
	hardware_cpu_bugs		text, 
	hardware_cpu_flags		text, 
	hardware_memory_total		numeric, 
	hardware_memory_free		numeric, 
	hardware_swap_total		numeric, 
	hardware_swap_free		numeric, 
	hardware_led_id_led		text, 
	hardware_led_css_led		text, 
	hardware_led_error_led		text, 
	modified_date			timestamp with time zone	not null
);
ALTER TABLE history.hardware OWNER TO #!variable!user!#;

CREATE FUNCTION history_hardware() RETURNS trigger
AS $$
DECLARE
	history_hardware RECORD;
BEGIN
	SELECT INTO history_hardware * FROM hardware WHERE hardware_uuid=new.hardware_uuid;
	INSERT INTO history.hardware
		(hardware_uuid,
		 hardware_host_uuid, 
		 hardware_cpu_model, 
		 hardware_cpu_cores, 
		 hardware_cpu_threads, 
		 hardware_cpu_bugs, 
		 hardware_cpu_flags, 
		 hardware_memory_total, 
		 hardware_memory_free, 
		 hardware_swap_total, 
		 hardware_swap_free, 
		 hardware_led_id_led, 
		 hardware_led_css_led, 
		 hardware_led_error_led, 
		 modified_date)
	VALUES
		(history_hardware.hardware_uuid,
		 history_hardware.hardware_host_uuid, 
		 history_hardware.hardware_cpu_model, 
		 history_hardware.hardware_cpu_cores, 
		 history_hardware.hardware_cpu_threads, 
		 history_hardware.hardware_cpu_bugs, 
		 history_hardware.hardware_cpu_flags, 
		 history_hardware.hardware_memory_total, 
		 history_hardware.hardware_memory_free, 
		 history_hardware.hardware_swap_total, 
		 history_hardware.hardware_swap_free, 
		 history_hardware.hardware_led_id_led, 
		 history_hardware.hardware_led_css_led, 
		 history_hardware.hardware_led_error_led, 
		 history_hardware.modified_date);
	RETURN NULL;
END;
$$
LANGUAGE plpgsql;
ALTER FUNCTION history_hardware() OWNER TO #!variable!user!#;

CREATE TRIGGER trigger_hardware
	AFTER INSERT OR UPDATE ON hardware
	FOR EACH ROW EXECUTE PROCEDURE history_hardware();

CREATE TABLE hardware_ram_module (
	hardware_ram_module_uuid		uuid				primary key,
	hardware_ram_module_host_uuid		uuid				not null,
	hardware_ram_module_locator		text				not null, 
	hardware_ram_module_size		numeric				not null, 
	hardware_ram_module_manufacturer	text				not null, 
	hardware_ram_module_model		text				not null,
	hardware_ram_module_serial_number	text				not null,
	modified_date				timestamp with time zone	not null,
	
	FOREIGN KEY(hardware_ram_module_host_uuid) REFERENCES hosts(host_uuid)
);
ALTER TABLE hardware_ram_module OWNER TO #!variable!user!#;

CREATE TABLE history.hardware_ram_module (
	history_id				bigserial,
	hardware_ram_module_uuid		uuid,
	hardware_ram_module_host_uuid		uuid,
	hardware_ram_module_locator		text, 
	hardware_ram_module_size		numeric, 
	hardware_ram_module_manufacturer	text, 
	hardware_ram_module_model		text, 
	hardware_ram_module_serial_number	text, 
	modified_date				timestamp with time zone	not null
);
ALTER TABLE history.hardware_ram_module OWNER TO #!variable!user!#;

CREATE FUNCTION history_hardware_ram_module() RETURNS trigger
AS $$
DECLARE
	history_hardware_ram_module RECORD;
BEGIN
	SELECT INTO history_hardware_ram_module * FROM hardware_ram_module WHERE hardware_ram_module_uuid=new.hardware_ram_module_uuid;
	INSERT INTO history.hardware_ram_module
		(hardware_ram_module_uuid,
		 hardware_ram_module_host_uuid, 
		 hardware_ram_module_locator, 
		 hardware_ram_module_size, 
		 hardware_ram_module_manufacturer, 
		 hardware_ram_module_model, 
		 hardware_ram_module_serial_number, 
		 modified_date)
	VALUES
		(history_hardware_ram_module.hardware_ram_module_uuid,
		 history_hardware_ram_module.hardware_ram_module_host_uuid, 
		 history_hardware_ram_module.hardware_ram_module_locator, 
		 history_hardware_ram_module.hardware_ram_module_size, 
		 history_hardware_ram_module.hardware_ram_module_manufacturer, 
		 history_hardware_ram_module.hardware_ram_module_model, 
		 history_hardware_ram_module.hardware_ram_module_serial_number, 
		 history_hardware_ram_module.modified_date);
	RETURN NULL;
END;
$$
LANGUAGE plpgsql;
ALTER FUNCTION history_hardware_ram_module() OWNER TO #!variable!user!#;

CREATE TRIGGER trigger_hardware_ram_module
	AFTER INSERT OR UPDATE ON hardware_ram_module
	FOR EACH ROW EXECUTE PROCEDURE history_hardware_ram_module();
