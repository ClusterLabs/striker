-- This is the database schema for the 'storcli Scan Agent'.

-- TODO: Things that change a lot (ie: temperatures) should go into the 'variables' tables with a known 
--       variable name to minimize DB size growth.
--       
--       Things that change rarely should go in the main tables (even if we won't explicitely watch for them
--       to change with specific alerts).

-- ------------------------------------------------------------------------------------------------------- --
-- Adapter                                                                                                 --
-- ------------------------------------------------------------------------------------------------------- --

-- Here is the basic controller information. All connected devices will reference back to this table's 
-- 'storcli_controller_serial_number' column.
CREATE TABLE storcli_controllers (
	storcli_controller_uuid			uuid				primary key,
	storcli_controller_host_uuid		uuid				not null,
	storcli_controller_serial_number	text				not null,	-- This is the core identifier
	storcli_controller_model		text				not null,	-- "Model"
	storcli_controller_alarm_state		text				not null,	-- "Alarm State"
	storcli_controller_cache_size		numeric				not null,	-- "On Board Memory Size"
	modified_date				timestamp with time zone	not null,
	
	FOREIGN KEY(storcli_controller_host_uuid) REFERENCES hosts(host_uuid)
);
ALTER TABLE storcli_controllers OWNER TO #!variable!user!#;

CREATE TABLE history.storcli_controllers (
	history_id				bigserial,
	storcli_controller_uuid			uuid,
	storcli_controller_host_uuid		uuid,
	storcli_controller_serial_number	text,
	storcli_controller_model		text,
	storcli_controller_alarm_state		text,
	storcli_controller_cache_size		numeric,
	modified_date				timestamp with time zone
);
ALTER TABLE history.storcli_controllers OWNER TO #!variable!user!#;

CREATE FUNCTION history_storcli_controllers() RETURNS trigger
AS $$
DECLARE
	history_storcli_controllers RECORD;
BEGIN
	SELECT INTO history_storcli_controllers * FROM storcli_controllers WHERE storcli_controller_uuid=new.storcli_controller_uuid;
	INSERT INTO history.storcli_controllers
		(storcli_controller_uuid, 
		 storcli_controller_host_uuid, 
		 storcli_controller_serial_number, 
		 storcli_controller_model, 
		 storcli_controller_alarm_state, 
		 storcli_controller_cache_size, 
		 modified_date)
	VALUES
		(history_storcli_controller.storcli_controller_uuid,
		 history_storcli_controller.storcli_controller_host_uuid,
		 history_storcli_controller.storcli_controller_serial_number, 
		 history_storcli_controller.storcli_controller_model, 
		 history_storcli_controller.storcli_controller_alarm_state, 
		 history_storcli_controller.storcli_controller_cache_size, 
		 history_storcli_controller.modified_date);
	RETURN NULL;
END;
$$
LANGUAGE plpgsql;
ALTER FUNCTION history_storcli_controllers() OWNER TO #!variable!user!#;

CREATE TRIGGER trigger_storcli_controllers
	AFTER INSERT OR UPDATE ON storcli_controllers
	FOR EACH ROW EXECUTE PROCEDURE history_storcli_controllers();


-- Key variables;
-- - "ROC temperature"
-- This stores various variables found for a given controller but not explicitely checked for (or that 
-- change frequently).
CREATE TABLE storcli_controller_variables (
	storcli_controller_variable_uuid		uuid				primary key,
	storcli_controller_variable_controller_uuid	uuid				not null,
	storcli_controller_is_temperature		boolean				not null	default FALSE,
	storcli_controller_variable_name		text				not null,
	storcli_controller_variable_value		text,
	modified_date					timestamp with time zone	not null,
	
	FOREIGN KEY(storcli_controller_variable_controller_uuid) REFERENCES storcli_controllers(storcli_controller_uuid)
);
ALTER TABLE storcli_controller_variables OWNER TO #!variable!user!#;

CREATE TABLE history.storcli_controller_variables (
	history_id					bigserial,
	storcli_controller_variable_uuid		uuid,
	storcli_controller_variable_controller_uuid	uuid,
	storcli_controller_is_temperature		boolean,
	storcli_controller_variable_name		text,
	storcli_controller_variable_value		text,
	modified_date					timestamp with time zone
);
ALTER TABLE history.storcli_controller_variables OWNER TO #!variable!user!#;

CREATE FUNCTION history_storcli_controller_variables() RETURNS trigger
AS $$
DECLARE
	history_storcli_controller_variables RECORD;
BEGIN
	SELECT INTO history_storcli_controller_variables * FROM storcli_controller_variables WHERE storcli_controller_variable_uuid=new.storcli_controller_variable_uuid;
	INSERT INTO history.storcli_controller_variables
		(storcli_controller_variable_uuid, 
		 storcli_controller_variable_controller_uuid,
		 storcli_controller_is_temperature,
		 storcli_controller_variable_name,
		 storcli_controller_variable_value,
		 modified_date)
	VALUES
		(history_storcli_controller_variables.storcli_controller_variable_uuid,
		 history_storcli_controller_variables.storcli_controller_variable_controller_uuid,
		 history_storcli_controller_variables.storcli_controller_is_temperature,
		 history_storcli_controller_variables.storcli_controller_variable_name,
		 history_storcli_controller_variables.storcli_controller_variable_value,
		 history_storcli_controller_variables.modified_date);
	RETURN NULL;
