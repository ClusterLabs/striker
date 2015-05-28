-- This is the core database schema for ScanCore. 
-- It expects PostgreSQL v. 9.x

SET client_encoding = 'UTF8';
CREATE SCHEMA IF NOT EXISTS history;

-- DO $$
-- BEGIN
--     IF NOT EXISTS
--     (
--         SELECT schema_name
--         FROM information_schema.schemata
--         WHERE schema_name = 'history'
--     )
--     THEN
--       EXECUTE 'CREATE SCHEMA history';
--     END IF;
-- END
-- $$;
-- ALTER SCHEMA history OWNER to #!variable!user!#;

-- -------------------------------------------------- --
-- TODO: Make everything below conditional like above --
-- -------------------------------------------------- --

-- This stores information about the host machine running this instance of
-- ScanCore. All agents will reference this table.
CREATE TABLE hosts (
	host_id			bigserial			primary key,
	host_name		text				not null,
	host_type		text				not null,			-- Either 'node' or 'dashboard'.
	host_status		text,
	modified_date		timestamp with time zone	not null
);
ALTER TABLE hosts OWNER TO #!variable!user!#;

CREATE TABLE history.hosts (
	history_id		bigserial,
	host_id			bigint,
	host_name		text,
	host_type		text,
	host_status		text,
	modified_date		timestamp with time zone	not null
);
ALTER TABLE history.hosts OWNER TO #!variable!user!#;

CREATE FUNCTION history_hosts() RETURNS trigger
AS $$
DECLARE
	history_hosts RECORD;
BEGIN
	SELECT INTO history_hosts * FROM hosts WHERE host_id = new.host_id;
	INSERT INTO history.hosts
		(host_id,
		host_name,
		host_type,
		host_status,
		modified_date)
	VALUES
		(history_hosts.host_id,
		history_hosts.host_name,
		history_hosts.host_type,
		history_hosts.host_status,
		history_hosts.modified_date);
	RETURN NULL;
END;
$$
LANGUAGE plpgsql;
ALTER FUNCTION history_hosts() OWNER TO #!variable!user!#;

CREATE TRIGGER trigger_hosts
	AFTER INSERT OR UPDATE ON hosts
	FOR EACH ROW EXECUTE PROCEDURE history_hosts();


-- This stores alerts coming in from various agents
CREATE TABLE alerts (
	alert_id		bigserial			primary key,
	alert_host_id		bigint				not null,			-- The name of the node or dashboard that this alert came from.
	alert_agent_name	text				not null,
	alert_level		text				not null,			-- debug (log only), info (+ admin email), notice (+ curious users), warning (+ client technical staff), critical (+ all)
	alert_title_key		text,								-- ScanCore will read in the agents <name>.xml words file and look for this message key
	alert_title_variables	text,								-- List of variables to substitute into the message key. Format is 'var1=val1 #!# var2 #!# val2 #!# ... #!# varN=valN'.
	alert_message_key	text,								-- ScanCore will read in the agents <name>.xml words file and look for this message key
	alert_message_variables	text,								-- List of variables to substitute into the message key. Format is 'var1=val1 #!# var2 #!# val2 #!# ... #!# varN=valN'.
	modified_date		timestamp with time zone	not null,
	
	FOREIGN KEY(alert_host_id) REFERENCES hosts(host_id)
);
ALTER TABLE alerts OWNER TO #!variable!user!#;

CREATE TABLE history.alerts (
	history_id		bigserial,
	alert_id		bigint,
	alert_host_id		bigint,
	alert_agent_name	text,
	alert_level		text,
	alert_title_key		text,
	alert_title_variables	text,
	alert_message_key	text,
	alert_message_variables	text,
	modified_date		timestamp with time zone	not null
);
ALTER TABLE history.alerts OWNER TO #!variable!user!#;

CREATE FUNCTION history_alerts() RETURNS trigger
AS $$
DECLARE
	history_alerts RECORD;
BEGIN
	SELECT INTO history_alerts * FROM alerts WHERE alert_id = new.alert_id;
	INSERT INTO history.alerts
		(alert_id,
		alert_host_id,
		alert_agent_name,
		alert_level,
		alert_title_key,
		alert_title_variables,
		alert_message_key,
		alert_message_variables,
		modified_date)
	VALUES
		(history_alerts.alert_id,
		history_alerts.alert_host_id,
		history_alerts.alert_agent_name,
		history_alerts.alert_level,
		history_alerts.alert_title_key,
		history_alerts.alert_title_variables,
		history_alerts.alert_message_key,
		history_alerts.alert_message_variables,
		history_alerts.modified_date);
	RETURN NULL;
END;
$$
LANGUAGE plpgsql;
ALTER FUNCTION history_alerts() OWNER TO #!variable!user!#;

