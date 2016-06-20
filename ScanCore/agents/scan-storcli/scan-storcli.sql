-- This is the database schema for the 'storcli Scan Agent'.

-- ------------------------------------------------------------------------------------------------------- --
-- Adapter                                                                                                 --
-- ------------------------------------------------------------------------------------------------------- --

-- Here is the basic adapter information. All connected devices will reference back to this table's 
-- 'storcli_adapter_serial_number' column.
CREATE TABLE storcli_adapters (
	storcli_adapter_uuid			uuid				primary key,
	storcli_adapter_host_uuid		uuid				not null,
	storcli_adapter_model			text				not null,
	storcli_adapter_serial_number		text				not null,	-- This is the core identifier
	storcli_adapter_alarm_state		text				not null,
	storcli_adapter_cache_size		numeric				not null,	-- "On Board Memory Size"
	storcli_adapter_roc_temperature		numeric				not null,	-- ROC == Raid on Chip, the controllers ASIC/CPU
	modified_date				timestamp with time zone	not null,
	
	FOREIGN KEY(storcli_host_uuid) REFERENCES hosts(host_uuid)
);
ALTER TABLE storcli_adapters OWNER TO #!variable!user!#;

CREATE TABLE history.storcli_adapters (
	history_id				bigserial,
	storcli_adapter_uuid			uuid,
	storcli_adapter_host_uuid		uuid,
	storcli_adapter_model			text,
	storcli_adapter_serial_number		text,
	storcli_adapter_alarm_state		text,
	storcli_adapter_cache_size		numeric,
	storcli_adapter_roc_temperature		numeric,
	modified_date				timestamp with time zone
);
ALTER TABLE history.storcli_adapters OWNER TO #!variable!user!#;

CREATE FUNCTION history_storcli_adapters() RETURNS trigger
AS $$
DECLARE
	history_storcli_adapters RECORD;
BEGIN
	SELECT INTO history_storcli_adapters * FROM storcli_adapters WHERE storcli_adapter_uuid=new.storcli_adapter_uuid;
	INSERT INTO history.storcli_adapters
		(storcli_adapter_uuid, 
		 storcli_adapter_host_uuid, 
		 storcli_adapter_model, 
		 storcli_adapter_serial_number, 
		 storcli_adapter_alarm_state, 
		 storcli_adapter_roc_temperature, 
		 storcli_adapter_cache_size, 
		 modified_date)
	VALUES
		(history_storcli_adapter.storcli_adapter_uuid,
		 history_storcli_adapter.storcli_adapter_host_uuid,
		 history_storcli_adapter.storcli_adapter_model, 
		 history_storcli_adapter.storcli_adapter_serial_number, 
		 history_storcli_adapter.storcli_adapter_alarm_state, 
		 history_storcli_adapter.storcli_adapter_roc_temperature, 
		 history_storcli_adapter.storcli_adapter_cache_size, 
		 history_storcli_adapter.modified_date);
	RETURN NULL;
END;
$$
LANGUAGE plpgsql;
ALTER FUNCTION history_storcli_adapters() OWNER TO #!variable!user!#;

CREATE TRIGGER trigger_storcli_adapters
	AFTER INSERT OR UPDATE ON storcli_adapters
	FOR EACH ROW EXECUTE PROCEDURE history_storcli_adapters();


-- This stores various variables found for a given controller but not explicitely checked for.
CREATE TABLE storcli_adapter_variables (
	storcli_adapter_variable_uuid		uuid				primary key,
	storcli_adapter_variable_adapter_uuid	uuid				not null,
	storcli_adapter_is_temperature		boolean				not null	default FALSE,
	storcli_adapter_variable_name		text				not null,
	storcli_adapter_variable_value		text,
	modified_date				timestamp with time zone	not null,
	
	FOREIGN KEY(storcli_adapter_variable_adapter_uuid) REFERENCES storcli_adapter(storcli_adapter_uuid)
);
ALTER TABLE storcli_adapter_variables OWNER TO #!variable!user!#;

CREATE TABLE history.storcli_adapter_variables (
	history_id				bigserial,
	storcli_adapter_variable_uuid		uuid,
	storcli_adapter_variable_adapter_uuid	uuid,
	storcli_adapter_is_temperature		boolean,
	storcli_adapter_variable_name		text,
	storcli_adapter_variable_value		text,
	modified_date				timestamp with time zone
);
ALTER TABLE history.storcli_adapter_variables OWNER TO #!variable!user!#;

