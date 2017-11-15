-- This is the database schema for the 'hpacucli Scan Agent'.
--       
--       Things that change rarely should go in the main tables (even if we won't explicitely watch for them
--       to change with specific alerts).

-- ------------------------------------------------------------------------------------------------------- --
-- Adapter                                                                                                 --
-- ------------------------------------------------------------------------------------------------------- --



-- Controller;
-- - Temperature; controller_temperature: [85 °C]
-- - Data; model_name: [Smart Array P420i]
-- - Data; cache_board_present: [True]
-- - Data; controller_status: [OK]
-- - Data; drive_write_cache: [Disabled]
-- - Data; firmware_version: [8.00]
-- - Data; no_battery_write_cache: [Disabled]
-- 
-- Ignore;
-- - Data; battery_or_capacitor_count: [1]
-- - Data; degraded_performance_optimization: [Disabled]
-- - Data; elevator_sort: [Enabled]
-- - Data; expand_priority: [Medium]
-- - Data; hardware_revision: [B]
-- - Data; inconsistency_repair_policy: [Disabled]
-- - Data; monitor_and_performance_delay: [60 min]
-- - Data; post_prompt_timeout: [0 secs]
-- - Data; queue_depth: [Automatic]
-- - Data; raid_6_-_adg_status: [Enabled]
-- - Data; rebuild_priority: [Medium]
-- - Data; sata_ncq_supported: [True]
-- - Data; spare_activation_mode: [Activate on drive failure]
-- - Data; surface_analysis_inconsistency_notification: [Disabled]
-- - Data; surface_scan_delay: [15 secs]
-- - Data; surface_scan_mode: [Idle]
-- - Data; wait_for_cache_room: [Disabled]
-- - Data; cache_ratio: [10% Read / 90% Write]
-- - Data; total_cache_memory_available: [816 MB]


-- Here is the basic controller information. All connected devices will reference back to this table's 
-- 'hpacucli_controller_serial_number' column.
CREATE TABLE hpacucli_controllers (
	hpacucli_controller_uuid			uuid				primary key,
	hpacucli_controller_host_uuid			uuid				not null,
	hpacucli_controller_serial_number		text				not null,	-- This is the core identifier
	hpacucli_controller_model			text				not null,	-- 
	hpacucli_controller_status			text				not null,	-- 
	hpacucli_controller_last_diagnostics		numeric,					-- Collecting diagnostics information is very expensive, so we do it once every hour (or whatever the user chooses).
	hpacucli_controller_cache_present		text				not null,	-- "yes" or "no"
	hpacucli_controller_drive_write_cache		text				not null,	-- "enabled" or "disabled"
	hpacucli_controller_firmware_version		text,
	hpacucli_controller_unsafe_writeback_cache	text,						-- "enabled" or "disabled"
	modified_date					timestamp with time zone	not null,
	
	FOREIGN KEY(hpacucli_controller_host_uuid) REFERENCES hosts(host_uuid)
);
ALTER TABLE hpacucli_controllers OWNER TO #!variable!user!#;

CREATE TABLE history.hpacucli_controllers (
	history_id					bigserial,
	hpacucli_controller_uuid			uuid,
	hpacucli_controller_host_uuid			uuid,
	hpacucli_controller_serial_number		text,
	hpacucli_controller_model			text,
	hpacucli_controller_status			text,
	hpacucli_controller_last_diagnostics		numeric,
	hpacucli_controller_cache_present		text,
	hpacucli_controller_drive_write_cache		text,
	hpacucli_controller_firmware_version		text,
	hpacucli_controller_unsafe_writeback_cache	text,
	modified_date					timestamp with time zone
);
ALTER TABLE history.hpacucli_controllers OWNER TO #!variable!user!#;

CREATE FUNCTION history_hpacucli_controllers() RETURNS trigger
AS $$
DECLARE
	history_hpacucli_controllers RECORD;
