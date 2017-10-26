-- This is the database schema for the 'hpacucli Scan Agent'.
--       
--       Things that change rarely should go in the main tables (even if we won't explicitely watch for them
--       to change with specific alerts).

-- ------------------------------------------------------------------------------------------------------- --
-- Adapter                                                                                                 --
-- ------------------------------------------------------------------------------------------------------- --

-- Here is the basic controller information. All connected devices will reference back to this table's 
-- 'hpacucli_controller_serial_number' column.
CREATE TABLE hpacucli_controllers (
	hpacucli_controller_uuid		uuid				primary key,
	hpacucli_controller_host_uuid		uuid				not null,
	hpacucli_controller_serial_number	text				not null,	-- This is the core identifier
	hpacucli_controller_model		text				not null,	-- 
	hpacucli_controller_status		text				not null,	-- 
	hpacucli_controller_last_diagnostics	numeric,					-- Collecting diagnostics information is very expensive, so we do it once every hour (or whatever the user chooses).
	modified_date				timestamp with time zone	not null,
	
	FOREIGN KEY(hpacucli_controller_host_uuid) REFERENCES hosts(host_uuid)
);
ALTER TABLE hpacucli_controllers OWNER TO #!variable!user!#;

CREATE TABLE history.hpacucli_controllers (
	history_id				bigserial,
	hpacucli_controller_uuid		uuid,
	hpacucli_controller_host_uuid		uuid,
	hpacucli_controller_serial_number	text,
	hpacucli_controller_model		text,
	hpacucli_controller_status		text,
	hpacucli_controller_last_diagnostics	numeric,
	modified_date				timestamp with time zone
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
		 modified_date)
	VALUES 
		(history_hpacucli_controllers.hpacucli_controller_uuid,
		 history_hpacucli_controllers.hpacucli_controller_host_uuid,
		 history_hpacucli_controllers.hpacucli_controller_serial_number, 
		 history_hpacucli_controllers.hpacucli_controller_model, 
		 history_hpacucli_controllers.hpacucli_controller_status, 
		 history_hpacucli_controllers.hpacucli_controller_last_diagnostics, 
		 history_hpacucli_controllers.modified_date);
	RETURN NULL;
END;
$$
LANGUAGE plpgsql;
ALTER FUNCTION history_hpacucli_controllers() OWNER TO #!variable!user!#;

CREATE TRIGGER trigger_hpacucli_controllers
	AFTER INSERT OR UPDATE ON hpacucli_controllers
	FOR EACH ROW EXECUTE PROCEDURE history_hpacucli_controllers();


-- This table is used for BBU and FBU caching.
CREATE TABLE hpacucli_cache_modules (
	hpacucli_cache_module_uuid			uuid				primary key,
	hpacucli_cache_module_host_uuid			uuid				not null,
	hpacucli_cache_module_hpacucli_controller_uuid	uuid				not null,	-- The controller this module is connected to
	hpacucli_cache_module_serial_number		text				not null,
	hpacucli_cache_module_status			text				not null,
	hpacucli_cache_module_type			text				not null,
	hpacucli_cache_module_size			numeric				not null,	-- In bytes
	modified_date					timestamp with time zone	not null,
	
	FOREIGN KEY(hpacucli_cache_module_host_uuid)                REFERENCES hosts(host_uuid),
	FOREIGN KEY(hpacucli_cache_module_hpacucli_controller_uuid) REFERENCES hpacucli_controllers(hpacucli_controller_uuid)
);
ALTER TABLE hpacucli_cache_modules OWNER TO #!variable!user!#;

CREATE TABLE history.hpacucli_cache_modules (
	history_id					bigserial,
	hpacucli_cache_module_uuid			uuid,
	hpacucli_cache_module_host_uuid			uuid,
	hpacucli_cache_module_hpacucli_controller_uuid	uuid,
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
		 hpacucli_cache_module_hpacucli_controller_uuid, 
		 hpacucli_cache_module_serial_number, 
		 hpacucli_cache_module_status, 
		 hpacucli_cache_module_type, 
		 hpacucli_cache_module_size, 
		 modified_date)
	VALUES 
		(history_hpacucli_cache_modules.hpacucli_cache_module_uuid,
		 history_hpacucli_cache_modules.hpacucli_cache_module_host_uuid,
		 history_hpacucli_cache_modules.hpacucli_cache_module_hpacucli_controller_uuid, 
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