END;
$$
LANGUAGE plpgsql;
ALTER FUNCTION history_storcli_controller_variables() OWNER TO #!variable!user!#;

CREATE TRIGGER trigger_storcli_controller_variables
	AFTER INSERT OR UPDATE ON storcli_controller_variables
	FOR EACH ROW EXECUTE PROCEDURE history_storcli_controller_variables();


-- ------------------------------------------------------------------------------------------------------- --
-- Cachevault                                                                                              --
-- ------------------------------------------------------------------------------------------------------- --

-- This records the basic information about the cachevault (FBU) unit.
CREATE TABLE storcli_cachevaults (
	storcli_cachevault_uuid			uuid				primary key,
	storcli_cachevault_controller_uuid	uuid				not null,
	storcli_cachevault_state		text,						-- "State"
	storcli_cachevault_design_capacity	text,						-- "Design Capacity"
	storcli_cachevault_replacement_needed	text,						-- "Replacement required"
	storcli_cachevault_type			text,						-- "Type"
	storcli_cachevault_manufacture_date	text,						-- "Date of Manufacture"
	modified_date				timestamp with time zone	not null,
	
	FOREIGN KEY(storcli_cachevault_controller_uuid) REFERENCES storcli_controllers(storcli_controller_uuid)
);
ALTER TABLE storcli_cachevaults OWNER TO #!variable!user!#;

CREATE TABLE history.storcli_cachevaults (
	history_id				bigserial,
	storcli_cachevault_uuid			uuid,
	storcli_cachevault_controller_uuid	uuid,
	storcli_cachevault_state		text,
	storcli_cachevault_design_capacity	text,
	storcli_cachevault_replacement_needed	text,
	storcli_cachevault_type			text,
	storcli_cachevault_manufacture_date	text,
	modified_date				timestamp with time zone
);
ALTER TABLE history.storcli_cachevaults OWNER TO #!variable!user!#;

CREATE FUNCTION history_storcli_cachevaults() RETURNS trigger
AS $$
DECLARE
	history_storcli_cachevaults RECORD;
BEGIN
	SELECT INTO history_storcli_cachevaults * FROM storcli_cachevaults WHERE storcli_cachevault_uuid=new.storcli_cachevault_uuid;
	INSERT INTO history.storcli_cachevaults
		(storcli_cachevault_uuid, 
		 storcli_cachevault_controller_uuid, 
		 storcli_cachevault_state, 
		 storcli_cachevault_design_capacity, 
		 storcli_cachevault_replacement_needed, 
		 storcli_cachevault_type, 
		 storcli_cachevault_manufacture_date, 
		 modified_date)
	VALUES
		(history_storcli_cachevault.storcli_cachevault_uuid,
		 history_storcli_cachevault.storcli_cachevault_controller_uuid, 
		 history_storcli_cachevault.storcli_cachevault_state, 
		 history_storcli_cachevault.storcli_cachevault_design_capacity, 
		 history_storcli_cachevault.storcli_cachevault_replacement_needed, 
		 history_storcli_cachevault.storcli_cachevault_type, 
		 history_storcli_cachevault.storcli_cachevault_manufacture_date, 
		 history_storcli_cachevault.modified_date);
	RETURN NULL;
END;
$$
LANGUAGE plpgsql;
ALTER FUNCTION history_storcli_cachevaults() OWNER TO #!variable!user!#;

CREATE TRIGGER trigger_storcli_cachevaults
	AFTER INSERT OR UPDATE ON storcli_cachevaults
	FOR EACH ROW EXECUTE PROCEDURE history_storcli_cachevaults();


-- Key variables;
-- - "Temperature"
-- - "Capacitance"
-- - "Pack Energy"
-- - "Next Learn time"
-- This stores various variables found for a given cachevault module but not explicitely checked for (or that
-- change frequently).
CREATE TABLE storcli_cachevault_variables (
	storcli_cachevault_variable_uuid		uuid				primary key,
	storcli_cachevault_variable_cachevault_uuid	uuid				not null,
	storcli_cachevault_is_temperature		boolean				not null	default FALSE,
	storcli_cachevault_variable_name		text				not null,
	storcli_cachevault_variable_value		text,
	modified_date					timestamp with time zone	not null,
	
	FOREIGN KEY(storcli_cachevault_variable_cachevault_uuid) REFERENCES storcli_cachevaults(storcli_cachevault_uuid)
);
ALTER TABLE storcli_cachevault_variables OWNER TO #!variable!user!#;

CREATE TABLE history.storcli_cachevault_variables (
	history_id					bigserial,
	storcli_cachevault_variable_uuid		uuid,
	storcli_cachevault_variable_cachevault_uuid	uuid,
	storcli_cachevault_is_temperature		boolean,
	storcli_cachevault_variable_name		text,
	storcli_cachevault_variable_value		text,
	modified_date					timestamp with time zone
);
ALTER TABLE history.storcli_cachevault_variables OWNER TO #!variable!user!#;

