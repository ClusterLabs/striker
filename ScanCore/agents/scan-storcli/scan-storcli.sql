-- This is the database schema for the 'storcli Scan Agent'.

-- Data here comes from the 'Basics' section of 'storcli64 /cX show all'
CREATE TABLE storcli_adapter (
	storcli_adapter_uuid			uuid				primary key,
	storcli_adapter_host_uuid		uuid				not null,
	storcli_adapter_model			text				not null,
	storcli_adapter_serial_number		text				not null,	-- This is the core identifier
	storcli_adapter_pci_address		text,
	modified_date				timestamp with time zone	not null,
	
	FOREIGN KEY(storcli_host_uuid) REFERENCES hosts(host_uuid)
);
ALTER TABLE storcli_adapter OWNER TO #!variable!user!#;

CREATE TABLE history.storcli_adapter (
	history_id				bigserial,
	storcli_adapter_uuid			uuid				primary key,
	storcli_adapter_host_uuid		uuid				not null,
	storcli_adapter_model			text				not null,
	storcli_adapter_serial_number		text				not null,	-- This is the core identifier
	storcli_adapter_pci_address		text,
	modified_date				timestamp with time zone	not null
);
ALTER TABLE history.storcli_adapter OWNER TO #!variable!user!#;

CREATE FUNCTION history_storcli_adapter() RETURNS trigger
AS $$
DECLARE
	history_storcli_adapter RECORD;
BEGIN
	SELECT INTO history_storcli_adapter * FROM storcli_adapter WHERE storcli_adapter_uuid=new.storcli_adapter_uuid;
	INSERT INTO history.storcli_adapter
		(storcli_adapter_uuid, 
		 storcli_adapter_host_uuid, 
		 storcli_adapter_model, 
		 storcli_adapter_serial_number, 
		 storcli_adapter_pci_address, 
		 modified_date)
	VALUES
		(history_storcli_adapter.storcli_adapter_uuid,
		 history_storcli_adapter.storcli_adapter_host_uuid,
		 history_storcli_adapter.storcli_adapter_model, 
		 history_storcli_adapter.storcli_adapter_serial_number, 
		 history_storcli_adapter.storcli_adapter_pci_address, 
		 history_storcli_adapter.modified_date);
	RETURN NULL;
END;
$$
LANGUAGE plpgsql;
ALTER FUNCTION history_storcli_adapter() OWNER TO #!variable!user!#;

CREATE TRIGGER trigger_storcli_adapter
	AFTER INSERT OR UPDATE ON storcli_adapter
	FOR EACH ROW EXECUTE PROCEDURE history_storcli_adapter();


-- This stores the data from the 'Version' section of 'storcli64 /cX show all'.
CREATE TABLE storcli_version (
	storcli_version_uuid			uuid				primary key,
	storcli_version_storcli_adapter_uuid	uuid				not null,
	storcli_version_package_build		text, 
	storcli_version_firmware_version	text,
	storcli_version_cpld_version		text, 
	storcli_version_bios_version		text, 
	storcli_version_webbios_version		text, 
	storcli_version_ctrl_r_version		text, 
	storcli_version_preboot_cli_version	text, 
	storcli_version_nvdata_version		text, 
	storcli_version_boot_block_version	text, 
	storcli_version_bootloader_version	text, 
	storcli_version_driver_name		text, 
	storcli_version_driver_version		text, 
	modified_date				timestamp with time zone	not null,
	
	FOREIGN KEY(storcli_version_uuid) REFERENCES storcli_adapter(storcli_adapter_uuid)
);
ALTER TABLE storcli_version OWNER TO #!variable!user!#;