BEGIN
	SELECT INTO history_hpacucli_controllers * FROM hpacucli_controllers WHERE hpacucli_controller_uuid=new.hpacucli_controller_uuid;
	INSERT INTO history.hpacucli_controllers
		(hpacucli_controller_uuid, 
		 hpacucli_controller_host_uuid, 
		 hpacucli_controller_serial_number, 
		 hpacucli_controller_model, 
		 hpacucli_controller_status,
		 hpacucli_controller_last_diagnostics, 
		 hpacucli_controller_cache_present,
		 hpacucli_controller_drive_write_cache,
		 hpacucli_controller_firmware_version,
		 hpacucli_controller_unsafe_writeback_cache,
		 modified_date)
	VALUES 
		(history_hpacucli_controllers.hpacucli_controller_uuid,
		 history_hpacucli_controllers.hpacucli_controller_host_uuid,
		 history_hpacucli_controllers.hpacucli_controller_serial_number, 
		 history_hpacucli_controllers.hpacucli_controller_model, 
		 history_hpacucli_controllers.hpacucli_controller_status, 
		 history_hpacucli_controllers.hpacucli_controller_last_diagnostics, 
		 history_hpacucli_controllers.hpacucli_controller_cache_present,
		 history_hpacucli_controllers.hpacucli_controller_drive_write_cache,
		 history_hpacucli_controllers.hpacucli_controller_firmware_version,
		 history_hpacucli_controllers.hpacucli_controller_unsafe_writeback_cache,
		 history_hpacucli_controllers.modified_date);
	RETURN NULL;
END;
$$
LANGUAGE plpgsql;
ALTER FUNCTION history_hpacucli_controllers() OWNER TO #!variable!user!#;

CREATE TRIGGER trigger_hpacucli_controllers
	AFTER INSERT OR UPDATE ON hpacucli_controllers
	FOR EACH ROW EXECUTE PROCEDURE history_hpacucli_controllers();


-- Cache;
-- - Temperature; cache_module_temperature: [37 °C]
-- - Temperature; capacitor_temperature: [25 °C]
-- - Data; cache_serial_number
-- - Data; cache_status: [OK]
-- - Data; battery_or_capacitor_status: [OK]
-- - Data; cache_backup_power_source: [Capacitors]
-- - Data; total_cache_size: [1024 MB]

-- This table is used for BBU and FBU caching.
CREATE TABLE hpacucli_cache_modules (
	hpacucli_cache_module_uuid			uuid				primary key,
	hpacucli_cache_module_host_uuid			uuid				not null,
	hpacucli_cache_module_controller_uuid		uuid				not null,	-- The controller this module is connected to
	hpacucli_cache_module_serial_number		text				not null,
	hpacucli_cache_module_status			text				not null,
	hpacucli_cache_module_type			text				not null,
	hpacucli_cache_module_size			numeric				not null,	-- In bytes
	modified_date					timestamp with time zone	not null,
	
	FOREIGN KEY(hpacucli_cache_module_host_uuid)       REFERENCES hosts(host_uuid),
	FOREIGN KEY(hpacucli_cache_module_controller_uuid) REFERENCES hpacucli_controllers(hpacucli_controller_uuid)
);
ALTER TABLE hpacucli_cache_modules OWNER TO #!variable!user!#;

CREATE TABLE history.hpacucli_cache_modules (
	history_id					bigserial,
	hpacucli_cache_module_uuid			uuid,
	hpacucli_cache_module_host_uuid			uuid,
	hpacucli_cache_module_controller_uuid		uuid,
	hpacucli_cache_module_serial_number		text,
	hpacucli_cache_module_status			text,
	hpacucli_cache_module_type			text,
	hpacucli_cache_module_size			numeric,
	modified_date					timestamp with time zone
);
ALTER TABLE history.hpacucli_cache_modules OWNER TO #!variable!user!#;

CREATE FUNCTION history_hpacucli_cache_modules() RETURNS trigger
AS $$
DECLARE
	history_hpacucli_cache_modules RECORD;
