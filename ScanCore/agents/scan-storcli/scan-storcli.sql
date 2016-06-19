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


