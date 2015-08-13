-- This is the database schema for the 'storcli Scan Agent'.

CREATE TABLE storcli_adapter (
	storcli_adapter_uuid			uuid				primary key,
	storcli_adapter_host_uuid		uuid				not null,
	storcli_adapter_adapter_number		numeric				not null,
	storcli_adapter_product_name		text				not null,
	storcli_adapter_serial_number		text				not null,	-- This is the core identifier
	storcli_adapter_sas_address		text,
	storcli_adapter_pci_address		text,
	storcli_adapter_manufacture_date	date,						-- yyyy/mm/dd
	storcli_adapter_rework_date		date,						-- yyyy/mm/dd
	storcli_adapter_revision_number		text,
	modified_date					timestamp with time zone	not null,
	
	FOREIGN KEY(storcli_host_uuid) REFERENCES hosts(host_uuid)
);
ALTER TABLE storcli OWNER TO #!variable!user!#;

-- Supported Operations
CREATE TABLE storcli_supported_ops (
	storcli_supported_ops_id			uuid				primary key,
	storcli_supported_ops_storcli_adapter_uuid	uuid				not null,
	storcli_supported_ops_rebuild_rate		boolean,
	storcli_supported_ops_cc_rate			boolean,
	storcli_supported_ops_bgi_rate			boolean,
	storcli_supported_ops_reconstruct_rate		boolean,
	storcli_supported_ops_patrol_read_rate		boolean,
	storcli_supported_ops_alarm_control		boolean,
	storcli_supported_ops_cluster_support		boolean,
	storcli_supported_ops_bbu			boolean,
	storcli_supported_ops_spanning			boolean,
	storcli_supported_ops_dedicated_hot_spare	boolean,
	storcli_supported_ops_revertible_hot_spares	boolean,
	storcli_supported_ops_foreign_config_import	boolean,
	storcli_supported_ops_self_diagnostic		boolean,
	storcli_supported_ops_allow_mixed_redundancy	boolean,	-- Still needs to be defined!
	storcli_supported_ops_global_hot_spares		boolean,
	storcli_supported_ops_deny_scsi_passthrough	boolean,
	storcli_supported_ops_deny_smp_passthrough	boolean,
	storcli_supported_ops_deny_stp_passthrough	boolean,
	storcli_supported_ops_support_more_than_8_pd	boolean,
	storcli_supported_ops_fw_and_event_time_in_gmt	boolean,
	storcli_supported_ops_enhanced_foreign_import	boolean,
	storcli_supported_ops_enclosure_enumeration	boolean,
	storcli_supported_ops_allowed_operations	boolean,
	storcli_supported_ops_abort_cc_on_error		boolean,
	storcli_supported_ops_multipath			boolean,
	storcli_supported_ops_odd_even_pd_count_raid1e	boolean,
	storcli_supported_ops_		boolean,
	storcli_supported_ops_		boolean,
	storcli_supported_ops_		boolean,
	storcli_supported_ops_		boolean,
	storcli_supported_ops_		boolean,
	
	modified_date					timestamp with time zone	not null,

	FOREIGN KEY(storcli_supported_ops_storcli_adapter_uuid) REFERENCES storcli_adapter(storcli_adapter_uuid)
);
	
	
	
	-- PCI Info
	storcli_adapter_controller_id		text,
	storcli_adapter_vendor_id		text,
	storcli_adapter_subvendor_id		text,
	storcli_adapter_device_id		text,
	storcli_adapter_subdevice_id		text,
	storcli_adapter_host_interface		text,
	storcli_adapter_chip_revision		text,
	storcli_adapter_link_speed		text,
	storcli_adapter_device_interface	text,
	storcli_adapter_frontend_port_number	text,						-- External ports
	storcli_adapter_backend_port_number	text,						-- Internal ports
	-- Hardware Info
	storcli_adapter_bbu_present		boolean,
	storcli_adapter_alarm_present		boolean,					-- This is NOT set by the existence of a problem, simply that there is an alarm available
	storcli_adapter_nvram_present		boolean,
	storcli_adapter_serial_debugger_present	boolean,
	storcli_adapter_memory_present		boolean,
	storcli_adapter_flash_present		boolean,
	storcli_adapter_memory_size		numeric,					-- Raw bytes
	storcli_adapter_tpm_present		boolean,
	storcli_adapter_onboard_expander	boolean,
	storcli_adapter_upgrade_key		boolean,
	storcli_adapter_roc_temp_sensor		boolean,
	storcli_adapter_controller_temp_sensor	boolean,
	storcli_adapter_troc_temperature	double precision,				-- In degree C
	-- Settings
	storcli_adapter_battery_fru		text,
	storcli_adapter_	text,
	storcli_adapter_	text,
	storcli_adapter_	text,
	storcli_adapter_	text,
	storcli_adapter_	text,
	storcli_adapter_	text,
	storcli_adapter_	text,
	
	modified_date					timestamp with time zone	not null,
	
	FOREIGN KEY(storcli_host_uuid) REFERENCES hosts(host_uuid)
);
ALTER TABLE storcli OWNER TO #!variable!user!#;