BEGIN
	SELECT INTO history_hpacucli_cache_modules * FROM hpacucli_cache_modules WHERE hpacucli_cache_module_uuid=new.hpacucli_cache_module_uuid;
	INSERT INTO history.hpacucli_cache_modules
		(hpacucli_cache_module_uuid, 
		 hpacucli_cache_module_host_uuid, 
		 hpacucli_cache_module_controller_uuid, 
		 hpacucli_cache_module_serial_number, 
		 hpacucli_cache_module_status, 
		 hpacucli_cache_module_type, 
		 hpacucli_cache_module_size, 
		 modified_date)
	VALUES 
		(history_hpacucli_cache_modules.hpacucli_cache_module_uuid,
		 history_hpacucli_cache_modules.hpacucli_cache_module_host_uuid,
		 history_hpacucli_cache_modules.hpacucli_cache_module_controller_uuid, 
		 history_hpacucli_cache_modules.hpacucli_cache_module_serial_number, 
		 history_hpacucli_cache_modules.hpacucli_cache_module_status, 
		 history_hpacucli_cache_modules.hpacucli_cache_module_type, 
		 history_hpacucli_cache_modules.hpacucli_cache_module_size, 
		 history_hpacucli_cache_modules.modified_date);
	RETURN NULL;
END;
$$
LANGUAGE plpgsql;
ALTER FUNCTION history_hpacucli_cache_modules() OWNER TO #!variable!user!#;

CREATE TRIGGER trigger_hpacucli_cache_modules
	AFTER INSERT OR UPDATE ON hpacucli_cache_modules
	FOR EACH ROW EXECUTE PROCEDURE history_hpacucli_cache_modules();


-- - Array: [A]
--   - Data; array_type: [Data]
--   - Data; interface_type: [SAS]
--   - Data; status: [OK]
--   - Data; unused_space: [0 MB]

-- NOTE: 'ZZZZ' is a fake array used for unallocated disks
-- This stores information about arrays. 
CREATE TABLE hpacucli_arrays (
	hpacucli_array_uuid				uuid				primary key,
	hpacucli_array_host_uuid			uuid				not null,
	hpacucli_array_controller_uuid			uuid				not null,	-- The controller this array is connected to
	hpacucli_array_name				text				not null,
	hpacucli_array_type				text				not null,
	hpacucli_array_status				text				not null,
	hpacucli_array_unused_space			numeric				not null,	-- In bytes
	modified_date					timestamp with time zone	not null,
	
	FOREIGN KEY(hpacucli_array_host_uuid)       REFERENCES hosts(host_uuid),
	FOREIGN KEY(hpacucli_array_controller_uuid) REFERENCES hpacucli_controllers(hpacucli_controller_uuid)
);
ALTER TABLE hpacucli_arrays OWNER TO #!variable!user!#;

CREATE TABLE history.hpacucli_arrays (
	history_id					bigserial,
	hpacucli_array_uuid				uuid,
	hpacucli_array_host_uuid			uuid,
	hpacucli_array_controller_uuid			uuid,
	hpacucli_array_name				text,
	hpacucli_array_type				text,
	hpacucli_array_status				text,
	hpacucli_array_unused_space			numeric, 
	modified_date					timestamp with time zone
);
ALTER TABLE history.hpacucli_arrays OWNER TO #!variable!user!#;

CREATE FUNCTION history_hpacucli_arrays() RETURNS trigger
AS $$
DECLARE
	history_hpacucli_arrays RECORD;
BEGIN
	SELECT INTO history_hpacucli_arrays * FROM hpacucli_arrays WHERE hpacucli_array_uuid=new.hpacucli_array_uuid;
	INSERT INTO history.hpacucli_arrays
		(hpacucli_array_uuid, 
		 hpacucli_array_host_uuid, 
		 hpacucli_array_controller_uuid, 
		 hpacucli_array_name, 
		 hpacucli_array_type,
		 hpacucli_array_status, 
		 hpacucli_array_unused_space, 
		 modified_date)
	VALUES 
		(history_hpacucli_arrays.hpacucli_array_uuid,
		 history_hpacucli_arrays.hpacucli_array_host_uuid,
		 history_hpacucli_arrays.hpacucli_array_controller_uuid, 
		 history_hpacucli_arrays.hpacucli_array_name, 
		 history_hpacucli_arrays.hpacucli_array_type,
		 history_hpacucli_arrays.hpacucli_array_status, 
		 history_hpacucli_arrays.hpacucli_array_unused_space, 
		 history_hpacucli_arrays.modified_date);
	RETURN NULL;