CREATE TABLE history.storcli_version (
	history_id				bigserial,
	storcli_version_uuid			uuid				primary key,
	storcli_version_storcli_adapter_uuid	uuid				not null,
	storcli_version_package_build		text, 
	storcli_version_firmware_version	text, 
	storcli_version_cpld_version		text, 
	storcli_version_bios_version		text, 
	storcli_version_webbios_version		text, 
	storcli_version_ctrl_r_version		text, 
	storcli_version_preboot_cli_version	text, 
	storcli_version_nvdata_version		text, 
	storcli_version_boot_block_version	text, 
	storcli_version_bootloader_version	text, 
	storcli_version_driver_name		text, 
	storcli_version_driver_version		text, 
	modified_date				timestamp with time zone	not null
);
ALTER TABLE history.storcli_version OWNER TO #!variable!user!#;

CREATE FUNCTION history_storcli_version() RETURNS trigger
AS $$
DECLARE
	history_storcli_version RECORD;
BEGIN
	SELECT INTO history_storcli_version * FROM storcli_version WHERE storcli_version_uuid=new.storcli_version_uuid;
	INSERT INTO history.storcli_version
		(storcli_version_uuid, 
		 storcli_version_storcli_adapter_uuid, 
		 storcli_version_package_build, 
		 storcli_version_firmware_version, 
		 storcli_version_cpld_version, 
		 storcli_version_bios_version, 
		 storcli_version_webbios_version, 
		 storcli_version_ctrl_r_version, 
		 storcli_version_preboot_cli_version, 
		 storcli_version_nvdata_version, 
		 storcli_version_boot_block_version, 
		 storcli_version_bootloader_version, 
		 storcli_version_driver_name, 
		 storcli_version_driver_version, 
		 modified_date)
	VALUES
		(history_storcli_version.storcli_version_uuid, 
		 history_storcli_version.storcli_version_storcli_adapter_uuid, 
		 history_storcli_version.storcli_version_package_build, 
		 history_storcli_version.storcli_version_firmware_version, 
		 history_storcli_version.storcli_version_cpld_version, 
		 history_storcli_version.storcli_version_bios_version, 
		 history_storcli_version.storcli_version_webbios_version, 
		 history_storcli_version.storcli_version_ctrl_r_version, 
		 history_storcli_version.storcli_version_preboot_cli_version, 
		 history_storcli_version.storcli_version_nvdata_version, 
		 history_storcli_version.storcli_version_boot_block_version, 
		 history_storcli_version.storcli_version_bootloader_version, 
		 history_storcli_version.storcli_version_driver_name, 
		 history_storcli_version.storcli_version_driver_version, 
		 history_storcli_version.modified_date);
	RETURN NULL;
END;
$$
LANGUAGE plpgsql;
ALTER FUNCTION history_storcli_version() OWNER TO #!variable!user!#;

CREATE TRIGGER trigger_storcli_version
	AFTER INSERT OR UPDATE ON storcli_version
	FOR EACH ROW EXECUTE PROCEDURE history_storcli_version();


-- This stores the data from the 'Status' section of 'storcli64 /cX show all'.
CREATE TABLE storcli_status (
	storcli_status_uuid				uuid				primary key,
	storcli_status_storcli_adapter_uuid		uuid				not null,
	storcli_status_function_number			text,
	storcli_status_memory_correctable_errors	text,
	storcli_status_memory_uncorrectable_errors	text,
	storcli_status_ecc_bucket_count			text,
	storcli_status_any_offline_vd_cache_preserved	text,
	storcli_status_bbu_status			text,
	storcli_status_lock_key_assigned		text,
	storcli_status_failed_to_get_lock_key_on_bootup	text,
	storcli_status_controller_booted_into_safe_mode	text,
	modified_date					timestamp with time zone	not null,
	
	FOREIGN KEY(storcli_status_uuid) REFERENCES storcli_adapter(storcli_adapter_uuid)
);
ALTER TABLE storcli_status OWNER TO #!variable!user!#;

CREATE TABLE history.storcli_status (
	history_id					bigserial,
	storcli_status_uuid				uuid				primary key,
	storcli_status_storcli_adapter_uuid		uuid				not null,
	storcli_status_function_number			text,
	storcli_status_memory_correctable_errors	text,
	storcli_status_memory_uncorrectable_errors	text,
	storcli_status_ecc_bucket_count			text,
	storcli_status_any_offline_vd_cache_preserved	text,
	storcli_status_bbu_status			text,
	storcli_status_lock_key_assigned		text,
	storcli_status_failed_to_get_lock_key_on_bootup	text,
	storcli_status_controller_booted_into_safe_mode	text,
	modified_date					timestamp with time zone	not null
);
ALTER TABLE history.storcli_status OWNER TO #!variable!user!#;