CREATE TABLE history.storcli (
	history_id			bigserial,
	storcli_uuid			uuid,
	storcli_host_uuid		uuid,
	storcli_sensor_host		text				not null,
	storcli_sensor_name		text				not null,
	storcli_sensor_units		text				not null,
	storcli_sensor_status		text				not null,
	storcli_sensor_high_critical	numeric,
	storcli_sensor_high_warning	numeric,
	storcli_sensor_low_critical	numeric,
	storcli_sensor_low_warning	numeric,
	modified_date			timestamp with time zone	not null
);
ALTER TABLE history.storcli OWNER TO #!variable!user!#;

CREATE FUNCTION history_storcli() RETURNS trigger
AS $$
DECLARE
	history_storcli RECORD;
BEGIN
	SELECT INTO history_storcli * FROM storcli WHERE storcli_uuid=new.storcli_uuid;
	INSERT INTO history.storcli
		(storcli_uuid,
		 storcli_host_uuid, 
		 storcli_sensor_host, 
		 storcli_sensor_name, 
		 storcli_sensor_units, 
		 storcli_sensor_status, 
		 storcli_sensor_high_critical, 
		 storcli_sensor_high_warning, 
		 storcli_sensor_low_critical, 
		 storcli_sensor_low_warning, 
		 modified_date)
	VALUES
		(history_storcli.storcli_uuid,
		 history_storcli.storcli_host_uuid, 
		 history_storcli.storcli_sensor_host, 
		 history_storcli.storcli_sensor_name, 
		 history_storcli.storcli_sensor_units, 
		 history_storcli.storcli_sensor_status, 
		 history_storcli.storcli_sensor_high_critical, 
		 history_storcli.storcli_sensor_high_warning, 
		 history_storcli.storcli_sensor_low_critical, 
		 history_storcli.storcli_sensor_low_warning, 
		 history_storcli.modified_date);
	RETURN NULL;
END;
$$
LANGUAGE plpgsql;
ALTER FUNCTION history_storcli() OWNER TO #!variable!user!#;

CREATE TRIGGER trigger_storcli
	AFTER INSERT OR UPDATE ON storcli
	FOR EACH ROW EXECUTE PROCEDURE history_storcli();


-- ----------------------------------------------------------------------------------------------------------

-- Information on firmware
CREATE TABLE storcli_firmware (
	storcli_firmware_id				uuid				primary key,
	storcli_firmware_storcli_adapter_uuid		uuid				not null,
	storcli_firmware_package_build			text,
	storcli_firmware_version			text,
	storcli_firmware_bios_version			text,
	storcli_firmware_webbios_version		text,
	storcli_firmware_preboot_cli_version		text,
	storcli_firmware_nvdata_version			text,
	storcli_firmware_boot_block_version		text,
	storcli_firmware_bootloader_version		text,
	storcli_firmware_driver_name			text,
	storcli_firmware_driver_version			text,
	storcli_firmware_pending_images_in_flash	text,
	modified_date					timestamp with time zone	not null,

	FOREIGN KEY(storcli_firmware_storcli_adapter_uuid) REFERENCES storcli_adapter(storcli_adapter_uuid)
);

-- Information on bus
CREATE TABLE storcli_bus (
	storcli_bus_id				uuid				primary key,
	storcli_bus_storcli_adapter_uuid	uuid				not null,
	storcli_bus_vendor_id			text,
	storcli_bus_device_id			text,
	storcli_bus_subvendor_id		text,
	storcli_bus_subdevice_id		text,
	storcli_bus_host_interface		text,
	storcli_bus_device_interface		text,
	storcli_bus_bus_number			numeric,
	storcli_bus_device_number		numeric,
	storcli_bus_function_number		numeric,
	modified_date				timestamp with time zone	not null,

	FOREIGN KEY(storcli_bus_storcli_adapter_uuid) REFERENCES storcli_adapter(storcli_adapter_uuid)
);