END;
$$
LANGUAGE plpgsql;
ALTER FUNCTION history_hpacucli_arrays() OWNER TO #!variable!user!#;

CREATE TRIGGER trigger_hpacucli_arrays
	AFTER INSERT OR UPDATE ON hpacucli_arrays
	FOR EACH ROW EXECUTE PROCEDURE history_hpacucli_arrays();


--  - Logical Drive: [1]
--    - Data; caching: [Enabled]
--    - Data; cylinders: [65535]
--    - Data; disk_name: [/dev/sda]
--    - Data; drive_type: [Data]
--    - Data; fault_tolerance: [RAID 5]
--    - Data; full_stripe_size: [1280 KB]
--    - Data; heads: [255]
--    - Data; logical_drive_label: [A595BA15001438030E9B24025C4]
--    - Data; mount_points: [/boot 512 MB, / 679.0 GB]
--    - Data; os_status: [LOCKED]
--    - Data; parity_initialization_status: [Initialization Completed]
--    - Data; sectors_per_track: [32]
--    - Data; size: [683.5 GB]
--    - Data; status: [OK]
--    - Data; strip_size: [256 KB]
--    - Data; unique_identifier: [600508B1001C1300C1A2BCEE4BF97677]

-- NOTE: The logical drive '9999' is a fake LD for unallocated disks
-- This stores information about arrays. 
CREATE TABLE hpacucli_logical_drives (
	hpacucli_logical_drive_uuid			uuid				primary key,
	hpacucli_logical_drive_host_uuid		uuid				not null,
	hpacucli_logical_drive_array_uuid		uuid				not null,	-- The array this logical_drive is connected to
	hpacucli_logical_drive_name			text				not null,
	hpacucli_logical_drive_caching			text				not null,
	hpacucli_logical_drive_os_device_name		text				not null,
	hpacucli_logical_drive_type			text				not null,
	hpacucli_logical_drive_raid_level		text				not null,
	hpacucli_logical_drive_size			numeric				not null,	-- in bytes
	hpacucli_logical_drive_strip_size		numeric				not null,	-- in bytes
	hpacucli_logical_drive_stripe_size		numeric				not null,	-- in bytes
	hpacucli_logical_drive_status			text				not null,
	hpacucli_logical_drive_wwn			text				not null,	-- "unique_identifier"
	modified_date					timestamp with time zone	not null,
	
	FOREIGN KEY(hpacucli_logical_drive_host_uuid)  REFERENCES hosts(host_uuid),
	FOREIGN KEY(hpacucli_logical_drive_array_uuid) REFERENCES hpacucli_arrays(hpacucli_array_uuid)
);
ALTER TABLE hpacucli_logical_drives OWNER TO #!variable!user!#;

CREATE TABLE history.hpacucli_logical_drives (
	history_id					bigserial,
	hpacucli_logical_drive_uuid			uuid,
	hpacucli_logical_drive_host_uuid		uuid,
	hpacucli_logical_drive_array_uuid		uuid,
	hpacucli_logical_drive_name			text,
	hpacucli_logical_drive_caching			text,
	hpacucli_logical_drive_os_device_name		text,
	hpacucli_logical_drive_type			text,
	hpacucli_logical_drive_raid_level		text,
	hpacucli_logical_drive_size			numeric,
	hpacucli_logical_drive_strip_size		numeric,
	hpacucli_logical_drive_stripe_size		numeric,
	hpacucli_logical_drive_status			text,
	hpacucli_logical_drive_wwn			text,
	modified_date					timestamp with time zone
);
ALTER TABLE history.hpacucli_logical_drives OWNER TO #!variable!user!#;

