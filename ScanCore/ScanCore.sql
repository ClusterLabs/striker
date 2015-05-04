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
	host_bcn_ip		text,								-- Might want to make this inet or cidr later.
	host_ifn_ip		text,								-- Might want to make this inet or cidr later.
	host_status		text,
	modified_date		timestamp with time zone	not null	default now()
);
ALTER TABLE hosts OWNER TO #!variable!user!#;

CREATE TABLE history.hosts (
	history_id		bigserial,
	host_id			bigint,
	host_name		text,
	host_type		text,
	host_bcn_ip		text,								-- Might want to make this inet or cidr later.
	host_ifn_ip		text,								-- Might want to make this inet or cidr later.
	host_status		text,
	modified_date		timestamp with time zone	not null	default now()
);
ALTER TABLE history.hosts OWNER TO #!variable!user!#;

CREATE FUNCTION history_hosts() RETURNS trigger
AS $$
DECLARE
	history_hosts RECORD;
BEGIN
	SELECT INTO history_hosts * FROM hosts WHERE host_id=new.host_id;
	INSERT INTO history.hosts
		(host_id,
		host_name,
		host_type,
		host_bcn_ip,
		host_ifn_ip,
		host_status,
		modified_date)
	VALUES
		(history_hosts.host_id,
		history_hosts.host_name,
		history_hosts.host_type,
		history_hosts.host_bcn_ip,
		history_hosts.host_ifn_ip,
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


-- This is a simple table used by ScanCore to record when the last scan
-- finished. If, when ScanCore connects, this table is behind another
-- database, the data will be copied out from the most up to date DB and
-- written to this DB. As such, this table has no history.
CREATE TABLE last_updated (
	last_updated_host_id	bigint,
	last_updated_date	timestamp with time zone	not null	default now(),
	
	FOREIGN KEY(last_updated_host_id) REFERENCES hosts(host_id)
);
ALTER TABLE last_updated OWNER TO #!variable!user!#;


-- 'Temperature' sensor types all have the default hysteresis of '1'. These can
-- be tuned in striker.conf with:
--   scancore::agent::<foo>::hysteresis::<alert_sensor_name> = X
-- The total score needed to trigger a thermal shutdown is '5'. This can be
-- altered with:
--   scancore::core::thermal::over::shutdown_score = X
--   scancore::core::thermal::under::shutdown_score = X

-- This stores alerts coming in from various agents
CREATE TABLE alerts (
	alert_id		bigserial				primary key,
	alert_host_id		bigint				not null,			-- The name of the node or dashboard that this alert came from.
	alert_agent_name	text				not null,
	alert_sensor_name	text				not null,			-- This is the name of the sensor causing this alert. Note that this must match the name used in striker.conf for the hysteresis tuning
	alert_sensor_type	text				not null,			-- "temperature", "power", "server", "information" - These are used for making shutdown/restart decisions. "temperature", "power" and "server" should only be used when going to hot/cold, when power is lost (or the batteries are otherwise depleting, like in a brown-out) or when a server needs to be restarted.
	alert_seconds_remaining	bigint,								-- When 'alert_sensor_type' is 'power', this must be set to the number of minutes remaining in the UPS.
	alert_temp_event_type	text,								-- "over" or "under" - When 'alert_sensor_type' is 'temperature', this tells ScanCore if it is an over temp or under temp alarm.
	alert_temp_value	real,								-- When 'alert_sensor_type' is 'temperature', this will have the temperature in celcius.
	alert_message_key	text,								-- ScanCore will read in the agents <name>.xml words file and look for this message key
	alert_message_variables	text,								-- List of variables to substitute into the message key. Format is 'var1=val1 #!# var2 #!# val2 #!# ... #!# varN=valN'.
	modified_date		timestamp with time zone	not null	default now(),
	
	FOREIGN KEY(alert_host_id) REFERENCES hosts(host_id)
);
ALTER TABLE alerts OWNER TO #!variable!user!#;

CREATE TABLE history.alerts (
	history_id		bigserial,
	alert_id		bigint,
	alert_host_id		bigint,
	alert_agent_name	text,
	alert_sensor_name	text,
	alert_sensor_type	text,
	alert_seconds_remaining	bigint,
	alert_temp_event_type	text,
	alert_temp_value	real,
	alert_message_key	text,
	alert_message_variables	text,
	modified_date		timestamp with time zone	not null	default now()
);
ALTER TABLE history.alerts OWNER TO #!variable!user!#;

CREATE FUNCTION history_alerts() RETURNS trigger
AS $$
DECLARE
	history_alerts RECORD;
BEGIN
	SELECT INTO history_alerts * FROM alerts WHERE host_id=new.host_id;
	INSERT INTO history.alerts
		(alert_id,
		alert_host_id,
		alert_agent_name,
		alert_sensor_name,
		alert_sensor_type,
		alert_seconds_remaining,
		alert_temp_event_type,
		alert_temp_value,
		alert_message_key,
		alert_message_variables,
		modified_date)
	VALUES
		(history_alerts.alert_id,
		history_alerts.alert_host_id,
		history_alerts.alert_agent_name,
		history_alerts.alert_sensor_name,
		history_alerts.alert_sensor_type,
		history_alerts.alert_seconds_remaining,
		history_alerts.alert_temp_event_type,
		history_alerts.alert_temp_value,
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


-- This stores information about the scan agents on this system
CREATE TABLE agents (
	agents_id		bigserial				primary key,
	agents_host_id		bigint				not null,
	agents_name		text				not null,			-- This is the name of the scan agent file name
	agents_last_exit_code	int				not null,			-- This is the exit code from the last run
	agents_runtime		int				not null,			-- This is the number of seconds it took for the agent to run last time.
	modified_date		timestamp with time zone	not null	default now(),
	
	FOREIGN KEY(agents_host_id) REFERENCES hosts(host_id)
);
ALTER TABLE agents OWNER TO #!variable!user!#;

CREATE TABLE history.agents (
	history_id		bigserial,
	agents_id		bigint,
	agents_host_id		bigint,
	agents_name		text				not null,
	agents_last_exit_code	int				not null,
	agents_runtime		int				not null,
	modified_date		timestamp with time zone	not null	default now()
);
ALTER TABLE history.agents OWNER TO #!variable!user!#;

CREATE FUNCTION history_agents() RETURNS trigger
AS $$
DECLARE
	history_agents RECORD;
BEGIN
	SELECT INTO history_agents * FROM agents WHERE host_id=new.host_id;
	INSERT INTO history.agents
		(agents_id,
		agents_host_id,
		agents_name,
		agents_last_exit_code,
		agents_runtime,
		modified_date)
	VALUES
		(history_agents.agents_id,
		history_agents.agents_host_id,
		history_agents.agents_name,
		history_agents.agents_last_exit_code,
		history_agents.agents_runtime,
		history_agents.modified_date);
	RETURN NULL;
END;
$$
LANGUAGE plpgsql;
ALTER FUNCTION history_agents() OWNER TO #!variable!user!#;

CREATE TRIGGER trigger_agents
	AFTER INSERT OR UPDATE ON agents
	FOR EACH ROW EXECUTE PROCEDURE history_agents();