CREATE FUNCTION history_storcli_adapter_variables() RETURNS trigger
AS $$
DECLARE
	history_storcli_adapter_variables RECORD;
BEGIN
	SELECT INTO history_storcli_adapter_variables * FROM storcli_adapter_variables WHERE storcli_adapter_variable_uuid=new.storcli_adapter_variable_uuid;
	INSERT INTO history.storcli_adapter_variables
		(storcli_adapter_variable_uuid, 
		 storcli_adapter_variable_adapter_uuid,
		 storcli_adapter_is_temperature,
		 storcli_adapter_variable_name,
		 storcli_adapter_variable_value,
		 modified_date)
	VALUES
		(history_storcli_adapter_variables.storcli_adapter_variable_uuid,
		 history_storcli_adapter_variables.storcli_adapter_variable_adapter_uuid,
		 history_storcli_adapter_variables.storcli_adapter_is_temperature,
		 history_storcli_adapter_variables.storcli_adapter_variable_name,
		 history_storcli_adapter_variables.storcli_adapter_variable_value,
		 history_storcli_adapter_variables.modified_date);
	RETURN NULL;
END;
$$
LANGUAGE plpgsql;
ALTER FUNCTION history_storcli_adapter_variables() OWNER TO #!variable!user!#;

CREATE TRIGGER trigger_storcli_adapter_variables
	AFTER INSERT OR UPDATE ON storcli_adapter_variables
	FOR EACH ROW EXECUTE PROCEDURE history_storcli_adapter_variables();


-- ------------------------------------------------------------------------------------------------------- --
-- Cachevault                                                                                              --
-- ------------------------------------------------------------------------------------------------------- --

-- This records the basic information about the cachevault (FBU) unit.
CREATE TABLE storcli_cachevaults (
	storcli_cachevault_uuid			uuid				primary key,
	storcli_cachevault_adapter_uuid		uuid				not null,
	storcli_cachevault_state		text,
	storcli_cachevault_design_capacity	text,
	storcli_cachevault_capacitance		text,
	storcli_cachevault_pack_energy		text,
	storcli_cachevault_replacement_needed	text,
	storcli_cachevault_next_relearn		text,
	storcli_cachevault_type			text,
	storcli_cachevault_manufacture_date	text,
	storcli_cachevault_temperature		numeric,
	modified_date				timestamp with time zone	not null,
	
	FOREIGN KEY(storcli_cachevault_adapter_uuid) REFERENCES storcli_adapter(storcli_adapter_uuid)
);
ALTER TABLE storcli_cachevaults OWNER TO #!variable!user!#;

CREATE TABLE history.storcli_cachevaults (
	history_id				bigserial,
	storcli_cachevault_uuid			uuid,
	storcli_cachevault_adapter_uuid		uuid,
	storcli_cachevault_state		text,
	storcli_cachevault_design_capacity	text,
	storcli_cachevault_capacitance		text,
	storcli_cachevault_pack_energy		text,
	storcli_cachevault_replacement_needed	text,
	storcli_cachevault_next_relearn		text,
	storcli_cachevault_type			text,
	storcli_cachevault_manufacture_date	text,
	storcli_cachevault_temperature		numeric,
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
		 storcli_cachevault_adapter_uuid, 
		 storcli_cachevault_state, 
		 storcli_cachevault_design_capacity, 
		 storcli_cachevault_capacitance, 
		 storcli_cachevault_pack_energy, 
		 storcli_cachevault_replacement_needed, 
		 storcli_cachevault_next_relearn, 
		 storcli_cachevault_type, 
		 storcli_cachevault_manufacture_date, 
		 storcli_cachevault_temperature, 
		 modified_date)
	VALUES
		(history_storcli_cachevault.storcli_cachevault_uuid,
		 history_storcli_cachevault.storcli_cachevault_adapter_uuid, 
		 history_storcli_cachevault.storcli_cachevault_state, 
		 history_storcli_cachevault.storcli_cachevault_design_capacity, 
		 history_storcli_cachevault.storcli_cachevault_capacitance, 
		 history_storcli_cachevault.storcli_cachevault_pack_energy, 
		 history_storcli_cachevault.storcli_cachevault_replacement_needed, 
		 history_storcli_cachevault.storcli_cachevault_next_relearn, 
		 history_storcli_cachevault.storcli_cachevault_type, 
		 history_storcli_cachevault.storcli_cachevault_manufacture_date, 
		 history_storcli_cachevault.storcli_cachevault_temperature, 
		 history_storcli_cachevault.modified_date);
	RETURN NULL;