-- Status information
CREATE TABLE storcli_status (
	storcli_status_id				uuid				primary key,
	storcli_status_storcli_adapter_uuid		uuid				not null,
	storcli_status_controller_status		text,
	storcli_status_memory_correctable_errors	numeric,
	storcli_status_memory_uncorrectable_errors	numeric,
	storcli_status_ecc_bucket_count			numeric,
	storcli_status_any_offline_vd_cache_preserved	boolean,
	storcli_status_bbu_status			numeric,
	storcli_status_support_pd_firmware_download	boolean,
	storcli_status_lock_key_assigned		boolean,
	storcli_status_failed_to_get_lock_key_on_bootup	boolean,
	storcli_status_bios_not_detected_during_boot	boolean,
	storcli_status_rebooted_for_security_operation	boolean,
	storcli_status_rollback_operation_in_progress	boolean,
	storcli_status_at_least_one_pfk_exists_in_nvram	boolean,
	storcli_status_ssc_policy_is_wb			boolean,
	storcli_status_controller_booted_into_safe_mode	boolean,
	modified_date					timestamp with time zone	not null,

	FOREIGN KEY(storcli_status_storcli_adapter_uuid) REFERENCES storcli_adapter(storcli_adapter_uuid)
);





-- ----------------------------------------------------------------------------------------------------------

-- Adapter settings (We do not record the date on the controller because it'll change every scan)
CREATE TABLE storcli_settings (
	storcli_settings_id					uuid				primary key,
	storcli_settings_storcli_adapter_uuid			uuid				not null,
	storcli_settings_predictive_fail_poll_interval		numeric,					-- Number of seconds
	storcli_settings_interrupt_throttle_active_count	numeric,
	storcli_settings_interrupt_throttle_completion		numeric,					-- Number of us
	storcli_settings_rebuild_rate				numeric,					-- Percentage of total bandwidth
	storcli_settings_patrol_read_rate			numeric,					-- Percentage - scans PDs looking for errors early
	storcli_settings_background_initialization_rate		numeric,					-- Percentage
	storcli_settings_check_consistency_rate			numeric,					-- Percentage
	storcli_settings_reconstruction_rate			numeric,					-- Percentage
	storcli_settings_cache_flush_interval			numeric,					-- Number of seconds
	storcli_settings_max_simultaneous_drive_spinup		numeric,					-- Drive count
	storcli_settings_spinup_group_delay			numeric,					-- Number of seconds to wait between drive group spinup
	storcli_settings_physical_drive_coercion_mode		boolean,					-- TRUE == enabled, FALSE == Disabled - ?
	storcli_settings_cluster_mode				boolean,					-- TRUE == enabled, FALSE == Disabled - ?
	storcli_settings_alarm					boolean,					-- TRUE == ?, FALSE == Disabled
	storcli_settings_auto_rebuild				boolean,					-- TRUE == enabled, FALSE == Disabled
	storcli_settings_battery_warning			boolean,					-- 
	storcli_settings_ecc_bucket_size			numeric,					-- ?
	storcli_settings_ecc_bucket_leak_rate			numeric,					-- Number of seconds
	storcli_settings_restore_hotspare_on_insertion		boolean,					-- TRUE == enabled, FALSE == Disabled
	storcli_settings_expose_enclosure_devices		boolean,					-- TRUE == enabled, FALSE == Disabled
	storcli_settings_maintain_physical_disk_fail_history	boolean,					-- TRUE == enabled, FALSE == Disabled
	storcli_settings_host_request_reordering		boolean,					-- TRUE == enabled, FALSE == Disabled
	storcli_settings_auto_detect_backplane_enabled		text,
	storcli_settings_load_balance_mode			text,
	storcli_settings_		boolean,
	storcli_settings_		numeric,

	modified_date			timestamp with time zone	not null

	FOREIGN KEY(storcli_settings_storcli_adapter_uuid) REFERENCES storcli_adapter(storcli_adapter_uuid)
);

-- Information on ports
CREATE TABLE storcli_port (
	storcli_port_id				uuid				primary key,
	storcli_port_storcli_adapter_uuid	uuid				not null,
	storcli_port_type			text				not null,	-- 'frontend' == external port, 'backend' == internal port
	storcli_port_number			numeric				not null,
	storcli_port_address			text				not null,
	modified_date				timestamp with time zone	not null

	FOREIGN KEY(storcli_port_storcli_uuid) REFERENCES storcli_adapter(storcli_adapter_uuid)
);
