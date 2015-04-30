-- This is the core database schema for ScanCore. 
-- It expects PostgreSQL v. 9.x

SET client_encoding       = 'UTF8';

CREATE SCHEMA history;
ALTER SCHEMA history OWNER to #!variable!user!#;

CREATE TABLE hosts (
	host_id			serial				primary key,
	host_name		text				not null,
	host_type		text				not null,			-- Either 'node' or 'dashboard'.
	host_bcn_ip		text,								-- Might want to make this inet or cidr later.
	host_ifn_ip		text,								-- Might want to make this inet or cidr later.
	host_status		text,
	modified_user		integer				not null	default 1,
	modified_date		timestamp with time zone	not null	default now()
);
ALTER TABLE hosts OWNER TO #!variable!user!#;

CREATE TABLE history.hosts (
	host_id			serial,
	history_id		serial,
	host_name		text,
	host_type		text,
	host_bcn_ip		text,								-- Might want to make this inet or cidr later.
	host_ifn_ip		text,								-- Might want to make this inet or cidr later.
	host_status		text,
	modified_user		int				not null	default 1,
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
		modified_user,
		modified_date)
	VALUES
		(history_hosts.host_id,
		history_hosts.host_name,
		history_hosts.host_type,
		history_hosts.host_bcn_ip,
		history_hosts.host_ifn_ip,
		history_hosts.host_status,
		history_hosts.modified_user,
		history_hosts.modified_user);
	RETURN NULL;
END;
$$
LANGUAGE plpgsql;
ALTER FUNCTION history_hosts() OWNER TO #!variable!user!#;

CREATE TRIGGER trigger_hosts
	AFTER INSERT OR UPDATE ON hosts
	FOR EACH ROW EXECUTE PROCEDURE history_hosts();


-- 'Temperature' sensor types all have the default hysteresis of '1'. These can
-- be tuned in striker.conf with:
--   scancore::agent::<foo>::hysteresis::<alert_sensor_name> = X
-- The total score needed to trigger a thermal shutdown is '5'. This can be
-- altered with:
--   scancore::core::thermal::over::shutdown_score = X
--   scancore::core::thermal::under::shutdown_score = X

-- This stores alerts coming in from various agents
CREATE TABLE alerts (
	alert_id		serial				primary key,
	alert_host_id		int				not null,			-- The name of the node or dashboard that this alert came from.
	alert_agent_name	text				not null,
	alert_sensor_name	text				not null,			-- This is the name of the sensor causing this alert. Note that this must match the name used in striker.conf for the hysteresis tuning
	alert_sensor_type	text				not null,			-- "temperature", "power", "server", "information" - These are used for making shutdown/restart decisions. "temperature", "power" and "server" should only be used when going to hot/cold, when power is lost (or the batteries are otherwise depleting, like in a brown-out) or when a server needs to be restarted.
	alert_seconds_remaining	int,								-- When 'alert_sensor_type' is 'power', this must be set to the number of minutes remaining in the UPS.
	alert_temp_event_type	text,								-- "over" or "under" - When 'alert_sensor_type' is 'temperature', this tells ScanCore if it is an over temp or under temp alarm.
	alert_temp_value	real,								-- When 'alert_sensor_type' is 'temperature', this will have the temperature in celcius.
	alert_message_key	text,								-- ScanCore will read in the agents <name>.xml words file and look for this message key
	alert_message_variables	text,								-- List of variables to substitute into the message key. Format is 'var1=val1 #!# var2 #!# val2 #!# ... #!# varN=valN'.
	modified_user		integer				not null	default 1,
	modified_date		timestamp with time zone	not null	default now(),
	
	FOREIGN KEY(alert_host_id) REFERENCES hosts(host_id)
);
ALTER TABLE alerts OWNER TO #!variable!user!#;

CREATE TABLE history.alerts (
	alert_id		bigint,
	alert_host_id		int,
	alert_agent_name	text,
	alert_sensor_name	text,
	alert_sensor_type	text,
	alert_seconds_remaining	int,
	alert_temp_event_type	text,
	alert_temp_value	real,
	alert_message_key	text,
	alert_message_variables	text,
	modified_user		int				not null	default 1,
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
		modified_user,
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
		history_alerts.modified_user,
		history_alerts.modified_user);
	RETURN NULL;
END;
$$
LANGUAGE plpgsql;
ALTER FUNCTION history_alerts() OWNER TO #!variable!user!#;

CREATE TRIGGER trigger_alerts
	AFTER INSERT OR UPDATE ON alerts
	FOR EACH ROW EXECUTE PROCEDURE history_alerts();