CREATE FUNCTION history_storcli_cachevault_variables() RETURNS trigger
AS $$
DECLARE
	history_storcli_cachevault_variables RECORD;
BEGIN
	SELECT INTO history_storcli_cachevault_variables * FROM storcli_cachevault_variables WHERE storcli_cachevault_variable_uuid=new.storcli_cachevault_variable_uuid;
	INSERT INTO history.storcli_cachevault_variables
		(storcli_cachevault_variable_uuid, 
		 storcli_cachevault_variable_cachevault_uuid,
		 storcli_cachevault_is_temperature,
		 storcli_cachevault_variable_name,
		 storcli_cachevault_variable_value,
		 modified_date)
	VALUES
		(history_storcli_cachevault_variables.storcli_cachevault_variable_uuid,
		 history_storcli_cachevault_variables.storcli_cachevault_variable_cachevault_uuid,
		 history_storcli_cachevault_variables.storcli_cachevault_is_temperature,
		 history_storcli_cachevault_variables.storcli_cachevault_variable_name,
		 history_storcli_cachevault_variables.storcli_cachevault_variable_value,
		 history_storcli_cachevault_variables.modified_date);
	RETURN NULL;
END;
$$
LANGUAGE plpgsql;
ALTER FUNCTION history_storcli_cachevault_variables() OWNER TO #!variable!user!#;

CREATE TRIGGER trigger_storcli_cachevault_variables
	AFTER INSERT OR UPDATE ON storcli_cachevault_variables
	FOR EACH ROW EXECUTE PROCEDURE history_storcli_cachevault_variables();


-- ------------------------------------------------------------------------------------------------------- --
-- Battery Backup Units                                                                                    --
-- ------------------------------------------------------------------------------------------------------- --

-- This records the basic information about the cachevault (FBU) unit.
CREATE TABLE storcli_bbus (
	storcli_bbu_uuid			uuid				primary key,
	storcli_bbu_controller_uuid		uuid				not null,
	storcli_bbu_type			text,						-- "Type"
	storcli_bbu_model			text,						-- "Manufacture Name"
	storcli_bbu_state			text,						-- "Battery State"
	storcli_bbu_manufacture_date		text,						-- "Date of Manufacture"
	storcli_bbu_design_capacity		text,						-- "Design Capacity"
	storcli_bbu_replacement_needed		text,						-- "Pack is about to fail & should be replaced"
	modified_date				timestamp with time zone	not null,
	
	FOREIGN KEY(storcli_bbu_controller_uuid) REFERENCES storcli_controllers(storcli_controller_uuid)
);
ALTER TABLE storcli_bbus OWNER TO #!variable!user!#;

CREATE TABLE history.storcli_bbus (
	history_id				bigserial,
	storcli_bbu_uuid			uuid,
	storcli_bbu_controller_uuid		uuid,
	storcli_bbu_type			text,
	storcli_bbu_model			text,
	storcli_bbu_state			text,
	storcli_bbu_manufacture_date		text,
	storcli_bbu_design_capacity		text,
	storcli_bbu_replacement_needed		text,
	modified_date				timestamp with time zone
);
ALTER TABLE history.storcli_bbus OWNER TO #!variable!user!#;

CREATE FUNCTION history_storcli_bbus() RETURNS trigger
AS $$
DECLARE
	history_storcli_bbus RECORD;
BEGIN
	SELECT INTO history_storcli_bbus * FROM storcli_bbus WHERE storcli_bbu_uuid=new.storcli_bbu_uuid;
	INSERT INTO history.storcli_bbus
		(storcli_bbu_uuid, 
		 storcli_bbu_controller_uuid, 
		 storcli_bbu_type, 
		 storcli_bbu_model, 
		 storcli_bbu_state, 
		 storcli_bbu_manufacture_date, 
		 storcli_bbu_design_capacity, 
		 storcli_bbu_replacement_needed, 
		 modified_date)
	VALUES
		(history_storcli_bbu.storcli_bbu_uuid,
		 history_storcli_bbu.storcli_bbu_controller_uuid, 
		 history_storcli_bbu.storcli_bbu_type, 
		 history_storcli_bbu.storcli_bbu_model, 
		 history_storcli_bbu.storcli_bbu_state, 
		 history_storcli_bbu.storcli_bbu_manufacture_date, 
		 history_storcli_bbu.storcli_bbu_design_capacity, 
		 history_storcli_bbu.storcli_bbu_replacement_needed, 
		 history_storcli_bbu.modified_date);
	RETURN NULL;
END;
$$
LANGUAGE plpgsql;
ALTER FUNCTION history_storcli_bbus() OWNER TO #!variable!user!#;

CREATE TRIGGER trigger_storcli_bbus
	AFTER INSERT OR UPDATE ON storcli_bbus
	FOR EACH ROW EXECUTE PROCEDURE history_storcli_bbus();