CREATE FUNCTION history_hpacucli_logical_drives() RETURNS trigger
AS $$
DECLARE
	history_hpacucli_logical_drives RECORD;
BEGIN
	SELECT INTO history_hpacucli_logical_drives * FROM hpacucli_logical_drives WHERE hpacucli_logical_drive_uuid=new.hpacucli_logical_drive_uuid;
	INSERT INTO history.hpacucli_logical_drives
		(hpacucli_logical_drive_uuid, 
		 hpacucli_logical_drive_host_uuid, 
		 hpacucli_logical_drive_array_uuid,
		 hpacucli_logical_drive_name,
		 hpacucli_logical_drive_caching,
		 hpacucli_logical_drive_os_device_name,
		 hpacucli_logical_drive_type,
		 hpacucli_logical_drive_raid_level,
		 hpacucli_logical_drive_size,
		 hpacucli_logical_drive_strip_size,
		 hpacucli_logical_drive_stripe_size,
		 hpacucli_logical_drive_status,
		 hpacucli_logical_drive_wwn,
		 modified_date)
	VALUES 
		(history_hpacucli_logical_drives.hpacucli_logical_drive_uuid,
		 history_hpacucli_logical_drives.hpacucli_logical_drive_host_uuid,
		 history_hpacucli_logical_drives.hpacucli_logical_drive_array_uuid,
		 history_hpacucli_logical_drives.hpacucli_logical_drive_name,
		 history_hpacucli_logical_drives.hpacucli_logical_drive_caching,
		 history_hpacucli_logical_drives.hpacucli_logical_drive_os_device_name,
		 history_hpacucli_logical_drives.hpacucli_logical_drive_type,
		 history_hpacucli_logical_drives.hpacucli_logical_drive_raid_level,
		 history_hpacucli_logical_drives.hpacucli_logical_drive_size,
		 history_hpacucli_logical_drives.hpacucli_logical_drive_strip_size,
		 history_hpacucli_logical_drives.hpacucli_logical_drive_stripe_size,
		 history_hpacucli_logical_drives.hpacucli_logical_drive_status,
		 history_hpacucli_logical_drives.hpacucli_logical_drive_wwn,
		 history_hpacucli_logical_drives.modified_date);
	RETURN NULL;
END;
$$
LANGUAGE plpgsql;
ALTER FUNCTION history_hpacucli_logical_drives() OWNER TO #!variable!user!#;

CREATE TRIGGER trigger_hpacucli_logical_drives
	AFTER INSERT OR UPDATE ON hpacucli_logical_drives
	FOR EACH ROW EXECUTE PROCEDURE history_hpacucli_logical_drives();



--   - Physical Drive: [1I:1:1], sn: [6XM4E1R60000M528BGFK]
--     - Temperature; current_temperature: [31 °C]
--     - Temperature; maximum_temperature: [40 °C]
--     - Data; drive_type: [Data Drive]
--     - Data; size: [146 GB]
--     - Data; status: [OK]
--     - Data; interface_type: [SAS]
--     - Data; model: [HP EH0146FBQDC]
--     - Data; rotational_speed: [15000]

--     - Data; phy_count: [2]
--     - Data; phy_transfer_rate: [6.0Gbps, Unknown]
--     - Data; firmware_revision: [HPD5]
--     - Data; drive_authentication_status: [OK]
--     - Data; carrier_application_version: [11]
--     - Data; carrier_bootloader_version: [6]

-- This stores information about physical disks. 
CREATE TABLE hpacucli_physical_drives (
	hpacucli_physical_drive_uuid			uuid				primary key,
	hpacucli_physical_drive_host_uuid		uuid				not null,
	hpacucli_physical_drive_logical_drive_uuid	uuid				not null,
	hpacucli_physical_drive_serial_number		text				not null,
	hpacucli_physical_drive_model			text				not null,
	hpacucli_physical_drive_interface		text				not null,
	hpacucli_physical_drive_status			text				not null,
	hpacucli_physical_drive_size			numeric				not null,	-- In bytes
	hpacucli_physical_drive_type			text				not null,
	hpacucli_physical_drive_rpm			numeric				not null,	-- '0' for SSDs.
	modified_date					timestamp with time zone	not null,
	
	FOREIGN KEY(hpacucli_physical_drive_host_uuid)          REFERENCES hosts(host_uuid),
	FOREIGN KEY(hpacucli_physical_drive_logical_drive_uuid) REFERENCES hpacucli_logical_drives(hpacucli_logical_drive_uuid)
);
ALTER TABLE hpacucli_physical_drives OWNER TO #!variable!user!#;