CREATE TRIGGER trigger_alerts
	AFTER INSERT OR UPDATE ON alerts
	FOR EACH ROW EXECUTE PROCEDURE history_alerts();


-- This is used to indicate the power state of UPSes. It is used to determine
-- when the system needs to be powered off. All UPS-type scan agents must use
-- this table (in addition to any tables they may wish to use)
CREATE TABLE power (
	power_id		bigserial			primary key,
	power_host_id		bigint				not null,			-- The name of the node or dashboard that this power came from.
	power_agent_name	text				not null,
	power_state		text				not null,			-- normal (nominal voltage), low (UPS is boosting), high (UPS is trimming), loss (no input power)
	power_on_battery	boolean				not null,			-- TRUE == use "time_remaining" to determine if graceful power off is needed. FALSE == power loss NOT imminent, do not power off node. 
	power_seconds_left	bigint,								-- Should always be set, but not required *EXCEPT* when 'power_on_battery' is TRUE.
	power_charge_percentage	double precision,						-- Percentage charge in the UPS. Used to determine when the dashboard should boot the node after AC restore
	power_load_percentage	double precision,						-- Can be used to more accurately determine time remaining
	modified_date		timestamp with time zone	not null,
	
	FOREIGN KEY(power_host_id) REFERENCES hosts(host_id)
);
ALTER TABLE power OWNER TO #!variable!user!#;

CREATE TABLE history.power (
	history_id		bigserial,
	power_id		bigint,
	power_host_id		bigint,
	power_agent_name	text,
	power_state		text,
	power_on_battery	boolean,
	power_seconds_left	bigint,
	power_charge_percentage	double precision,
	power_load_percentage	double precision,
	modified_date		timestamp with time zone	not null
);
ALTER TABLE history.power OWNER TO #!variable!user!#;

CREATE FUNCTION history_power() RETURNS trigger
AS $$
DECLARE
	history_power RECORD;
BEGIN
	SELECT INTO history_power * FROM power WHERE power_id = new.power_id;
	INSERT INTO history.power
		(power_id,
		power_host_id,
		power_agent_name,
		power_state,
		power_on_battery,
		power_seconds_left,
		power_charge_percentage,
		power_load_percentage,
		modified_date)
	VALUES
		(history_power.power_id,
		history_power.power_host_id,
		history_power.power_agent_name,
		history_power.power_state,
		history_power.power_on_battery,
		history_power.power_seconds_left,
		history_power.power_charge_percentage,
		history_power.power_load_percentage,
		history_power.modified_date);
	RETURN NULL;
END;
$$
LANGUAGE plpgsql;
ALTER FUNCTION history_power() OWNER TO #!variable!user!#;

CREATE TRIGGER trigger_power
	AFTER INSERT OR UPDATE ON power
	FOR EACH ROW EXECUTE PROCEDURE history_power();


-- This stores alerts coming in from various agents
CREATE TABLE temperature (
	temperature_id		bigserial			primary key,
	temperature_host_id	bigint				not null,			-- The name of the node or dashboard that this temperature came from.
	temperature_agent_name	text				not null,
	temperature_sensor_name	text				not null,
	temperature_celcius	double precision		not null,
	temperature_state	text				not null,			-- warning, critical
	temperature_is		text				not null,			-- high or low
	temperature_jumped	boolean				not null,			-- Set true if the sensor is still in "Warning" but possibly indicative of a cooling failure.
	modified_date		timestamp with time zone	not null,
	
	FOREIGN KEY(temperature_host_id) REFERENCES hosts(host_id)
);
ALTER TABLE temperature OWNER TO #!variable!user!#;

CREATE TABLE history.temperature (
	history_id		bigserial,
	temperature_id		bigint,
	temperature_host_id	bigint,
	temperature_agent_name	text,
	temperature_sensor_name	text,
	temperature_celcius	double precision,
	temperature_state	text,
	temperature_is		text,
	temperature_jumped	boolean,
	modified_date		timestamp with time zone	not null
);
ALTER TABLE history.temperature OWNER TO #!variable!user!#;

CREATE FUNCTION history_temperature() RETURNS trigger
AS $$
DECLARE
	history_temperature RECORD;
BEGIN
	SELECT INTO history_temperature * FROM temperature WHERE temperature_id = new.temperature_id;
	INSERT INTO history.temperature
		(temperature_id,
		temperature_host_id,
		temperature_agent_name,
		temperature_sensor_name,
		temperature_celcius,
		temperature_state,
		temperature_is,
		temperature_jumped,
		modified_date)
	VALUES
		(history_temperature.temperature_id,
		history_temperature.temperature_host_id,
		history_temperature.temperature_agent_name,
		history_temperature.temperature_sensor_name,
		history_temperature.temperature_celcius,
		history_temperature.temperature_state,
		history_temperature.temperature_is,
		history_temperature.temperature_jumped,
		history_temperature.modified_date);
	RETURN NULL;