END;
$$
LANGUAGE plpgsql;
ALTER FUNCTION history_storcli_cachevaults() OWNER TO #!variable!user!#;

CREATE TRIGGER trigger_storcli_cachevaults
	AFTER INSERT OR UPDATE ON storcli_cachevaults
	FOR EACH ROW EXECUTE PROCEDURE history_storcli_cachevaults();


-- This stores various variables found for a given controller but not explicitely checked for.
CREATE TABLE storcli_cachevault_variables (
	storcli_cachevault_variable_uuid		uuid				primary key,
	storcli_cachevault_variable_cachevault_uuid	uuid				not null,
	storcli_cachevault_is_temperature		boolean				not null	default FALSE,
	storcli_cachevault_variable_name		text				not null,
	storcli_cachevault_variable_value		text,
	modified_date					timestamp with time zone	not null,
	
	FOREIGN KEY(storcli_cachevault_variable_cachevault_uuid) REFERENCES storcli_cachevault(storcli_cachevault_uuid)
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
	storcli_bbu_adapter_uuid		uuid				not null,
	storcli_bbu_type			text,						-- "Type"
	storcli_bbu_model			text,						-- "Manufacture Name"
	storcli_bbu_state			text,						-- "Battery State"
	storcli_bbu_manufacture_date		text,						-- "Date of Manufacture"
	storcli_bbu_absolute_state_of_charge	text,						-- "Absolute state of charge"
	storcli_bbu_cycle_count			numeric,					-- "Cycle Count"
	storcli_bbu_design_capacity		text,						-- "Design Capacity"
	storcli_bbu_current_maximum_capacity	text,						-- "Full Charge Capacity"
	storcli_bbu_charged			text,						-- "Fully Charged"
	storcli_bbu_learning			text,						-- "Learn Cycle Active"
	storcli_bbu_next_relearn		text,						-- "Next Learn time"
	storcli_bbu_over_charged		text,						-- "Over Charged"
	storcli_bbu_over_temperature		text,						-- "Over Temperature"
	storcli_bbu_replacement_needed		text,						-- "Pack is about to fail & should be replaced"
	storcli_bbu_temperature			numeric,					-- "Temperature"
	modified_date				timestamp with time zone	not null,
	
	FOREIGN KEY(storcli_bbu_adapter_uuid) REFERENCES storcli_adapter(storcli_adapter_uuid)
);
ALTER TABLE storcli_bbus OWNER TO #!variable!user!#;