-- Key variables;
-- - "Temperature"
-- - "Absolute state of charge"
-- - "Cycle Count"
-- - "Full Charge Capacity"
-- - "Fully Charged"
-- - "Learn Cycle Active"
-- - "Next Learn time"
-- - "Over Charged"
-- - "Over Temperature"
-- This stores various variables found for a given BBU module but not explicitely checked for (or that change
-- frequently).
CREATE TABLE storcli_bbu_variables (
	storcli_bbu_variable_uuid		uuid				primary key,
	storcli_bbu_variable_bbu_uuid		uuid				not null,
	storcli_bbu_is_temperature		boolean				not null	default FALSE,
	storcli_bbu_variable_name		text				not null,
	storcli_bbu_variable_value		text,
	modified_date				timestamp with time zone	not null,
	
	FOREIGN KEY(storcli_bbu_variable_bbu_uuid) REFERENCES storcli_bbus(storcli_bbu_uuid)
);
ALTER TABLE storcli_bbu_variables OWNER TO #!variable!user!#;

CREATE TABLE history.storcli_bbu_variables (
	history_id				bigserial,
	storcli_bbu_variable_uuid		uuid,
	storcli_bbu_variable_bbu_uuid		uuid,
	storcli_bbu_is_temperature		boolean,
	storcli_bbu_variable_name		text,
	storcli_bbu_variable_value		text,
	modified_date				timestamp with time zone
);
ALTER TABLE history.storcli_bbu_variables OWNER TO #!variable!user!#;

CREATE FUNCTION history_storcli_bbu_variables() RETURNS trigger
AS $$
DECLARE
	history_storcli_bbu_variables RECORD;
BEGIN
	SELECT INTO history_storcli_bbu_variables * FROM storcli_bbu_variables WHERE storcli_bbu_variable_uuid=new.storcli_bbu_variable_uuid;
	INSERT INTO history.storcli_bbu_variables
		(storcli_bbu_variable_uuid, 
		 storcli_bbu_variable_bbu_uuid,
		 storcli_bbu_is_temperature,
		 storcli_bbu_variable_name,
		 storcli_bbu_variable_value,
		 modified_date)
	VALUES
		(history_storcli_bbu_variables.storcli_bbu_variable_uuid,
		 history_storcli_bbu_variables.storcli_bbu_variable_bbu_uuid,
		 history_storcli_bbu_variables.storcli_bbu_is_temperature,
		 history_storcli_bbu_variables.storcli_bbu_variable_name,
		 history_storcli_bbu_variables.storcli_bbu_variable_value,
		 history_storcli_bbu_variables.modified_date);
	RETURN NULL;
END;
$$
LANGUAGE plpgsql;
ALTER FUNCTION history_storcli_bbu_variables() OWNER TO #!variable!user!#;

CREATE TRIGGER trigger_storcli_bbu_variables
	AFTER INSERT OR UPDATE ON storcli_bbu_variables
	FOR EACH ROW EXECUTE PROCEDURE history_storcli_bbu_variables();


-- ------------------------------------------------------------------------------------------------------- --
-- Virtual Drives                                                                                          --
-- ------------------------------------------------------------------------------------------------------- --

-- This records the basic virtual drives. These contain one or more drive groups to form an array
CREATE TABLE storcli_virtual_drives (
	storcli_virtual_drive_uuid		uuid				primary key,
	storcli_virtual_drive_controller_uuid	uuid				not null,
	storcli_virtual_drive_creation_date	text,						-- "Creation Date" and "Creation Time"
	storcli_virtual_drive_data_protection	text,						-- "Data Protection"
	storcli_virtual_drive_disk_cache_policy	text,						-- "Disk Cache Policy"
	storcli_virtual_drive_emulation_type	text,						-- "Emulation type"
	storcli_virtual_drive_encryption	text,						-- "Encryption"
	storcli_virtual_drive_blocks		numeric,					-- "Number of Blocks"
	storcli_virtual_drive_strip_size	numeric,					-- "Strip Size"
	storcli_virtual_drive_drives_per_span	numeric,					-- "Number of Drives Per Span"
	storcli_virtual_drive_span_depth	numeric,					-- "Span Depth"
	storcli_virtual_drive_scsi_naa_id	text,						-- "SCSI NAA Id" - https://en.wikipedia.org/wiki/ISCSI#Addressing
	modified_date				timestamp with time zone	not null,
	
	FOREIGN KEY(storcli_virtual_drive_controller_uuid) REFERENCES storcli_controllers(storcli_controller_uuid)
);
ALTER TABLE storcli_virtual_drives OWNER TO #!variable!user!#;

CREATE TABLE history.storcli_virtual_drives (
	history_id				bigserial,
	storcli_virtual_drive_uuid		uuid,
	storcli_virtual_drive_controller_uuid	uuid,
	storcli_virtual_drive_creation_date	text,
	storcli_virtual_drive_data_protection	text,
	storcli_virtual_drive_disk_cache_policy	text,
	storcli_virtual_drive_emulation_type	text,
	storcli_virtual_drive_encryption	text,
	storcli_virtual_drive_blocks		numeric,
	storcli_virtual_drive_strip_size	numeric,
	storcli_virtual_drive_drives_per_span	numeric,
	storcli_virtual_drive_span_depth	numeric,
	storcli_virtual_drive_scsi_naa_id	text,
	modified_date				timestamp with time zone
);
ALTER TABLE history.storcli_virtual_drives OWNER TO #!variable!user!#;

CREATE FUNCTION history_storcli_virtual_drives() RETURNS trigger
AS $$
DECLARE
	history_storcli_virtual_drives RECORD;