CREATE TABLE history.hpacucli_physical_drives (
	history_id					bigserial,
	hpacucli_physical_drive_uuid			uuid,
	hpacucli_physical_drive_host_uuid		uuid,
	hpacucli_physical_drive_logical_drive_uuid	uuid,
	hpacucli_physical_drive_serial_number		text,
	hpacucli_physical_drive_model			text,
	hpacucli_physical_drive_interface		text,
	hpacucli_physical_drive_status			text,
	hpacucli_physical_drive_size			numeric,
	hpacucli_physical_drive_type			text,
	hpacucli_physical_drive_rpm			numeric,
	modified_date					timestamp with time zone
);
ALTER TABLE history.hpacucli_physical_drives OWNER TO #!variable!user!#;

CREATE FUNCTION history_hpacucli_physical_drives() RETURNS trigger
AS $$
DECLARE
	history_hpacucli_physical_drives RECORD;
BEGIN
	SELECT INTO history_hpacucli_physical_drives * FROM hpacucli_physical_drives WHERE hpacucli_physical_drive_uuid=new.hpacucli_physical_drive_uuid;
	INSERT INTO history.hpacucli_physical_drives
		(hpacucli_physical_drive_uuid, 
		 hpacucli_physical_drive_host_uuid, 
		 hpacucli_physical_drive_logical_drive_uuid, 
		 hpacucli_physical_drive_serial_number,
		 hpacucli_physical_drive_model,
		 hpacucli_physical_drive_interface,
		 hpacucli_physical_drive_status,
		 hpacucli_physical_drive_size,
		 hpacucli_physical_drive_type,
		 hpacucli_physical_drive_rpm,
		 modified_date)
	VALUES 
		(history_hpacucli_physical_drives.hpacucli_physical_drive_uuid,
		 history_hpacucli_physical_drives.hpacucli_physical_drive_host_uuid,
		 history_hpacucli_physical_drives.hpacucli_physical_drive_logical_drive_uuid, 
		 history_hpacucli_physical_drives.hpacucli_physical_drive_serial_number,
		 history_hpacucli_physical_drives.hpacucli_physical_drive_model,
		 history_hpacucli_physical_drives.hpacucli_physical_drive_interface,
	 	 history_hpacucli_physical_drives.hpacucli_physical_drive_status,
		 history_hpacucli_physical_drives.hpacucli_physical_drive_size,
		 history_hpacucli_physical_drives.hpacucli_physical_drive_type,
		 history_hpacucli_physical_drives.hpacucli_physical_drive_rpm,
		 history_hpacucli_physical_drives.modified_date);
	RETURN NULL;
END;
$$
LANGUAGE plpgsql;
ALTER FUNCTION history_hpacucli_physical_drives() OWNER TO #!variable!user!#;

CREATE TRIGGER trigger_hpacucli_physical_drives
	AFTER INSERT OR UPDATE ON hpacucli_physical_drives
	FOR EACH ROW EXECUTE PROCEDURE history_hpacucli_physical_drives();



-- ------------------------------------------------------------------------------------------------------- --
-- Each data type has several variables that we're not storing in the component-specific tables. To do so  --
-- would be to create massive tables that would miss variables not shown for all controllers or when new   --
-- variables are added or renamed. So this table is used to store all those myriade of variables. Each     --
-- entry will reference the table it is attached to and the UUID of the record in that table. The column   --

-- 'hpacucli_variable_is_temperature' will be used to know what data is a temperature and will be then     --
-- used to inform on the host's thermal health.                                                            --
-- ------------------------------------------------------------------------------------------------------- --