CREATE TABLE history.storcli_bbus (
	history_id				bigserial,
	storcli_bbu_uuid			uuid,
	storcli_bbu_adapter_uuid		uuid,
	storcli_bbu_type			text,
	storcli_bbu_model			text,
	storcli_bbu_state			text,
	storcli_bbu_manufacture_date		text,
	storcli_bbu_absolute_state_of_charge	text,
	storcli_bbu_cycle_count			numeric,
	storcli_bbu_design_capacity		text,
	storcli_bbu_current_maximum_capacity	text,
	storcli_bbu_charged			text,
	storcli_bbu_learning			text,
	storcli_bbu_next_relearn		text,
	storcli_bbu_over_charged		text,
	storcli_bbu_over_temperature		text,
	storcli_bbu_replacement_needed		text,
	storcli_bbu_temperature			numeric,
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
		 storcli_bbu_adapter_uuid, 
		 storcli_bbu_type, 
		 storcli_bbu_model, 
		 storcli_bbu_state, 
		 storcli_bbu_manufacture_date, 
		 storcli_bbu_absolute_state_of_charge, 
		 storcli_bbu_cycle_count, 
		 storcli_bbu_design_capacity, 
		 storcli_bbu_current_maximum_capacity, 
		 storcli_bbu_charged, 
		 storcli_bbu_learning, 
		 storcli_bbu_next_relearn, 
		 storcli_bbu_over_charged, 
		 storcli_bbu_over_temperature, 
		 storcli_bbu_replacement_needed, 
		 storcli_bbu_temperature, 
		 modified_date)
	VALUES
		(history_storcli_bbu.storcli_bbu_uuid,
		 history_storcli_bbu.storcli_bbu_adapter_uuid, 
		 history_storcli_bbu.storcli_bbu_type, 
		 history_storcli_bbu.storcli_bbu_model, 
		 history_storcli_bbu.storcli_bbu_state, 
		 history_storcli_bbu.storcli_bbu_manufacture_date, 
		 history_storcli_bbu.storcli_bbu_absolute_state_of_charge, 
		 history_storcli_bbu.storcli_bbu_cycle_count, 
		 history_storcli_bbu.storcli_bbu_design_capacity, 
		 history_storcli_bbu.storcli_bbu_current_maximum_capacity, 
		 history_storcli_bbu.storcli_bbu_charged, 
		 history_storcli_bbu.storcli_bbu_learning, 
		 history_storcli_bbu.storcli_bbu_next_relearn, 
		 history_storcli_bbu.storcli_bbu_over_charged, 
		 history_storcli_bbu.storcli_bbu_over_temperature, 
		 history_storcli_bbu.storcli_bbu_replacement_needed, 
		 history_storcli_bbu.storcli_bbu_temperature, 
		 history_storcli_bbu.modified_date);
	RETURN NULL;
END;
$$
LANGUAGE plpgsql;
ALTER FUNCTION history_storcli_bbus() OWNER TO #!variable!user!#;

CREATE TRIGGER trigger_storcli_bbus
	AFTER INSERT OR UPDATE ON storcli_bbus
	FOR EACH ROW EXECUTE PROCEDURE history_storcli_bbus();


-- This stores various variables found for a given controller but not explicitely checked for.
CREATE TABLE storcli_bbu_variables (
	storcli_bbu_variable_uuid		uuid				primary key,
	storcli_bbu_variable_bbu_uuid		uuid				not null,
	storcli_bbu_is_temperature		boolean				not null	default FALSE,
	storcli_bbu_variable_name		text				not null,
	storcli_bbu_variable_value		text,
	modified_date				timestamp with time zone	not null,
	
	FOREIGN KEY(storcli_bbu_variable_bbu_uuid) REFERENCES storcli_bbu(storcli_bbu_uuid)
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
	storcli_virtual_drive_adapter_uuid	uuid				not null,
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
	
	FOREIGN KEY(storcli_virtual_drive_adapter_uuid) REFERENCES storcli_adapter(storcli_adapter_uuid)
);
ALTER TABLE storcli_virtual_drives OWNER TO #!variable!user!#;

CREATE TABLE history.storcli_virtual_drives (
	history_id				bigserial,
	storcli_virtual_drive_uuid		uuid,
	storcli_virtual_drive_adapter_uuid	uuid,
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
		 storcli_virtual_drive_adapter_uuid, 
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
		 history_storcli_virtual_drive.storcli_virtual_drive_adapter_uuid, 
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
-- This stores various variables found for a given virtual disk but not explicitely checked for.
CREATE TABLE storcli_virtual_drive_variables (
	storcli_virtual_drive_variable_uuid			uuid				primary key,
	storcli_virtual_drive_variable_virtual_drive_uuid	uuid				not null,
	storcli_virtual_drive_is_temperature			boolean				not null	default FALSE,
	storcli_virtual_drive_variable_name			text				not null,
	storcli_virtual_drive_variable_value			text,
	modified_date						timestamp with time zone	not null,
	
	FOREIGN KEY(storcli_virtual_drive_variable_virtual_drive_uuid) REFERENCES storcli_virtual_drive(storcli_virtual_drive_uuid)
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
	storcli_drive_group_array_size		text,						-- "array_state"
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
	
	FOREIGN KEY(storcli_drive_group_virtual_drive_uuid) REFERENCES storcli_virtual_drives(storcli_virtual_drive_uuid),
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
	
	FOREIGN KEY(storcli_drive_group_variable_drive_group_uuid) REFERENCES storcli_drive_group(storcli_drive_group_uuid)
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