BEGIN
	SELECT INTO history_storcli_virtual_drives * FROM storcli_virtual_drives WHERE storcli_virtual_drive_uuid=new.storcli_virtual_drive_uuid;
	INSERT INTO history.storcli_virtual_drives
		(storcli_virtual_drive_uuid, 
		 storcli_virtual_drive_controller_uuid, 
		 storcli_virtual_drive_creation_date, 
		 storcli_virtual_drive_data_protection, 
		 storcli_virtual_drive_disk_cache_policy, 
		 storcli_virtual_drive_emulation_type, 
		 storcli_virtual_drive_encryption, 
		 storcli_virtual_drive_blocks, 
		 storcli_virtual_drive_strip_size, 
		 storcli_virtual_drive_drives_per_span, 
		 storcli_virtual_drive_span_depth, 
		 storcli_virtual_drive_scsi_naa_id, 
		 modified_date)
	VALUES
		(history_storcli_virtual_drive.storcli_virtual_drive_uuid,
		 history_storcli_virtual_drive.storcli_virtual_drive_controller_uuid, 
		 history_storcli_virtual_drive.storcli_virtual_drive_creation_date, 
		 history_storcli_virtual_drive.storcli_virtual_drive_data_protection, 
		 history_storcli_virtual_drive.storcli_virtual_drive_disk_cache_policy, 
		 history_storcli_virtual_drive.storcli_virtual_drive_emulation_type, 
		 history_storcli_virtual_drive.storcli_virtual_drive_encryption, 
		 history_storcli_virtual_drive.storcli_virtual_drive_blocks, 
		 history_storcli_virtual_drive.storcli_virtual_drive_strip_size, 
		 history_storcli_virtual_drive.storcli_virtual_drive_drives_per_span, 
		 history_storcli_virtual_drive.storcli_virtual_drive_span_depth, 
		 history_storcli_virtual_drive.storcli_virtual_drive_scsi_naa_id, 
		 history_storcli_virtual_drive.modified_date);
	RETURN NULL;
END;
$$
LANGUAGE plpgsql;
ALTER FUNCTION history_storcli_virtual_drives() OWNER TO #!variable!user!#;

CREATE TRIGGER trigger_storcli_virtual_drives
	AFTER INSERT OR UPDATE ON storcli_virtual_drives
	FOR EACH ROW EXECUTE PROCEDURE history_storcli_virtual_drives();


-- NOTE: There is likely never going to be a temperature here, but there is no harm in having the toggle
--       This stores various variables found for a given virtual disk but not explicitely checked for.
CREATE TABLE storcli_virtual_drive_variables (
	storcli_virtual_drive_variable_uuid			uuid				primary key,
	storcli_virtual_drive_variable_virtual_drive_uuid	uuid				not null,
	storcli_virtual_drive_is_temperature			boolean				not null	default FALSE,
	storcli_virtual_drive_variable_name			text				not null,
	storcli_virtual_drive_variable_value			text,
	modified_date						timestamp with time zone	not null,
	
	FOREIGN KEY(storcli_virtual_drive_variable_virtual_drive_uuid) REFERENCES storcli_virtual_drives(storcli_virtual_drive_uuid)
);
ALTER TABLE storcli_virtual_drive_variables OWNER TO #!variable!user!#;

CREATE TABLE history.storcli_virtual_drive_variables (
	history_id						bigserial,
	storcli_virtual_drive_variable_uuid			uuid,
	storcli_virtual_drive_variable_virtual_drive_uuid	uuid,
	storcli_virtual_drive_is_temperature			boolean,
	storcli_virtual_drive_variable_name			text,
	storcli_virtual_drive_variable_value			text,
	modified_date						timestamp with time zone
);
ALTER TABLE history.storcli_virtual_drive_variables OWNER TO #!variable!user!#;

CREATE FUNCTION history_storcli_virtual_drive_variables() RETURNS trigger
AS $$
DECLARE
	history_storcli_virtual_drive_variables RECORD;
BEGIN
	SELECT INTO history_storcli_virtual_drive_variables * FROM storcli_virtual_drive_variables WHERE storcli_virtual_drive_variable_uuid=new.storcli_virtual_drive_variable_uuid;
	INSERT INTO history.storcli_virtual_drive_variables
		(storcli_virtual_drive_variable_uuid, 
		 storcli_virtual_drive_variable_virtual_drive_uuid,
		 storcli_virtual_drive_is_temperature,
		 storcli_virtual_drive_variable_name,
		 storcli_virtual_drive_variable_value,
		 modified_date)
	VALUES
		(history_storcli_virtual_drive_variables.storcli_virtual_drive_variable_uuid,
		 history_storcli_virtual_drive_variables.storcli_virtual_drive_variable_virtual_drive_uuid,
		 history_storcli_virtual_drive_variables.storcli_virtual_drive_is_temperature,
		 history_storcli_virtual_drive_variables.storcli_virtual_drive_variable_name,
		 history_storcli_virtual_drive_variables.storcli_virtual_drive_variable_value,
		 history_storcli_virtual_drive_variables.modified_date);
	RETURN NULL;
END;
$$
LANGUAGE plpgsql;
ALTER FUNCTION history_storcli_virtual_drive_variables() OWNER TO #!variable!user!#;