-- This stores various variables found for a given controller but not explicitely checked for (or that 
-- change frequently).
CREATE TABLE hpacucli_variables (
	hpacucli_variable_uuid			uuid				primary key,
	hpacucli_variable_host_uuid		uuid				not null,
	hpacucli_variable_source_table		text				not null,
	hpacucli_variable_source_uuid		uuid				not null,
	hpacucli_variable_is_temperature	boolean				not null	default FALSE,
	hpacucli_variable_name			text				not null,
	hpacucli_variable_value			text,
	modified_date				timestamp with time zone	not null,
	
	FOREIGN KEY(hpacucli_variable_host_uuid) REFERENCES hosts(host_uuid)
);
ALTER TABLE hpacucli_variables OWNER TO #!variable!user!#;

CREATE TABLE history.hpacucli_variables (
	history_id				bigserial,
	hpacucli_variable_uuid			uuid,
	hpacucli_variable_host_uuid		uuid,
	hpacucli_variable_source_table		text,
	hpacucli_variable_source_uuid		uuid,
	hpacucli_variable_is_temperature	boolean,
	hpacucli_variable_name			text,
	hpacucli_variable_value			text,
	modified_date				timestamp with time zone
);
ALTER TABLE history.hpacucli_variables OWNER TO #!variable!user!#;

CREATE FUNCTION history_hpacucli_variables() RETURNS trigger
AS $$
DECLARE
	history_hpacucli_variables RECORD;
BEGIN
	SELECT INTO history_hpacucli_variables * FROM hpacucli_variables WHERE hpacucli_variable_uuid=new.hpacucli_variable_uuid;
	INSERT INTO history.hpacucli_variables
		(hpacucli_variable_uuid, 
		 hpacucli_variable_host_uuid, 
		 hpacucli_variable_source_table, 
		 hpacucli_variable_source_uuid, 
		 hpacucli_variable_is_temperature,
		 hpacucli_variable_name,
		 hpacucli_variable_value,
		 modified_date)
	VALUES
		(history_hpacucli_variables.hpacucli_variable_uuid,
		 history_hpacucli_variables.hpacucli_variable_host_uuid, 
		 history_hpacucli_variables.hpacucli_variable_source_table, 
		 history_hpacucli_variables.hpacucli_variable_source_uuid, 
		 history_hpacucli_variables.hpacucli_variable_is_temperature,
		 history_hpacucli_variables.hpacucli_variable_name,
		 history_hpacucli_variables.hpacucli_variable_value,
		 history_hpacucli_variables.modified_date);
	RETURN NULL;
END;
$$
LANGUAGE plpgsql;
ALTER FUNCTION history_hpacucli_variables() OWNER TO #!variable!user!#;

CREATE TRIGGER trigger_hpacucli_variables
	AFTER INSERT OR UPDATE ON hpacucli_variables
	FOR EACH ROW EXECUTE PROCEDURE history_hpacucli_variables();

-- - Array: [ZZZZ]
--  - Logical Drive: [9999]
--   - Physical Drive: [2I:1:8], sn: [11428100010010790594]
--     - Data; carrier_application_version: [11]
--     - Data; carrier_bootloader_version: [6]
--     - Data; device_number: [380]
--     - Data; drive_authentication_status: [OK]
--     - Data; drive_type: [Unassigned Drive]
--     - Data; firmware_revision: [1.0]
--     - Data; firmware_version: [RevB]	
--     - Data; interface_type: [Solid State SATA]
--     - Data; model: [SRCv8x6G]
--     - Data; phy_count: [1]
--     - Data; phy_transfer_rate: [6.0Gbps]
--     - Data; sata_ncq_capable: [True]
--     - Data; sata_ncq_enabled: [True]
--     - Data; size: [128.0 GB]
--     - Data; ssd_smart_trip_wearout: [Not Supported]
--     - Data; status: [OK]
--     - Data; vendor_id: [PMCSIERA]
--     - Data; wwid: [5001438030E9B24F]