CREATE FUNCTION history_storcli_status() RETURNS trigger
AS $$
DECLARE
	history_storcli_status RECORD;
BEGIN
	SELECT INTO history_storcli_status * FROM storcli_status WHERE storcli_status_uuid=new.storcli_status_uuid;
	INSERT INTO history.storcli_status
		(storcli_status_uuid, 
		 storcli_status_storcli_adapter_uuid, 
		 storcli_status_function_number, 
		 storcli_status_memory_correctable_errors, 
		 storcli_status_memory_uncorrectable_errors, 
		 storcli_status_ecc_bucket_count, 
		 storcli_status_any_offline_vd_cache_preserved, 
		 storcli_status_bbu_status, 
		 storcli_status_lock_key_assigned, 
		 storcli_status_failed_to_get_lock_key_on_bootup, 
		 storcli_status_controller_booted_into_safe_mode, 
		 modified_date)
	VALUES
		(history_storcli_status.storcli_status_uuid, 
		 history_storcli_status.storcli_status_storcli_adapter_uuid, 
		 history_storcli_status.storcli_status_function_number, 
		 history_storcli_status.storcli_status_memory_correctable_errors, 
		 history_storcli_status.storcli_status_memory_uncorrectable_errors, 
		 history_storcli_status.storcli_status_ecc_bucket_count, 
		 history_storcli_status.storcli_status_any_offline_vd_cache_preserved, 
		 history_storcli_status.storcli_status_bbu_status, 
		 history_storcli_status.storcli_status_lock_key_assigned, 
		 history_storcli_status.storcli_status_failed_to_get_lock_key_on_bootup, 
		 history_storcli_status.storcli_status_controller_booted_into_safe_mode, 
		 history_storcli_status.modified_date);
	RETURN NULL;
END;
$$
LANGUAGE plpgsql;
ALTER FUNCTION history_storcli_status() OWNER TO #!variable!user!#;

CREATE TRIGGER trigger_storcli_status
	AFTER INSERT OR UPDATE ON storcli_status
	FOR EACH ROW EXECUTE PROCEDURE history_storcli_status();

-- This stores the data from the 'Status' section of 'storcli64 /cX show all'.
CREATE TABLE storcli_supported_adapter_operations (
	storcli_status_uuid				uuid				primary key,
	storcli_status_storcli_adapter_uuid		uuid				not null,

	modified_date					timestamp with time zone	not null,
	
	FOREIGN KEY(storcli_status_uuid) REFERENCES storcli_adapter(storcli_adapter_uuid)
);
ALTER TABLE storcli_supported_adapter_operations OWNER TO #!variable!user!#;

CREATE TABLE history.storcli_supported_adapter_operations (
	history_id					bigserial,
	storcli_status_uuid				uuid				primary key,
	storcli_status_storcli_adapter_uuid		uuid				not null,

	modified_date					timestamp with time zone	not null
);
ALTER TABLE history.storcli_status OWNER TO #!variable!user!#;

CREATE FUNCTION history_storcli_status() RETURNS trigger
AS $$
DECLARE
	history_storcli_status RECORD;