CREATE TRIGGER trigger_storcli_virtual_drive_variables
	AFTER INSERT OR UPDATE ON storcli_virtual_drive_variables
	FOR EACH ROW EXECUTE PROCEDURE history_storcli_virtual_drive_variables();


-- ------------------------------------------------------------------------------------------------------- --
-- Drive Groups                                                                                            --
-- ------------------------------------------------------------------------------------------------------- --

-- This records the basic drive group information.
CREATE TABLE storcli_drive_groups (
	storcli_drive_group_uuid		uuid				primary key,
	storcli_drive_group_virtual_drive_uuid	uuid,
	storcli_drive_group_access		text,						-- "access"
	storcli_drive_group_array_size		text,						-- "array_size"
	storcli_drive_group_array_state		text,						-- "array_state"
	storcli_drive_group_cache		text,						-- "cache"
	storcli_drive_group_cachecade		text,						-- "cachecade"
	storcli_drive_group_consistent		text,						-- "consistent"
	storcli_drive_group_disk_cache		text,						-- "disk_cache"
	storcli_drive_group_raid_type		text,						-- "raid_type"
	storcli_drive_group_read_cache		text,						-- "read_cache"
	storcli_drive_group_scheduled_cc	text,						-- "scheduled_consistency_check"
	storcli_drive_group_write_cache		text,						-- "write_cache"
	modified_date				timestamp with time zone	not null,
	
	FOREIGN KEY(storcli_drive_group_virtual_drive_uuid) REFERENCES storcli_virtual_drives(storcli_virtual_drive_uuid)
);
ALTER TABLE storcli_drive_groups OWNER TO #!variable!user!#;

CREATE TABLE history.storcli_drive_groups (
	history_id				bigserial,
	storcli_drive_group_uuid		uuid,
	storcli_drive_group_virtual_drive_uuid	uuid,
	storcli_drive_group_access		text,
	storcli_drive_group_array_size		text,
	storcli_drive_group_array_state		text,
	storcli_drive_group_cache		text,
	storcli_drive_group_cachecade		text,
	storcli_drive_group_consistent		text,
	storcli_drive_group_disk_cache		text,
	storcli_drive_group_raid_type		text,
	storcli_drive_group_read_cache		text,
	storcli_drive_group_scheduled_cc	text,
	storcli_drive_group_write_cache		text,
	modified_date				timestamp with time zone
);
ALTER TABLE history.storcli_drive_groups OWNER TO #!variable!user!#;

CREATE FUNCTION history_storcli_drive_groups() RETURNS trigger
AS $$
DECLARE
	history_storcli_drive_groups RECORD;
BEGIN
	SELECT INTO history_storcli_drive_groups * FROM storcli_drive_groups WHERE storcli_drive_group_uuid=new.storcli_drive_group_uuid;
	INSERT INTO history.storcli_drive_groups
		(storcli_drive_group_uuid, 
		 storcli_drive_group_virtual_drive_uuid, 
		 storcli_drive_group_access, 
		 storcli_drive_group_array_size, 
		 storcli_drive_group_array_state, 
		 storcli_drive_group_cache, 
		 storcli_drive_group_cachecade, 
		 storcli_drive_group_consistent, 
		 storcli_drive_group_disk_cache, 
		 storcli_drive_group_raid_type, 
		 storcli_drive_group_read_cache, 
		 storcli_drive_group_scheduled_cc, 
		 storcli_drive_group_write_cache, 
		 modified_date)
	VALUES
		(history_storcli_drive_group.storcli_drive_group_uuid,
		 history_storcli_drive_group.storcli_drive_group_virtual_drive_uuid, 
		 history_storcli_drive_group.storcli_drive_group_access, 
		 history_storcli_drive_group.storcli_drive_group_array_size, 
		 history_storcli_drive_group.storcli_drive_group_array_state, 
		 history_storcli_drive_group.storcli_drive_group_cache, 
		 history_storcli_drive_group.storcli_drive_group_cachecade, 
		 history_storcli_drive_group.storcli_drive_group_consistent, 
		 history_storcli_drive_group.storcli_drive_group_disk_cache, 
		 history_storcli_drive_group.storcli_drive_group_raid_type, 
		 history_storcli_drive_group.storcli_drive_group_read_cache, 
		 history_storcli_drive_group.storcli_drive_group_scheduled_cc, 
		 history_storcli_drive_group.storcli_drive_group_write_cache, 
		 history_storcli_drive_group.modified_date);
	RETURN NULL;
END;
$$
LANGUAGE plpgsql;
ALTER FUNCTION history_storcli_drive_groups() OWNER TO #!variable!user!#;

CREATE TRIGGER trigger_storcli_drive_groups
	AFTER INSERT OR UPDATE ON storcli_drive_groups
	FOR EACH ROW EXECUTE PROCEDURE history_storcli_drive_groups();


