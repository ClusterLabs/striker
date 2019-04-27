-- This is the database schema for the 'hardware Scan Agent'.

CREATE TABLE hardware (
	hardware_uuid			uuid				primary key,
	hardware_host_uuid		uuid				not null,
	hardware_cpu_model		text				not null, 
	hardware_cpu_cores		numeric				not null, 	-- We don't care about individual sockets / chips
	hardware_cpu_threads		numeric				not null, 
	hardware_cpu_bugs		text				not null, 
	hardware_cpu_flags		text				not null,	--  
	hardware_ram_total		numeric				not null,	-- This is the sum of the hardware memory module capacity
	hardware_memory_total		numeric				not null,	-- This is the amount seen by the OS, minus shared memory, like that allocated to video
	hardware_memory_free		numeric				not null,	--  
	hardware_swap_total		numeric				not null,	--  
	hardware_swap_free		numeric				not null,	--  
	hardware_led_id			text				not null,	--  
	hardware_led_css		text				not null,	--  
	hardware_led_error		text				not null,	--  
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
	hardware_ram_total		numeric,
	hardware_memory_total		numeric, 
	hardware_memory_free		numeric, 
	hardware_swap_total		numeric, 
	hardware_swap_free		numeric, 
	hardware_led_id			text, 
	hardware_led_css		text, 
	hardware_led_error		text, 
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
		 hardware_ram_total, 
		 hardware_memory_total, 
		 hardware_memory_free, 
		 hardware_swap_total, 
		 hardware_swap_free, 
		 hardware_led_id, 
		 hardware_led_css, 
		 hardware_led_error, 
		 modified_date)
	VALUES
		(history_hardware.hardware_uuid,
		 history_hardware.hardware_host_uuid, 
		 history_hardware.hardware_cpu_model, 
		 history_hardware.hardware_cpu_cores, 
		 history_hardware.hardware_cpu_threads, 
		 history_hardware.hardware_cpu_bugs, 
		 history_hardware.hardware_cpu_flags, 
		 history_hardware.hardware_ram_total, 
		 history_hardware.hardware_memory_total, 
		 history_hardware.hardware_memory_free, 
		 history_hardware.hardware_swap_total, 
		 history_hardware.hardware_swap_free, 
		 history_hardware.hardware_led_id, 
		 history_hardware.hardware_led_css, 
		 history_hardware.hardware_led_error, 
		 history_hardware.modified_date);
	RETURN NULL;
END;
$$
LANGUAGE plpgsql;
ALTER FUNCTION history_hardware() OWNER TO #!variable!user!#;

CREATE TRIGGER trigger_hardware
	AFTER INSERT OR UPDATE ON hardware
	FOR EACH ROW EXECUTE PROCEDURE history_hardware();

CREATE TABLE hardware_ram_modules (
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
ALTER TABLE hardware_ram_modules OWNER TO #!variable!user!#;

CREATE TABLE history.hardware_ram_modules (
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
ALTER TABLE history.hardware_ram_modules OWNER TO #!variable!user!#;

CREATE FUNCTION history_hardware_ram_modules() RETURNS trigger
AS $$
DECLARE
	history_hardware_ram_modules RECORD;
BEGIN
	SELECT INTO history_hardware_ram_modules * FROM hardware_ram_modules WHERE hardware_ram_module_uuid=new.hardware_ram_module_uuid;
	INSERT INTO history.hardware_ram_modules
		(hardware_ram_module_uuid,
		 hardware_ram_module_host_uuid, 
		 hardware_ram_module_locator, 
		 hardware_ram_module_size, 
		 hardware_ram_module_manufacturer, 
		 hardware_ram_module_model, 
		 hardware_ram_module_serial_number, 
		 modified_date)
	VALUES
		(history_hardware_ram_modules.hardware_ram_module_uuid,
		 history_hardware_ram_modules.hardware_ram_module_host_uuid, 
		 history_hardware_ram_modules.hardware_ram_module_locator, 
		 history_hardware_ram_modules.hardware_ram_module_size, 
		 history_hardware_ram_modules.hardware_ram_module_manufacturer, 
		 history_hardware_ram_modules.hardware_ram_module_model, 
		 history_hardware_ram_modules.hardware_ram_module_serial_number, 
		 history_hardware_ram_modules.modified_date);
	RETURN NULL;
END;
$$
LANGUAGE plpgsql;
ALTER FUNCTION history_hardware_ram_modules() OWNER TO #!variable!user!#;

CREATE TRIGGER trigger_hardware_ram_modules
	AFTER INSERT OR UPDATE ON hardware_ram_modules
	FOR EACH ROW EXECUTE PROCEDURE history_hardware_ram_modules();