BEGIN
	SELECT INTO history_storcli_status * FROM storcli_status WHERE storcli_status_uuid=new.storcli_status_uuid;
	INSERT INTO history.storcli_status
		(storcli_status_uuid, 
		 storcli_status_storcli_adapter_uuid, 
		 storcli_status_function_number, 
		 storcli_status_memory_correctable_errors, 
		 storcli_status_memory_uncorrectable_errors, 
		 storcli_status_ecc_bucket_count, 
		 storcli_status_any_offline_vd_cache_preserved, 
		 storcli_status_bbu_status, 
		 storcli_status_lock_key_assigned, 
		 storcli_status_failed_to_get_lock_key_on_bootup, 
		 storcli_status_controller_booted_into_safe_mode, 
		 modified_date)
	VALUES
		(history_storcli_status.storcli_status_uuid, 
		 history_storcli_status.storcli_status_storcli_adapter_uuid, 
		 history_storcli_status.storcli_status_function_number, 
		 history_storcli_status.storcli_status_memory_correctable_errors, 
		 history_storcli_status.storcli_status_memory_uncorrectable_errors, 
		 history_storcli_status.storcli_status_ecc_bucket_count, 
		 history_storcli_status.storcli_status_any_offline_vd_cache_preserved, 
		 history_storcli_status.storcli_status_bbu_status, 
		 history_storcli_status.storcli_status_lock_key_assigned, 
		 history_storcli_status.storcli_status_failed_to_get_lock_key_on_bootup, 
		 history_storcli_status.storcli_status_controller_booted_into_safe_mode, 
		 history_storcli_status.modified_date);
	RETURN NULL;
END;
$$
LANGUAGE plpgsql;
ALTER FUNCTION history_storcli_status() OWNER TO #!variable!user!#;

CREATE TRIGGER trigger_storcli_status
	AFTER INSERT OR UPDATE ON storcli_status
	FOR EACH ROW EXECUTE PROCEDURE history_storcli_status();







-- ------------------------------------------------------------------------------------------------------- --
-- This stores the plethora of values we read but don't explicitely parse (yet).                           --
-- ------------------------------------------------------------------------------------------------------- --
CREATE TABLE storcli_miscellaneous (
	storcli_misc_uuid			uuid				primary key,
	storcli_misc_storcli_adapter_uuid	uuid				not null,
	storcli_misc_section			text				not null,
	storcli_misc_varible_name		text				not null,
	storcli_misc_value			text,
	modified_date				timestamp with time zone	not null,
	
	FOREIGN KEY(storcli_misc_uuid) REFERENCES storcli_adapter(storcli_adapter_uuid)
);
ALTER TABLE storcli_miscellaneous OWNER TO #!variable!user!#;

CREATE TABLE history.storcli_miscellaneous (
	history_id				bigserial,
	storcli_misc_uuid			uuid				primary key,
	storcli_misc_storcli_adapter_uuid	uuid				not null,
	storcli_misc_section			text				not null,
	storcli_misc_varible_name		text				not null,
	storcli_misc_value			text,
	modified_date				timestamp with time zone	not null
);
ALTER TABLE history.storcli_miscellaneous OWNER TO #!variable!user!#;

CREATE FUNCTION history_storcli_miscellaneous() RETURNS trigger
AS $$
DECLARE
	history_storcli_adapter RECORD;
BEGIN
	SELECT INTO history_storcli_misc * FROM storcli_miscellaneous WHERE storcli_adapter_uuid=new.storcli_adapter_uuid;
	INSERT INTO history.storcli_miscellaneous
		(storcli_misc_uuid, 
		 storcli_misc_storcli_adapter_uuid, 
		 storcli_misc_section, 
		 storcli_misc_varible_name, 
		 storcli_misc_value, 
		 modified_date)
	VALUES
		(history_storcli_misc.storcli_misc_uuid, 
		 history_storcli_misc.storcli_misc_storcli_adapter_uuid, 
		 history_storcli_misc.storcli_misc_section, 
		 history_storcli_misc.storcli_misc_varible_name, 
		 history_storcli_misc.storcli_misc_value, 
		 history_storcli_misc.modified_date);
	RETURN NULL;
END;
$$
LANGUAGE plpgsql;
ALTER FUNCTION history_storcli_adapter() OWNER TO #!variable!user!#;

CREATE TRIGGER trigger_storcli_miscellaneous
	AFTER INSERT OR UPDATE ON storcli_miscellaneous
	FOR EACH ROW EXECUTE PROCEDURE history_storcli_miscellaneous();