-- NOTE: There is likely not needed, but it could be useful in a pinch if LSI changes the formatting to 
--       add/remove stuff.
-- This stores various variables found for a given virtual disk but not explicitely checked for.
CREATE TABLE storcli_drive_group_variables (
	storcli_drive_group_variable_uuid		uuid				primary key,
	storcli_drive_group_variable_drive_group_uuid	uuid				not null,
	storcli_drive_group_is_temperature		boolean				not null	default FALSE,
	storcli_drive_group_variable_name		text				not null,
	storcli_drive_group_variable_value		text,
	modified_date					timestamp with time zone	not null,
	
	FOREIGN KEY(storcli_drive_group_variable_drive_group_uuid) REFERENCES storcli_drive_groups(storcli_drive_group_uuid)
);
ALTER TABLE storcli_drive_group_variables OWNER TO #!variable!user!#;

CREATE TABLE history.storcli_drive_group_variables (
	history_id					bigserial,
	storcli_drive_group_variable_uuid		uuid,
	storcli_drive_group_variable_drive_group_uuid	uuid,
	storcli_drive_group_is_temperature		boolean,
	storcli_drive_group_variable_name		text,
	storcli_drive_group_variable_value		text,
	modified_date					timestamp with time zone
);
ALTER TABLE history.storcli_drive_group_variables OWNER TO #!variable!user!#;

CREATE FUNCTION history_storcli_drive_group_variables() RETURNS trigger
AS $$
DECLARE
	history_storcli_drive_group_variables RECORD;
BEGIN
	SELECT INTO history_storcli_drive_group_variables * FROM storcli_drive_group_variables WHERE storcli_drive_group_variable_uuid=new.storcli_drive_group_variable_uuid;
	INSERT INTO history.storcli_drive_group_variables
		(storcli_drive_group_variable_uuid, 
		 storcli_drive_group_variable_drive_group_uuid,
		 storcli_drive_group_is_temperature,
		 storcli_drive_group_variable_name,
		 storcli_drive_group_variable_value,
		 modified_date)
	VALUES
		(history_storcli_drive_group_variables.storcli_drive_group_variable_uuid,
		 history_storcli_drive_group_variables.storcli_drive_group_variable_drive_group_uuid,
		 history_storcli_drive_group_variables.storcli_drive_group_is_temperature,
		 history_storcli_drive_group_variables.storcli_drive_group_variable_name,
		 history_storcli_drive_group_variables.storcli_drive_group_variable_value,
		 history_storcli_drive_group_variables.modified_date);
	RETURN NULL;
END;
$$
LANGUAGE plpgsql;
ALTER FUNCTION history_storcli_drive_group_variables() OWNER TO #!variable!user!#;

CREATE TRIGGER trigger_storcli_drive_group_variables
	AFTER INSERT OR UPDATE ON storcli_drive_group_variables
	FOR EACH ROW EXECUTE PROCEDURE history_storcli_drive_group_variables();


-- ------------------------------------------------------------------------------------------------------- --
-- Physical Drives                                                                                         --
-- ------------------------------------------------------------------------------------------------------- --

-- NOTE: More information to T10-PI (protection information) is available here:
--       https://www.seagate.com/files/staticfiles/docs/pdf/whitepaper/safeguarding-data-from-corruption-technology-paper-tp621us.pdf

-- This records the basic drive group information.
CREATE TABLE storcli_physical_drives (
	storcli_physical_drive_uuid			uuid				primary key,
	storcli_physical_drive_controller_uuid		uuid,
	storcli_physical_drive_drive_size		numeric,					-- "drive_size" but also; "Raw size", "Non Coerced size" and "Coerced size"
	storcli_physical_drive_sector_size		numeric,					-- "sector_size", "Sector Size"
	storcli_physical_drive_drive_vendor		text,						-- "Manufacturer Identification"
	storcli_physical_drive_drive_model		text,						-- "drive_model", "Model Number"
	storcli_physical_drive_serial_number		text,						-- "Serial Number"
	storcli_physical_drive_self_encrypting_drive	text,						-- "self_encrypting_drive", "SED Capable"
	modified_date					timestamp with time zone	not null,
	
	FOREIGN KEY(storcli_physical_drive_controller_uuid) REFERENCES storcli_controllers(storcli_controller_uuid)
);
ALTER TABLE storcli_physical_drives OWNER TO #!variable!user!#;

CREATE TABLE history.storcli_physical_drives (
	history_id					bigserial,
	storcli_physical_drive_uuid			uuid,
	storcli_physical_drive_controller_uuid		uuid,
	storcli_physical_drive_drive_size		numeric,
	storcli_physical_drive_sector_size		numeric,
	storcli_physical_drive_drive_vendor		text,
	storcli_physical_drive_drive_model		text,
	storcli_physical_drive_serial_number		text,
	storcli_physical_drive_self_encrypting_drive	text,
	modified_date					timestamp with time zone
);
ALTER TABLE history.storcli_physical_drives OWNER TO #!variable!user!#;

CREATE FUNCTION history_storcli_physical_drives() RETURNS trigger
AS $$
DECLARE
	history_storcli_physical_drives RECORD;