END;
$$
LANGUAGE plpgsql;
ALTER FUNCTION history_temperature() OWNER TO #!variable!user!#;

CREATE TRIGGER trigger_temperature
	AFTER INSERT OR UPDATE ON temperature
	FOR EACH ROW EXECUTE PROCEDURE history_temperature();


-- This stores information about the scan agents on this system
CREATE TABLE agents (
	agent_id		bigserial				primary key,
	agent_host_id		bigint				not null,
	agent_name		text				not null,			-- This is the name of the scan agent file name
	agent_exit_code		int				not null,			-- This is the exit code from the last run
	agent_runtime		int				not null,			-- This is the number of seconds it took for the agent to run last time.
	modified_date		timestamp with time zone	not null,
	
	FOREIGN KEY(agent_host_id) REFERENCES hosts(host_id)
);
ALTER TABLE agents OWNER TO #!variable!user!#;

CREATE TABLE history.agents (
	history_id		bigserial,
	agent_id		bigint,
	agent_host_id		bigint,
	agent_name		text				not null,
	agent_exit_code		int				not null,
	agent_runtime		int				not null,
	modified_date		timestamp with time zone	not null
);
ALTER TABLE history.agents OWNER TO #!variable!user!#;

CREATE FUNCTION history_agents() RETURNS trigger
AS $$
DECLARE
	history_agents RECORD;
BEGIN
	SELECT INTO history_agents * FROM agents WHERE agent_id = new.agent_id;
	INSERT INTO history.agents
		(agent_id,
		agent_host_id,
		agent_name,
		agent_exit_code,
		agent_runtime,
		modified_date)
	VALUES
		(history_agents.agent_id,
		history_agents.agent_host_id,
		history_agents.agent_name,
		history_agents.agent_exit_code,
		history_agents.agent_runtime,
		history_agents.modified_date);
	RETURN NULL;
END;
$$
LANGUAGE plpgsql;
ALTER FUNCTION history_agents() OWNER TO #!variable!user!#;

CREATE TRIGGER trigger_agents
	AFTER INSERT OR UPDATE ON agents
	FOR EACH ROW EXECUTE PROCEDURE history_agents();


-- ------------------------------------------------------------------------- --
-- NOTE: Because this will be updated on every run, we will use its          --
--       modified_data comlumn to determine if the tables in this schema     --
--       need to be updated.                                                 --
-- ------------------------------------------------------------------------- --

-- This stores information about the RAM used by ScanCore and it's agents.
CREATE TABLE ram_used (
	ram_used_id		bigserial,
	ram_used_host_id	bigint				not null,
	ram_used_by		text				not null,			-- Either 'ScanCore' or the scan agent name
	ram_used_bytes		bigint				not null,
	modified_date		timestamp with time zone	not null,
	
	FOREIGN KEY(ram_used_host_id) REFERENCES hosts(host_id)
);
ALTER TABLE ram_used OWNER TO #!variable!user!#;

CREATE TABLE history.ram_used (
	history_id		bigserial,
	ram_used_id		bigint,
	ram_used_host_id	bigint,
	ram_used_by		text				not null,			-- Either 'ScanCore' or the scan agent name
	ram_used_bytes		bigint				not null,
	modified_date		timestamp with time zone	not null
);
ALTER TABLE history.ram_used OWNER TO #!variable!user!#;

CREATE FUNCTION history_ram_used() RETURNS trigger
AS $$
DECLARE
	history_ram_used RECORD;
BEGIN
	SELECT INTO history_ram_used * FROM ram_used WHERE ram_used_id = new.ram_used_id;
	INSERT INTO history.ram_used
		(ram_used_id,
		ram_used_host_id,
		ram_used_by,
		ram_used_bytes,
		modified_date)
	VALUES
		(history_ram_used.ram_used_id,
		history_ram_used.ram_used_host_id,
		history_ram_used.ram_used_by,
		history_ram_used.ram_used_bytes,
		history_ram_used.modified_date);
	RETURN NULL;
END;
$$
LANGUAGE plpgsql;
ALTER FUNCTION history_ram_used() OWNER TO #!variable!user!#;

CREATE TRIGGER trigger_ram_used
	AFTER INSERT OR UPDATE ON ram_used
	FOR EACH ROW EXECUTE PROCEDURE history_ram_used();


-- This is a special table with no history that simply records the last time a
-- scan ran.
CREATE TABLE updated (
	updated_host_id		bigint				not null,
	updated_by		text				not null,			-- The name of the agent (or "ScanCore' itself) that updated.
	modified_date		timestamp with time zone	not null,
	
	FOREIGN KEY(updated_host_id) REFERENCES hosts(host_id)
);
ALTER TABLE updated OWNER TO #!variable!user!#;


