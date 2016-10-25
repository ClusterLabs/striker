-- This is the database schema for the 'storcli Scan Agent'.
--       
--       Things that change rarely should go in the main tables (even if we won't explicitely watch for them
--       to change with specific alerts).

-- ------------------------------------------------------------------------------------------------------- --
-- Adapter                                                                                                 --
-- ------------------------------------------------------------------------------------------------------- --

-- Here is the basic controller information. All connected devices will reference back to this table's 
-- 'storcli_controller_serial_number' column.

-- Key variables;
-- - "ROC temperature"
CREATE TABLE storcli_controllers (
	storcli_controller_uuid			uuid				primary key,
	storcli_controller_host_uuid		uuid				not null,
	storcli_controller_serial_number	text				not null,	-- This is the core identifier
	storcli_controller_model		text				not null,	-- "model"
	storcli_controller_alarm_state		text				not null,	-- "alarm_state"
	storcli_controller_cache_size		numeric				not null,	-- "on_board_memory_size"
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
		(history_storcli_controllers.storcli_controller_uuid,
		 history_storcli_controllers.storcli_controller_host_uuid,
		 history_storcli_controllers.storcli_controller_serial_number, 
		 history_storcli_controllers.storcli_controller_model, 
		 history_storcli_controllers.storcli_controller_alarm_state, 
		 history_storcli_controllers.storcli_controller_cache_size, 
		 history_storcli_controllers.modified_date);
	RETURN NULL;
END;
$$
LANGUAGE plpgsql;
ALTER FUNCTION history_storcli_controllers() OWNER TO #!variable!user!#;

CREATE TRIGGER trigger_storcli_controllers
	AFTER INSERT OR UPDATE ON storcli_controllers
	FOR EACH ROW EXECUTE PROCEDURE history_storcli_controllers();


-- ------------------------------------------------------------------------------------------------------- --
-- Cachevault                                                                                              --
-- ------------------------------------------------------------------------------------------------------- --

-- Key variables;
-- - "Temperature"
-- - "Capacitance"
-- - "Pack Energy"
-- - "Next Learn time"
-- This records the basic information about the cachevault (FBU) unit.
CREATE TABLE storcli_cachevaults (
	storcli_cachevault_uuid			uuid				primary key,
	storcli_cachevault_host_uuid		uuid				not null,
	storcli_cachevault_controller_uuid	uuid				not null,
	storcli_cachevault_serial_number	text				not null,	-- "Serial Number"
	storcli_cachevault_state		text,						-- "State"
	storcli_cachevault_design_capacity	text,						-- "Design Capacity"
	storcli_cachevault_replacement_needed	text,						-- "Replacement required"
	storcli_cachevault_type			text,						-- "Type"
	storcli_cachevault_model		text,						-- "Device Name"
	storcli_cachevault_manufacture_date	text,						-- "Date of Manufacture"
	modified_date				timestamp with time zone	not null,
	
	FOREIGN KEY(storcli_cachevault_host_uuid) REFERENCES hosts(host_uuid),
	FOREIGN KEY(storcli_cachevault_controller_uuid) REFERENCES storcli_controllers(storcli_controller_uuid)
);
ALTER TABLE storcli_cachevaults OWNER TO #!variable!user!#;

CREATE TABLE history.storcli_cachevaults (
	history_id				bigserial,
	storcli_cachevault_uuid			uuid,
	storcli_cachevault_host_uuid		uuid,
	storcli_cachevault_controller_uuid	uuid,
	storcli_cachevault_serial_number	text,
	storcli_cachevault_state		text,
	storcli_cachevault_design_capacity	text,
	storcli_cachevault_replacement_needed	text,
	storcli_cachevault_type			text,
	storcli_cachevault_model		text,
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
		 storcli_cachevault_host_uuid,
		 storcli_cachevault_controller_uuid, 
		 storcli_cachevault_serial_number, 
		 storcli_cachevault_state, 
		 storcli_cachevault_design_capacity, 
		 storcli_cachevault_replacement_needed, 
		 storcli_cachevault_type, 
		 storcli_cachevault_model, 
		 storcli_cachevault_manufacture_date, 
		 modified_date)
	VALUES
		(history_storcli_cachevaults.storcli_cachevault_uuid,
		 history_storcli_cachevaults.storcli_cachevault_host_uuid,
		 history_storcli_cachevaults.storcli_cachevault_controller_uuid, 
		 history_storcli_cachevaults.storcli_cachevault_serial_number, 
		 history_storcli_cachevaults.storcli_cachevault_state, 
		 history_storcli_cachevaults.storcli_cachevault_design_capacity, 
		 history_storcli_cachevaults.storcli_cachevault_replacement_needed, 
		 history_storcli_cachevaults.storcli_cachevault_type, 
		 history_storcli_cachevaults.storcli_cachevault_model, 
		 history_storcli_cachevaults.storcli_cachevault_manufacture_date, 
		 history_storcli_cachevaults.modified_date);
	RETURN NULL;
END;
$$
LANGUAGE plpgsql;
ALTER FUNCTION history_storcli_cachevaults() OWNER TO #!variable!user!#;

CREATE TRIGGER trigger_storcli_cachevaults
	AFTER INSERT OR UPDATE ON storcli_cachevaults
	FOR EACH ROW EXECUTE PROCEDURE history_storcli_cachevaults();


-- ------------------------------------------------------------------------------------------------------- --
-- Battery Backup Units                                                                                    --
-- ------------------------------------------------------------------------------------------------------- --

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
-- This records the basic information about the cachevault (FBU) unit.
CREATE TABLE storcli_bbus (
	storcli_bbu_uuid			uuid				primary key,
	storcli_bbu_host_uuid			uuid				not null,
	storcli_bbu_controller_uuid		uuid				not null,
	storcli_bbu_serial_number		text				not null,	-- "Serial Number"
	storcli_bbu_type			text,						-- "Type"
	storcli_bbu_model			text,						-- "Manufacture Name"
	storcli_bbu_state			text,						-- "Battery State"
	storcli_bbu_manufacture_date		text,						-- "Date of Manufacture"
	storcli_bbu_design_capacity		text,						-- "Design Capacity"
	storcli_bbu_replacement_needed		text,						-- "Pack is about to fail & should be replaced"
	modified_date				timestamp with time zone	not null,
	
	FOREIGN KEY(storcli_bbu_host_uuid) REFERENCES hosts(host_uuid),
	FOREIGN KEY(storcli_bbu_controller_uuid) REFERENCES storcli_controllers(storcli_controller_uuid)
);
ALTER TABLE storcli_bbus OWNER TO #!variable!user!#;

CREATE TABLE history.storcli_bbus (
	history_id				bigserial,
	storcli_bbu_uuid			uuid,
	storcli_bbu_host_uuid			uuid,
	storcli_bbu_controller_uuid		uuid,
	storcli_bbu_serial_number		text,
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
		 storcli_bbu_host_uuid, 
		 storcli_bbu_controller_uuid, 
		 storcli_bbu_serial_number, 
		 storcli_bbu_type, 
		 storcli_bbu_model, 
		 storcli_bbu_state, 
		 storcli_bbu_manufacture_date, 
		 storcli_bbu_design_capacity, 
		 storcli_bbu_replacement_needed, 
		 modified_date)
	VALUES
		(history_storcli_bbus.storcli_bbu_uuid,
		 history_storcli_bbus.storcli_bbu_host_uuid, 
		 history_storcli_bbus.storcli_bbu_controller_uuid, 
		 history_storcli_bbus.storcli_bbu_serial_number, 
		 history_storcli_bbus.storcli_bbu_type, 
		 history_storcli_bbus.storcli_bbu_model, 
		 history_storcli_bbus.storcli_bbu_state, 
		 history_storcli_bbus.storcli_bbu_manufacture_date, 
		 history_storcli_bbus.storcli_bbu_design_capacity, 
		 history_storcli_bbus.storcli_bbu_replacement_needed, 
		 history_storcli_bbus.modified_date);
	RETURN NULL;
END;
$$
LANGUAGE plpgsql;
ALTER FUNCTION history_storcli_bbus() OWNER TO #!variable!user!#;

CREATE TRIGGER trigger_storcli_bbus
	AFTER INSERT OR UPDATE ON storcli_bbus
	FOR EACH ROW EXECUTE PROCEDURE history_storcli_bbus();


-- ------------------------------------------------------------------------------------------------------- --
-- Virtual Drives                                                                                          --
-- ------------------------------------------------------------------------------------------------------- --

-- This records the basic virtual drives. These contain one or more drive groups to form an array
CREATE TABLE storcli_virtual_drives (
	storcli_virtual_drive_uuid		uuid				primary key,
	storcli_virtual_drive_host_uuid		uuid				not null,
	storcli_virtual_drive_controller_uuid	uuid				not null,
	storcli_virtual_drive_id_string		text				not null,	-- This is '<host_controller_sn>-vd<x>' where 'x' is the virtual drive number.
	storcli_virtual_drive_creation_date	text,						-- "Creation Date" and "Creation Time"
	storcli_virtual_drive_data_protection	text,						-- "Data Protection"
	storcli_virtual_drive_disk_cache_policy	text,						-- "Disk Cache Policy"
	storcli_virtual_drive_emulation_type	text,						-- "Emulation type"
	storcli_virtual_drive_encryption	text,						-- "Encryption"
	storcli_virtual_drive_blocks		numeric,					-- "Number of Blocks"
	storcli_virtual_drive_strip_size	text,						-- "Strip Size" (has the suffix 'Bytes', so not numeric)
	storcli_virtual_drive_drives_per_span	numeric,					-- "Number of Drives Per Span"
	storcli_virtual_drive_span_depth	numeric,					-- "Span Depth"
	storcli_virtual_drive_scsi_naa_id	text,						-- "SCSI NAA Id" - https://en.wikipedia.org/wiki/ISCSI#Addressing
	modified_date				timestamp with time zone	not null,
	
	FOREIGN KEY(storcli_virtual_drive_host_uuid) REFERENCES hosts(host_uuid),
	FOREIGN KEY(storcli_virtual_drive_controller_uuid) REFERENCES storcli_controllers(storcli_controller_uuid)
);
ALTER TABLE storcli_virtual_drives OWNER TO #!variable!user!#;

CREATE TABLE history.storcli_virtual_drives (
	history_id				bigserial,
	storcli_virtual_drive_uuid		uuid,
	storcli_virtual_drive_host_uuid		uuid,
	storcli_virtual_drive_controller_uuid	uuid,
	storcli_virtual_drive_id_string		text,
	storcli_virtual_drive_creation_date	text,
	storcli_virtual_drive_data_protection	text,
	storcli_virtual_drive_disk_cache_policy	text,
	storcli_virtual_drive_emulation_type	text,
	storcli_virtual_drive_encryption	text,
	storcli_virtual_drive_blocks		numeric,
	storcli_virtual_drive_strip_size	text,
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
		 storcli_virtual_drive_host_uuid, 
		 storcli_virtual_drive_controller_uuid, 
		 storcli_virtual_drive_id_string, 
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
		(history_storcli_virtual_drives.storcli_virtual_drive_uuid,
		 history_storcli_virtual_drives.storcli_virtual_drive_host_uuid, 
		 history_storcli_virtual_drives.storcli_virtual_drive_controller_uuid, 
		 history_storcli_virtual_drives.storcli_virtual_drive_id_string, 
		 history_storcli_virtual_drives.storcli_virtual_drive_creation_date, 
		 history_storcli_virtual_drives.storcli_virtual_drive_data_protection, 
		 history_storcli_virtual_drives.storcli_virtual_drive_disk_cache_policy, 
		 history_storcli_virtual_drives.storcli_virtual_drive_emulation_type, 
		 history_storcli_virtual_drives.storcli_virtual_drive_encryption, 
		 history_storcli_virtual_drives.storcli_virtual_drive_blocks, 
		 history_storcli_virtual_drives.storcli_virtual_drive_strip_size, 
		 history_storcli_virtual_drives.storcli_virtual_drive_drives_per_span, 
		 history_storcli_virtual_drives.storcli_virtual_drive_span_depth, 
		 history_storcli_virtual_drives.storcli_virtual_drive_scsi_naa_id, 
		 history_storcli_virtual_drives.modified_date);
	RETURN NULL;
END;
$$
LANGUAGE plpgsql;
ALTER FUNCTION history_storcli_virtual_drives() OWNER TO #!variable!user!#;

CREATE TRIGGER trigger_storcli_virtual_drives
	AFTER INSERT OR UPDATE ON storcli_virtual_drives
	FOR EACH ROW EXECUTE PROCEDURE history_storcli_virtual_drives();


-- ------------------------------------------------------------------------------------------------------- --
-- Drive Groups                                                                                            --
-- ------------------------------------------------------------------------------------------------------- --

-- This records the basic drive group information.
CREATE TABLE storcli_drive_groups (
	storcli_drive_group_uuid		uuid				primary key,
	storcli_drive_group_host_uuid		uuid				not null,
	storcli_drive_group_virtual_drive_uuid	uuid				not null,
	storcli_drive_group_id_string		text,						-- This is '<host_controller_sn>-vd<x>-dg<y>' where 'x' is the virtual drive number and 'y' is the drive group number.
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
	
	FOREIGN KEY(storcli_drive_group_host_uuid) REFERENCES hosts(host_uuid),
	FOREIGN KEY(storcli_drive_group_virtual_drive_uuid) REFERENCES storcli_virtual_drives(storcli_virtual_drive_uuid)
);
ALTER TABLE storcli_drive_groups OWNER TO #!variable!user!#;

CREATE TABLE history.storcli_drive_groups (
	history_id				bigserial,
	storcli_drive_group_uuid		uuid,
	storcli_drive_group_host_uuid		uuid,
	storcli_drive_group_virtual_drive_uuid	uuid,
	storcli_drive_group_id_string		text,
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
		 storcli_drive_group_host_uuid, 
		 storcli_drive_group_virtual_drive_uuid, 
		 storcli_drive_group_id_string, 
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
		(history_storcli_drive_groups.storcli_drive_group_uuid,
		 history_storcli_drive_groups.storcli_drive_group_host_uuid, 
		 history_storcli_drive_groups.storcli_drive_group_virtual_drive_uuid, 
		 history_storcli_drive_groups.storcli_drive_group_id_string, 
		 history_storcli_drive_groups.storcli_drive_group_access, 
		 history_storcli_drive_groups.storcli_drive_group_array_size, 
		 history_storcli_drive_groups.storcli_drive_group_array_state, 
		 history_storcli_drive_groups.storcli_drive_group_cache, 
		 history_storcli_drive_groups.storcli_drive_group_cachecade, 
		 history_storcli_drive_groups.storcli_drive_group_consistent, 
		 history_storcli_drive_groups.storcli_drive_group_disk_cache, 
		 history_storcli_drive_groups.storcli_drive_group_raid_type, 
		 history_storcli_drive_groups.storcli_drive_group_read_cache, 
		 history_storcli_drive_groups.storcli_drive_group_scheduled_cc, 
		 history_storcli_drive_groups.storcli_drive_group_write_cache, 
		 history_storcli_drive_groups.modified_date);
	RETURN NULL;
END;
$$
LANGUAGE plpgsql;
ALTER FUNCTION history_storcli_drive_groups() OWNER TO #!variable!user!#;

CREATE TRIGGER trigger_storcli_drive_groups
	AFTER INSERT OR UPDATE ON storcli_drive_groups
	FOR EACH ROW EXECUTE PROCEDURE history_storcli_drive_groups();


-- ------------------------------------------------------------------------------------------------------- --
-- Physical Drives                                                                                         --
-- ------------------------------------------------------------------------------------------------------- --

-- NOTE: More information to T10-PI (protection information) is available here:
--       https://www.seagate.com/files/staticfiles/docs/pdf/whitepaper/safeguarding-data-from-corruption-technology-paper-tp621us.pdf

-- This records the basic drive group information.
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
CREATE TABLE storcli_physical_drives (
	storcli_physical_drive_uuid			uuid				primary key,
	storcli_physical_drive_host_uuid		uuid				not null,
	storcli_physical_drive_controller_uuid		uuid				not null,
	storcli_physical_drive_virtual_drive		text,
	storcli_physical_drive_drive_group		text,
	storcli_physical_drive_enclosure_id		text,
	storcli_physical_drive_slot_number		text,
	storcli_physical_drive_serial_number		text,					-- "Serial Number"
	storcli_physical_drive_size			text,					-- In 'text' because of 'Bytes' suffix - "drive_size" but also; "Raw size", "Non Coerced size" and "Coerced size"
	storcli_physical_drive_sector_size		text,					-- In 'text' because of 'Bytes' suffix - "sector_size", "Sector Size"
	storcli_physical_drive_vendor			text,					-- "Manufacturer Identification"
	storcli_physical_drive_model			text,					-- "drive_model", "Model Number"
	storcli_physical_drive_self_encrypting_drive	text,					-- "self_encrypting_drive", "SED Capable"
	modified_date					timestamp with time zone	not null,
	
	FOREIGN KEY(storcli_physical_drive_host_uuid) REFERENCES hosts(host_uuid),
	FOREIGN KEY(storcli_physical_drive_controller_uuid) REFERENCES storcli_controllers(storcli_controller_uuid)
);
ALTER TABLE storcli_physical_drives OWNER TO #!variable!user!#;

CREATE TABLE history.storcli_physical_drives (
	history_id					bigserial,
	storcli_physical_drive_uuid			uuid,
	storcli_physical_drive_host_uuid		uuid,
	storcli_physical_drive_controller_uuid		uuid,
	storcli_physical_drive_serial_number		text,
	storcli_physical_drive_virtual_drive		text,
	storcli_physical_drive_drive_group		text,
	storcli_physical_drive_enclosure_id		text,
	storcli_physical_drive_slot_number		text,
	storcli_physical_drive_size			text,
	storcli_physical_drive_sector_size		text,
	storcli_physical_drive_vendor			text,
	storcli_physical_drive_model			text,
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
		 storcli_physical_drive_host_uuid,
		 storcli_physical_drive_controller_uuid, 
		 storcli_physical_drive_virtual_drive, 
		 storcli_physical_drive_drive_group, 
		 storcli_physical_drive_enclosure_id, 
		 storcli_physical_drive_slot_number, 
		 storcli_physical_drive_serial_number, 
		 storcli_physical_drive_size, 
		 storcli_physical_drive_sector_size, 
		 storcli_physical_drive_vendor, 
		 storcli_physical_drive_model, 
		 storcli_physical_drive_self_encrypting_drive, 
		 modified_date)
	VALUES
		(history_storcli_physical_drives.storcli_physical_drive_uuid,
		 history_storcli_physical_drives.storcli_physical_drive_host_uuid,
		 history_storcli_physical_drives.storcli_physical_drive_controller_uuid, 
		 history_storcli_physical_drives.storcli_physical_drive_virtual_drive, 
		 history_storcli_physical_drives.storcli_physical_drive_drive_group, 
		 history_storcli_physical_drives.storcli_physical_drive_enclosure_id, 
		 history_storcli_physical_drives.storcli_physical_drive_slot_number, 
		 history_storcli_physical_drives.storcli_physical_drive_size, 
		 history_storcli_physical_drives.storcli_physical_drive_sector_size, 
		 history_storcli_physical_drives.storcli_physical_drive_vendor, 
		 history_storcli_physical_drives.storcli_physical_drive_model, 
		 history_storcli_physical_drives.storcli_physical_drive_serial_number, 
		 history_storcli_physical_drives.storcli_physical_drive_self_encrypting_drive, 
		 history_storcli_physical_drives.modified_date);
	RETURN NULL;
END;
$$
LANGUAGE plpgsql;
ALTER FUNCTION history_storcli_physical_drives() OWNER TO #!variable!user!#;

CREATE TRIGGER trigger_storcli_physical_drives
	AFTER INSERT OR UPDATE ON storcli_physical_drives
	FOR EACH ROW EXECUTE PROCEDURE history_storcli_physical_drives();


-- ------------------------------------------------------------------------------------------------------- --
-- Each data type has several variables that we're not storing in the component-specific tables. To do so  --
-- would be to create massive tables that would miss variables not shown for all controllers or when new   --
-- variables are added or renamed. So this table is used to store all those myriade of variables. Each     --
-- entry will reference the table it is attached to and the UUID of the record in that table. The column   --

-- 'storcli_variable_is_temperature' will be used to know what data is a temperature and will be then used --
-- to inform on the host's thermal health.                                                                 --
-- ------------------------------------------------------------------------------------------------------- --

-- This stores various variables found for a given controller but not explicitely checked for (or that 
-- change frequently).
CREATE TABLE storcli_variables (
	storcli_variable_uuid		uuid				primary key,
	storcli_variable_host_uuid	uuid				not null,
	storcli_variable_source_table	text				not null,
	storcli_variable_source_uuid	uuid				not null,
	storcli_variable_is_temperature	boolean				not null	default FALSE,
	storcli_variable_name		text				not null,
	storcli_variable_value		text,
	modified_date					timestamp with time zone	not null,
	
	FOREIGN KEY(storcli_variable_host_uuid) REFERENCES hosts(host_uuid)
);
ALTER TABLE storcli_variables OWNER TO #!variable!user!#;

CREATE TABLE history.storcli_variables (
	history_id			bigserial,
	storcli_variable_uuid		uuid,
	storcli_variable_host_uuid	uuid,
	storcli_variable_source_table	text,
	storcli_variable_source_uuid	uuid,
	storcli_variable_is_temperature	boolean,
	storcli_variable_name		text,
	storcli_variable_value		text,
	modified_date					timestamp with time zone
);
ALTER TABLE history.storcli_variables OWNER TO #!variable!user!#;

CREATE FUNCTION history_storcli_variables() RETURNS trigger
AS $$
DECLARE
	history_storcli_variables RECORD;
BEGIN
	SELECT INTO history_storcli_variables * FROM storcli_variables WHERE storcli_variable_uuid=new.storcli_variable_uuid;
	INSERT INTO history.storcli_variables
		(storcli_variable_uuid, 
		 storcli_variable_host_uuid, 
		 storcli_variable_source_table, 
		 storcli_variable_source_uuid, 
		 storcli_variable_is_temperature,
		 storcli_variable_name,
		 storcli_variable_value,
		 modified_date)
	VALUES
		(history_storcli_variables.storcli_variable_uuid,
		 history_storcli_variables.storcli_variable_host_uuid, 
		 history_storcli_variables.storcli_variable_source_table, 
		 history_storcli_variables.storcli_variable_source_uuid, 
		 history_storcli_variables.storcli_variable_is_temperature,
		 history_storcli_variables.storcli_variable_name,
		 history_storcli_variables.storcli_variable_value,
		 history_storcli_variables.modified_date);
	RETURN NULL;
END;
$$
LANGUAGE plpgsql;
ALTER FUNCTION history_storcli_variables() OWNER TO #!variable!user!#;

CREATE TRIGGER trigger_storcli_variables
	AFTER INSERT OR UPDATE ON storcli_variables
	FOR EACH ROW EXECUTE PROCEDURE history_storcli_variables();