BEGIN
	SELECT INTO history_storcli_physical_drives * FROM storcli_physical_drives WHERE storcli_physical_drive_uuid=new.storcli_physical_drive_uuid;
	INSERT INTO history.storcli_physical_drives
		(storcli_physical_drive_uuid, 
		 storcli_physical_drive_controller_uuid, 
		 storcli_physical_drive_drive_size, 
		 storcli_physical_drive_sector_size, 
		 storcli_physical_drive_drive_vendor, 
		 storcli_physical_drive_drive_model, 
		 storcli_physical_drive_serial_number, 
		 storcli_physical_drive_self_encrypting_drive, 
		 modified_date)
	VALUES
		(history_storcli_physical_drive.storcli_physical_drive_uuid,
		 history_storcli_physical_drive.storcli_physical_drive_drive_size, 
		 history_storcli_physical_drive.storcli_physical_drive_sector_size, 
		 history_storcli_physical_drive.storcli_physical_drive_drive_vendor, 
		 history_storcli_physical_drive.storcli_physical_drive_drive_model, 
		 history_storcli_physical_drive.storcli_physical_drive_serial_number, 
		 history_storcli_physical_drive.storcli_physical_drive_self_encrypting_drive, 
		 history_storcli_physical_drive.modified_date);
	RETURN NULL;
END;
$$
LANGUAGE plpgsql;
ALTER FUNCTION history_storcli_physical_drives() OWNER TO #!variable!user!#;

CREATE TRIGGER trigger_storcli_physical_drives
	AFTER INSERT OR UPDATE ON storcli_physical_drives
	FOR EACH ROW EXECUTE PROCEDURE history_storcli_physical_drives();


-- Key variables;
-- - "Drive Temperature"
-- - "spun_up"
-- - "state"
-- - "Certified"
-- - "Device Speed"
-- - "Link Speed"
-- - "sas_port_0_link_speed"
-- - "sas_port_0_port_status"
-- - "sas_port_0_sas_address"
-- - "sas_port_1_link_speed"
-- - "sas_port_1_port_status"
-- - "sas_port_1_sas_address"
-- - "drive_media"
-- - "interface"
-- - "NAND Vendor"
-- - "Firmware Revision"
-- - "World Wide Name"
-- - "device_id"
-- - "SED Enabled"
-- - "Secured"
-- - "Locked"
-- - "Needs External Key Management Attention"
-- - "protection_info", "Protection Information Eligible"
-- - "Emergency Spare"
-- - "Commissioned Spare"
-- - "S.M.A.R.T alert flagged by drive"
-- - "Media Error Count"
-- - "Other Error Count"
-- - "Predictive Failure Count"
-- This stores various variables found for a given virtual disk but not explicitely checked for.
CREATE TABLE storcli_physical_drive_variables (
	storcli_physical_drive_variable_uuid			uuid				primary key,
	storcli_physical_drive_variable_physical_drive_uuid	uuid				not null,
	storcli_physical_drive_is_temperature			boolean				not null	default FALSE,
	storcli_physical_drive_variable_name			text				not null,
	storcli_physical_drive_variable_value			text,
	modified_date						timestamp with time zone	not null,
	
	FOREIGN KEY(storcli_physical_drive_variable_physical_drive_uuid) REFERENCES storcli_physical_drives(storcli_physical_drive_uuid)
);
ALTER TABLE storcli_physical_drive_variables OWNER TO #!variable!user!#;

CREATE TABLE history.storcli_physical_drive_variables (
	history_id						bigserial,
	storcli_physical_drive_variable_uuid			uuid,
	storcli_physical_drive_variable_physical_drive_uuid	uuid,
	storcli_physical_drive_is_temperature			boolean,
	storcli_physical_drive_variable_name			text,
	storcli_physical_drive_variable_value			text,
	modified_date						timestamp with time zone
);
ALTER TABLE history.storcli_physical_drive_variables OWNER TO #!variable!user!#;

CREATE FUNCTION history_storcli_physical_drive_variables() RETURNS trigger
AS $$
DECLARE
	history_storcli_physical_drive_variables RECORD;
BEGIN
	SELECT INTO history_storcli_physical_drive_variables * FROM storcli_physical_drive_variables WHERE storcli_physical_drive_variable_uuid=new.storcli_physical_drive_variable_uuid;
	INSERT INTO history.storcli_physical_drive_variables
		(storcli_physical_drive_variable_uuid, 
		 storcli_physical_drive_variable_physical_drive_uuid,
		 storcli_physical_drive_is_temperature,
		 storcli_physical_drive_variable_name,
		 storcli_physical_drive_variable_value,
		 modified_date)
	VALUES
		(history_storcli_physical_drive_variables.storcli_physical_drive_variable_uuid,
		 history_storcli_physical_drive_variables.storcli_physical_drive_variable_physical_drive_uuid,
		 history_storcli_physical_drive_variables.storcli_physical_drive_is_temperature,
		 history_storcli_physical_drive_variables.storcli_physical_drive_variable_name,
		 history_storcli_physical_drive_variables.storcli_physical_drive_variable_value,
		 history_storcli_physical_drive_variables.modified_date);
	RETURN NULL;
END;
$$
LANGUAGE plpgsql;
ALTER FUNCTION history_storcli_physical_drive_variables() OWNER TO #!variable!user!#;

CREATE TRIGGER trigger_storcli_physical_drive_variables
	AFTER INSERT OR UPDATE ON storcli_physical_drive_variables
	FOR EACH ROW EXECUTE PROCEDURE history_storcli_physical_drive_variables();

