-- This is the core database schema for ScanCore. 
-- It expects PostgreSQL v. 9.x

SET client_encoding = 'UTF8';
CREATE SCHEMA IF NOT EXISTS history;


-- This stores infomation for sending email notifications. 
CREATE TABLE smtp (
	smtp_uuid		uuid				not null	primary key,	-- 
	smtp_server		text				not null,			-- example; mail.example.com
	smtp_port		integer				not null	default 587,
	smtp_username		text				not null,			-- This is the user name (usually email address) used when authenticating against the mail server.
	smtp_password		text,								-- This is the password used when authenticating against the mail server
	smtp_security		text				not null,			-- This is the security type used when authenticating against the mail server (STARTTLS, TLS/SSL or NONE)
	smtp_authentication	text				not null,			-- 'None', 'Plain Text', 'Encrypted' (will add other types later.
	smtp_helo_domain	text				not null,			-- The domain we identify to the mail server as being from.
	smtp_note		text,
	smtp_alt_server		text,								-- This is an alternate/backup mail server to use when the main SMTP server can't be accessed
	smtp_alt_port		text,								-- This is the TCP port for the alternate server
	modified_date		timestamp with time zone	not null
);
ALTER TABLE smtp OWNER TO #!variable!user!#;

CREATE TABLE history.smtp (
	history_id		bigserial,
	smtp_uuid		uuid,
	smtp_server		text,
	smtp_port		integer,
	smtp_username		text,
	smtp_password		text,
	smtp_security		text,
	smtp_authentication	text,
	smtp_helo_domain	text,
	smtp_note		text,
	smtp_alt_server		text,
	smtp_alt_port		text,
	modified_date		timestamp with time zone	not null
);
ALTER TABLE history.smtp OWNER TO #!variable!user!#;

CREATE FUNCTION history_smtp() RETURNS trigger
AS $$
DECLARE
	history_smtp RECORD;
BEGIN
	SELECT INTO history_smtp * FROM smtp WHERE smtp_uuid = new.smtp_uuid;
	INSERT INTO history.smtp
		(smtp_uuid, 
		 smtp_server, 
		 smtp_port, 
		 smtp_username, 
		 smtp_password, 
		 smtp_security, 
		 smtp_authentication, 
		 smtp_helo_domain, 
		 smtp_note, 
		 smtp_alt_server, 
		 smtp_alt_port, 
		 modified_date)
	VALUES
		(history_smtp.smtp_uuid, 
		 history_smtp.smtp_server, 
		 history_smtp.smtp_port, 
		 history_smtp.smtp_username, 
		 history_smtp.smtp_password, 
		 history_smtp.smtp_security, 
		 history_smtp.smtp_authentication, 
		 history_smtp.smtp_helo_domain, 
		 history_smtp.smtp_note, 
		 history_smtp.smtp_alt_server, 
		 history_smtp.smtp_alt_port, 
		 history_smtp.modified_date);
	RETURN NULL;
END;
$$
LANGUAGE plpgsql;
ALTER FUNCTION history_smtp() OWNER TO #!variable!user!#;

CREATE TRIGGER trigger_smtp
	AFTER INSERT OR UPDATE ON smtp
	FOR EACH ROW EXECUTE PROCEDURE history_smtp();


-- This stores information about the company or organization that owns one or more Anvil! systems. 
CREATE TABLE owners (
	owner_uuid		uuid				not null	primary key,	-- This is the single most important record in ScanCore. Everything links back to here.
	owner_name		text				not null,
	owner_note		text,								-- This is a free-form note area for admins to record details about this Anvil!.
	modified_date		timestamp with time zone	not null
);
ALTER TABLE owners OWNER TO #!variable!user!#;

CREATE TABLE history.owners (
	history_id		bigserial,
	owner_uuid		uuid, 
	owner_name		text, 
	owner_note		text,
	modified_date		timestamp with time zone	not null
);
ALTER TABLE history.owners OWNER TO #!variable!user!#;

CREATE FUNCTION history_owners() RETURNS trigger
AS $$
DECLARE
	history_owners RECORD;
BEGIN
	SELECT INTO history_owners * FROM owners WHERE owner_uuid = new.owner_uuid;
	INSERT INTO history.owners
		(owner_uuid, 
		 owner_name, 
		 owner_note, 
		 modified_date)
	VALUES
		(history_owners.owner_uuid, 
		 history_owners.owner_name, 
		 history_owners.owner_note, 
		 history_owners.modified_date);
	RETURN NULL;
END;
$$
LANGUAGE plpgsql;
ALTER FUNCTION history_owners() OWNER TO #!variable!user!#;

CREATE TRIGGER trigger_owners
	AFTER INSERT OR UPDATE ON owners
	FOR EACH ROW EXECUTE PROCEDURE history_owners();


-- This stores information about Anvil! systems. 
CREATE TABLE anvils (
	anvil_uuid		uuid				not null	primary key,	-- 
	anvil_owner_uuid	uuid				not null	not null,	-- NOTE: Make life easy for users; Auto-generate the 'owner' if they enter one that doesn't exist.
	anvil_smtp_uuid		uuid,								-- This is the mail server to use when sending email notifications. It is not required because some users use file-based notifications only.
	anvil_name		text				not null,
	anvil_description	text				not null,			-- This is a short, one-line (usually) description of this particular Anvil!. It is displayed in the Anvil! selection list.
	anvil_note		text,								-- This is a free-form note area for admins to record details about this Anvil!.
	anvil_password		text				not null,			-- This is the 'ricci' or 'hacluster' user password. It is also used to access nodes that don't have a specific password set.
	modified_date		timestamp with time zone	not null,
	
	FOREIGN KEY(anvil_owner_uuid) REFERENCES owners(owner_uuid),
	FOREIGN KEY(anvil_smtp_uuid) REFERENCES smtp(smtp_uuid)
);
ALTER TABLE anvils OWNER TO #!variable!user!#;

CREATE TABLE history.anvils (
	history_id		bigserial,
	anvil_uuid		uuid,
	anvil_owner_uuid	uuid,
	anvil_smtp_uuid		uuid,
	anvil_name		text,
	anvil_description	text,
	anvil_note		text,
	anvil_password		text,
	modified_date		timestamp with time zone	not null 
);
ALTER TABLE history.anvils OWNER TO #!variable!user!#;

CREATE FUNCTION history_anvils() RETURNS trigger
AS $$
DECLARE
	history_anvils RECORD;
BEGIN
	SELECT INTO history_anvils * FROM anvils WHERE anvil_uuid = new.anvil_uuid;
	INSERT INTO history.anvils
		(anvil_uuid, 
		 anvil_owner_uuid, 
		 anvil_smtp_uuid, 
		 anvil_name, 
		 anvil_description, 
		 anvil_note, 
		 anvil_password, 
		 modified_date)
	VALUES
		(history_anvils.anvil_uuid, 
		 history_anvils.anvil_owner_uuid, 
		 history_anvils.anvil_smtp_uuid, 
		 history_anvils.anvil_name, 
		 history_anvils.anvil_description, 
		 history_anvils.anvil_note, 
		 history_anvils.anvil_password, 
		 history_anvils.modified_date);
	RETURN NULL;
END;
$$
LANGUAGE plpgsql;
ALTER FUNCTION history_anvils() OWNER TO #!variable!user!#;

CREATE TRIGGER trigger_anvils
	AFTER INSERT OR UPDATE ON anvils
	FOR EACH ROW EXECUTE PROCEDURE history_anvils();


-- This stores information about Anvil! nodes.
CREATE TABLE nodes (
	node_uuid		uuid				not null	primary key,	-- 
	node_anvil_uuid		uuid				not null,			-- This is the Anvil! that this node belongs to.
	node_host_uuid		uuid				not null,			-- This is the 'hosts' -> 'host_uuid' for this node.
	node_remote_ip		text,								-- if the node's IFN or BCN IPs do not match a Striker dashboard's IFN or BCN, it will be determined to be remote and this hostname/IP (and port) will be used to access it
	node_remote_port	numeric,							-- if the port isn't set, '22' will be used by Striker.
	node_note		text,
	node_bcn		inet,								-- These will be checked against a given dashboard's interfaces and, if one matches, will be used to access it (BCN getting top priotity, then IFN, then remote)
	node_sn			inet,
	node_ifn		inet,
	node_password		text,								-- This should not generally be set (should always use 'anvil_password'.
	modified_date		timestamp with time zone	not null,
	
	FOREIGN KEY(node_anvil_uuid) REFERENCES anvils(anvil_uuid)
);
ALTER TABLE nodes OWNER TO #!variable!user!#;

CREATE TABLE history.nodes (
	history_id		bigserial,
	node_uuid		uuid,
	node_anvil_uuid		uuid,
	node_host_uuid		uuid,
	node_remote_ip		text,
	node_remote_port	numeric,
	node_note		text,
	node_bcn		inet,
	node_sn			inet,
	node_ifn		inet,
	node_password		text,
	modified_date		timestamp with time zone	not null
);
ALTER TABLE history.nodes OWNER TO #!variable!user!#;

CREATE FUNCTION history_nodes() RETURNS trigger
AS $$
DECLARE
	history_nodes RECORD;
BEGIN
	SELECT INTO history_nodes * FROM nodes WHERE node_uuid = new.node_uuid;
	INSERT INTO history.nodes
		(node_uuid, 
		 node_anvil_uuid, 
		 node_host_uuid, 
		 node_remote_ip, 
		 node_remote_port, 
		 node_note, 
		 node_bcn, 
		 node_sn, 
		 node_ifn, 
		 node_password, 
		 modified_date)
	VALUES
		(history_nodes.node_uuid, 
		 history_nodes.node_anvil_uuid, 
		 history_nodes.node_host_uuid, 
		 history_nodes.node_remote_ip, 
		 history_nodes.node_remote_port, 
		 history_nodes.node_note, 
		 history_nodes.node_bcn, 
		 history_nodes.node_sn, 
		 history_nodes.node_ifn, 
		 history_nodes.node_password, 
		 history_nodes.modified_date);
	RETURN NULL;
END;
$$
LANGUAGE plpgsql;
ALTER FUNCTION history_nodes() OWNER TO #!variable!user!#;

CREATE TRIGGER trigger_nodes
	AFTER INSERT OR UPDATE ON nodes
	FOR EACH ROW EXECUTE PROCEDURE history_nodes();


-- This holds user-configurable variable that alter how Striker and ScanCore works. These values override defaults but NOT striker.conf.
CREATE TABLE variables (
	variable_uuid			uuid				not null	primary key,	-- 
	variable_name			text				not null,			-- This is the 'x::y::z' style variable name.
	variable_value			text,								-- It is up to the software to sanity check variable values before they are stored
	variable_default		text,								-- This acts as a reference for the user should they want to roll-back changes.
	variable_description		text,								-- This is a string key that describes this variable's use.
	variable_section		text,								-- This is a free-form field that is used when displaying the various entries to a user. This allows for the various variables to be grouped into sections.
	variable_source_uuid		text,								-- Optional; Marks the variable as belonging to a specific X_uuid, where 'X' is a table name set in 'variable_source_table'
	variable_source_table		text,								-- Optional; Marks the database table corresponding to the 'variable_source_uuid' value.
	modified_date			timestamp with time zone	not null 
);
ALTER TABLE variables OWNER TO #!variable!user!#;

CREATE TABLE history.variables (
	history_id			bigserial,
	variable_uuid			uuid,
	variable_name			text,
	variable_value			text,
	variable_default		text,
	variable_description		text,
	variable_section		text,
	variable_source_uuid		text,
	variable_source_table		text,
	modified_date			timestamp with time zone	not null 
);
ALTER TABLE history.variables OWNER TO #!variable!user!#;

CREATE FUNCTION history_variables() RETURNS trigger
AS $$
DECLARE
	history_variables RECORD;
BEGIN
	SELECT INTO history_variables * FROM variables WHERE variable_uuid = new.variable_uuid;
	INSERT INTO history.variables
		(variable_uuid,
		 variable_name, 
		 variable_value, 
		 variable_default, 
		 variable_description, 
		 variable_section, 
		 variable_source_uuid, 
		 variable_source_table, 
		 modified_date)
	VALUES
		(history_variables.variable_uuid,
		 history_variables.variable_name, 
		 history_variables.variable_value, 
		 history_variables.variable_default, 
		 history_variables.variable_description, 
		 history_variables.variable_section, 
		 history_variables.variable_source_uuid, 
		 history_variables.variable_source_table, 
		 history_variables.modified_date);
	RETURN NULL;
END;
$$
LANGUAGE plpgsql;
ALTER FUNCTION history_variables() OWNER TO #!variable!user!#;

CREATE TRIGGER trigger_variables
	AFTER INSERT OR UPDATE ON variables
	FOR EACH ROW EXECUTE PROCEDURE history_variables();


-- This stores information on an email alert or file alert notifications
CREATE TABLE notifications (
	notify_uuid		uuid				not null	primary key,		
	notify_name		text				not null,				-- This is the Free-form name of the alart recipient. It is used in the To: field of email notify targets
	notify_target		text				not null,				-- This is the target of the notify; either an email-address to send the notify to or a file name to write to notify to.
	notify_language		text				not null	default 'en_CA',	-- The language to use. Must exist in all .xml language files!
	notify_level		text				not null	default 'warning', 	-- The level of log messages this user wants to receive (stated level plus higher-level); levels are; 'debug', 'info', 'notice', 'warning' and 'critical'.
	notify_units		text				not null	default 'metric', 	-- Can be 'metric' or 'imperial'. All internal values are metric, imperial units are calculated when the email is generated.
	notify_note		text,
	modified_date		timestamp with time zone	not null
);
ALTER TABLE notifications OWNER TO #!variable!user!#;

-- This stores information on an email notify recipient
CREATE TABLE history.notifications (
	history_id		bigserial,
	notify_uuid		uuid,
	notify_name		text,
	notify_target		text,
	notify_language		text,
	notify_level		text,
	notify_units		text,
	notify_note		text,
	modified_date		timestamp with time zone	not null
);
ALTER TABLE history.notifications OWNER TO #!variable!user!#;

CREATE FUNCTION history_notifications() RETURNS trigger
AS $$
DECLARE
	history_notifications RECORD;
BEGIN
	SELECT INTO history_notifications * FROM notifications WHERE notify_uuid = new.notify_uuid;
	INSERT INTO history.notifications
		(notify_uuid,
		 notify_name,
		 notify_target,
		 notify_language,
		 notify_level,
		 notify_units, 
		 notify_note, 
		 modified_date)
	VALUES
		(history_notifications.notify_uuid,
		 history_notifications.notify_name,
		 history_notifications.notify_target,
		 history_notifications.notify_language,
		 history_notifications.notify_level,
		 history_notifications.notify_units, 
		 history_notifications.notify_note, 
		 history_notifications.modified_date);
	RETURN NULL;
END;
$$
LANGUAGE plpgsql;
ALTER FUNCTION history_notifications() OWNER TO #!variable!user!#;

CREATE TRIGGER trigger_notifications
	AFTER INSERT OR UPDATE ON notifications
	FOR EACH ROW EXECUTE PROCEDURE history_notifications();


-- This links notification recipients to Anvil!'s the recipient wants to hear about
CREATE TABLE recipients (
	recipient_uuid			uuid				not null	primary key,	-- 
	recipient_anvil_uuid		uuid				not null,			-- 
	recipient_notify_uuid		uuid,
	recipient_notify_level		text,								-- If this is set, this log level will over-ride the level set in the file or email alert recipient table.
	recipient_note			text, 
	modified_date			timestamp with time zone	not null, 
	
	FOREIGN KEY(recipient_anvil_uuid) REFERENCES anvils(anvil_uuid), 
	FOREIGN KEY(recipient_notify_uuid) REFERENCES notifications(notify_uuid) 
);
ALTER TABLE recipients OWNER TO #!variable!user!#;

CREATE TABLE history.recipients (
	history_id			bigserial,
	recipient_uuid			uuid,
	recipient_anvil_uuid		uuid,
	recipient_notify_uuid		uuid,
	recipient_notify_level		text,
	recipient_note			text, 
	modified_date			timestamp with time zone	not null 
);
ALTER TABLE history.recipients OWNER TO #!variable!user!#;

CREATE FUNCTION history_recipients() RETURNS trigger
AS $$
DECLARE
	history_recipients RECORD;
BEGIN
	SELECT INTO history_recipients * FROM recipients WHERE recipient_uuid = new.recipient_uuid;
	INSERT INTO history.recipients
		(recipient_uuid,
		 recipient_anvil_uuid, 
		 recipient_notify_uuid, 
		 recipient_notify_level, 
		 recipient_note, 
		 modified_date)
	VALUES
		(history_recipients.recipient_uuid,
		 history_recipients.recipient_anvil_uuid, 
		 history_recipients.recipient_notify_uuid, 
		 history_recipients.recipient_notify_level, 
		 history_recipients.recipient_note, 
		 history_recipients.modified_date);
	RETURN NULL;
END;
$$
LANGUAGE plpgsql;
ALTER FUNCTION history_recipients() OWNER TO #!variable!user!#;

CREATE TRIGGER trigger_recipients
	AFTER INSERT OR UPDATE ON recipients
	FOR EACH ROW EXECUTE PROCEDURE history_recipients();


-- This stores install manifests
CREATE TABLE manifests (
	manifest_uuid		uuid				not null	primary key,	-- 
	manifest_data		text				not null,			-- This is the XML body
	manifest_note		text, 
	modified_date		timestamp with time zone	not null 
);
ALTER TABLE manifests OWNER TO #!variable!user!#;

CREATE TABLE history.manifests (
	history_id		bigserial,
	manifest_uuid		uuid,
	manifest_data		text, 
	manifest_note		text, 
	modified_date		timestamp with time zone	not null 
);
ALTER TABLE history.manifests OWNER TO #!variable!user!#;

CREATE FUNCTION history_manifests() RETURNS trigger
AS $$
DECLARE
	history_manifests RECORD;
BEGIN
	SELECT INTO history_manifests * FROM manifests WHERE manifest_uuid = new.manifest_uuid;
	INSERT INTO history.manifests
		(manifest_uuid,
		 manifest_data, 
		 manifest_note, 
		 modified_date)
	VALUES
		(history_manifests.manifest_uuid,
		 history_manifests.manifest_data, 
		 history_manifests.manifest_note, 
		 history_manifests.modified_date);
	RETURN NULL;
END;
$$
LANGUAGE plpgsql;
ALTER FUNCTION history_manifests() OWNER TO #!variable!user!#;

CREATE TRIGGER trigger_manifests
	AFTER INSERT OR UPDATE ON manifests
	FOR EACH ROW EXECUTE PROCEDURE history_manifests();


-- This stores information about the host machine running this instance of
-- ScanCore. All agents will reference this table.
CREATE TABLE hosts (
	host_uuid		uuid				not null	primary key,	-- This is the single most important record in ScanCore. Everything links back to here.
	host_name		text				not null,
	host_type		text				not null,			-- Either 'node' or 'dashboard'.
	host_emergency_stop	boolean				not null	default FALSE,	-- Set to TRUE when ScanCore shuts down the node.
	host_stop_reason	text,								-- Set to 'power' if the UPS shut down and 'temperature' if the temperature went too high or low. Set to 'clean' if the user used Striker to power off the node (this prevents any Striker from booting the nodes back up).
	host_health		text,								-- This stores the current health of the node ('ok', 'warning', 'critical', 'shutdown')
	modified_date		timestamp with time zone	not null
);
ALTER TABLE hosts OWNER TO #!variable!user!#;

CREATE TABLE history.hosts (
	history_id		bigserial,
	host_uuid		uuid				not null,
	host_name		text				not null,
	host_type		text				not null,
	host_emergency_stop	boolean				not null,
	host_stop_reason	text,
	host_health		text,
	modified_date		timestamp with time zone	not null
);
ALTER TABLE history.hosts OWNER TO #!variable!user!#;

CREATE FUNCTION history_hosts() RETURNS trigger
AS $$
DECLARE
	history_hosts RECORD;
BEGIN
	SELECT INTO history_hosts * FROM hosts WHERE host_uuid = new.host_uuid;
	INSERT INTO history.hosts
		(host_uuid,
		 host_name,
		 host_type,
		 host_emergency_stop,
		 host_stop_reason, 
		 host_health, 
		 modified_date)
	VALUES
		(history_hosts.host_uuid,
		 history_hosts.host_name,
		 history_hosts.host_type,
		 history_hosts.host_emergency_stop,
		 history_hosts.host_stop_reason, 
		 history_hosts.host_health, 
		 history_hosts.modified_date);
	RETURN NULL;
END;
$$
LANGUAGE plpgsql;
ALTER FUNCTION history_hosts() OWNER TO #!variable!user!#;

CREATE TRIGGER trigger_hosts
	AFTER INSERT OR UPDATE ON hosts
	FOR EACH ROW EXECUTE PROCEDURE history_hosts();


-- This stores state information, like the whether migrations are happening and so on.
CREATE TABLE states (
	state_uuid		uuid				primary key,
	state_name		text				not null,			-- This is the name of the state (ie: 'migration', etc)
	state_host_uuid		uuid				not null,			-- The UUID of the machine that the state relates to. In migrations, this is the UUID of the target
	state_note		text,								-- This is a free-form note section that the application setting the state can use for extra information (like the name of the server being migrated)
	modified_date		timestamp with time zone	not null,
	
	FOREIGN KEY(state_host_uuid) REFERENCES hosts(host_uuid)
);
ALTER TABLE states OWNER TO #!variable!user!#;

CREATE TABLE history.states (
	history_id		bigserial,
	state_uuid		uuid,
	state_name		text,
	state_host_uuid		uuid,
	state_note		text,
	modified_date		timestamp with time zone	not null
);
ALTER TABLE history.states OWNER TO #!variable!user!#;

CREATE FUNCTION history_states() RETURNS trigger
AS $$
DECLARE
	history_states RECORD;
BEGIN
	SELECT INTO history_states * FROM states WHERE state_uuid = new.state_uuid;
	INSERT INTO history.states
		(state_uuid,
		 state_name, 
		 state_host_uuid, 
		 state_note, 
		 modified_date)
	VALUES
		(history_states.state_uuid,
		 history_states.state_name, 
		 history_states.state_host_uuid, 
		 history_states.state_note, 
		 history_states.modified_date);
	RETURN NULL;
END;
$$
LANGUAGE plpgsql;
ALTER FUNCTION history_states() OWNER TO #!variable!user!#;

CREATE TRIGGER trigger_states
	AFTER INSERT OR UPDATE ON states
	FOR EACH ROW EXECUTE PROCEDURE history_states();


-- TODO: Create a 'node_cache' table here that stores things like power check commands, default network to 
--       use for access, hosts and sshd data and so on. Link it to a host_uuid because some dashboards will
--       record different data, like what network to use to talk to the dashboard.
CREATE TABLE nodes_cache (
	node_cache_uuid		uuid				primary key,
	node_cache_host_uuid	uuid				not null,			-- The UUID of the machine recording this cache. Note that other dashboards may use this if they have no cache of their own.
	node_cache_node_uuid	uuid				not null,			-- The UUID of the node that the cached data applies to.
	node_cache_name		text				not null,			-- This is the name of the cached data. Like 'hosts', 'power_control', 'ssh_config', etc.
	node_cache_data		text,								-- This is a the actual cached data.
	node_cache_note		text,								-- This is a free form note area for this cache entry, likely only to be ever used by Striker itself.
	modified_date		timestamp with time zone	not null,
	
	FOREIGN KEY(node_cache_host_uuid) REFERENCES hosts(host_uuid), 
	FOREIGN KEY(node_cache_node_uuid) REFERENCES nodes(node_uuid)
);
ALTER TABLE nodes_cache OWNER TO #!variable!user!#;

CREATE TABLE history.nodes_cache (
	history_id		bigserial,
	node_cache_uuid		uuid,
	node_cache_host_uuid	uuid,
	node_cache_node_uuid	uuid,
	node_cache_name		text,
	node_cache_data		text,
	node_cache_note		text,
	modified_date		timestamp with time zone	not null
);
ALTER TABLE history.nodes_cache OWNER TO #!variable!user!#;

CREATE FUNCTION history_nodes_cache() RETURNS trigger
AS $$
DECLARE
	history_nodes_cache RECORD;
BEGIN
	SELECT INTO history_nodes_cache * FROM nodes_cache WHERE node_cache_uuid = new.node_cache_uuid;
	INSERT INTO history.nodes_cache
		(node_cache_uuid,
		 node_cache_host_uuid, 
		 node_cache_node_uuid, 
		 node_cache_name, 
		 node_cache_data, 
		 node_cache_note, 
		 modified_date)
	VALUES
		(history_nodes_cache.node_cache_uuid,
		 history_nodes_cache.node_cache_host_uuid, 
		 history_nodes_cache.node_cache_node_uuid, 
		 history_nodes_cache.node_cache_name, 
		 history_nodes_cache.node_cache_data, 
		 history_nodes_cache.node_cache_note, 
		 history_nodes_cache.modified_date);
	RETURN NULL;
END;
$$
LANGUAGE plpgsql;
ALTER FUNCTION history_nodes_cache() OWNER TO #!variable!user!#;

CREATE TRIGGER trigger_nodes_cache
	AFTER INSERT OR UPDATE ON nodes_cache
	FOR EACH ROW EXECUTE PROCEDURE history_nodes_cache();



-- This stores alerts coming in from various agents
CREATE TABLE alerts (
	alert_uuid		uuid				primary key,
	alert_host_uuid		uuid				not null,			-- The name of the node or dashboard that this alert came from.
	alert_agent_name	text				not null,
	alert_level		text				not null,			-- debug (log only), info (+ admin email), notice (+ curious users), warning (+ client technical staff), critical (+ all)
	alert_title_key		text,								-- ScanCore will read in the agents <name>.xml words file and look for this message key
	alert_title_variables	text,								-- List of variables to substitute into the message key. Format is 'var1=val1 #!# var2 #!# val2 #!# ... #!# varN=valN'.
	alert_message_key	text,								-- ScanCore will read in the agents <name>.xml words file and look for this message key
	alert_message_variables	text,								-- List of variables to substitute into the message key. Format is 'var1=val1 #!# var2 #!# val2 #!# ... #!# varN=valN'.
	alert_sort		text,								-- The alerts will sort on this column. It allows for an optional sorting of the messages in the alert.
	alert_header		boolean						default TRUE,	-- This can be set to have the alert be printed with only the contents of the string, no headers.
	modified_date		timestamp with time zone	not null,
	
	FOREIGN KEY(alert_host_uuid) REFERENCES hosts(host_uuid)
);
ALTER TABLE alerts OWNER TO #!variable!user!#;

CREATE TABLE history.alerts (
	history_id		bigserial,
	alert_uuid		uuid				not null,
	alert_host_uuid		uuid				not null,
	alert_agent_name	text				not null,
	alert_level		text				not null,
	alert_title_key		text,
	alert_title_variables	text,
	alert_message_key	text,
	alert_message_variables	text,
	alert_sort		text,
	alert_header		boolean,
	modified_date		timestamp with time zone	not null
);
ALTER TABLE history.alerts OWNER TO #!variable!user!#;

CREATE FUNCTION history_alerts() RETURNS trigger
AS $$
DECLARE
	history_alerts RECORD;
BEGIN
	SELECT INTO history_alerts * FROM alerts WHERE alert_uuid = new.alert_uuid;
	INSERT INTO history.alerts
		(alert_uuid,
		 alert_host_uuid,
		 alert_agent_name,
		 alert_level,
		 alert_title_key,
		 alert_title_variables,
		 alert_message_key,
		 alert_message_variables,
		 alert_sort, 
		 alert_header, 
		 modified_date)
	VALUES
		(history_alerts.alert_uuid,
		 history_alerts.alert_host_uuid,
		 history_alerts.alert_agent_name,
		 history_alerts.alert_level,
		 history_alerts.alert_title_key,
		 history_alerts.alert_title_variables,
		 history_alerts.alert_message_key,
		 history_alerts.alert_message_variables,
		 history_alerts.alert_sort, 
		 history_alerts.alert_header, 
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
	power_uuid		uuid				primary key,
	power_host_uuid		uuid				not null,			-- The name of the node or dashboard that this power came from.
	power_agent_name	text				not null,
	power_record_locator	text,								-- Optional string used by the agent to identify the UPS
	power_ups_name		text				not null,			-- This is the full domain name of the UPS. This is used by ScanCore to determine which UPSes are powering a given node so this MUST match the host names used in the node's /etc/hosts file.
	power_on_battery	boolean				not null,			-- TRUE == use "time_remaining" to determine if graceful power off is needed. FALSE == power loss NOT imminent, do not power off node. 
	power_seconds_left	numeric,								-- Should always be set, but not required *EXCEPT* when 'power_on_battery' is TRUE.
	power_charge_percentage	numeric,						-- Percentage charge in the UPS. Used to determine when the dashboard should boot the node after AC restore
	modified_date		timestamp with time zone	not null,
	
	FOREIGN KEY(power_host_uuid) REFERENCES hosts(host_uuid)
);
ALTER TABLE power OWNER TO #!variable!user!#;

CREATE TABLE history.power (
	history_id		bigserial,
	power_uuid		uuid				not null,
	power_host_uuid		uuid				not null,
	power_agent_name	text				not null,
	power_record_locator	text,
	power_ups_name		text				not null,
	power_on_battery	boolean				not null,
	power_seconds_left	numeric,
	power_charge_percentage	numeric,
	modified_date		timestamp with time zone	not null
);
ALTER TABLE history.power OWNER TO #!variable!user!#;

CREATE FUNCTION history_power() RETURNS trigger
AS $$
DECLARE
	history_power RECORD;
BEGIN
	SELECT INTO history_power * FROM power WHERE power_uuid = new.power_uuid;
	INSERT INTO history.power
		(power_uuid,
		 power_host_uuid,
		 power_agent_name,
		 power_record_locator,
		 power_ups_name, 
		 power_on_battery,
		 power_seconds_left,
		 power_charge_percentage,
		 modified_date)
	VALUES
		(history_power.power_uuid,
		 history_power.power_host_uuid,
		 history_power.power_agent_name,
		 history_power.power_record_locator,
		 history_power.power_ups_name, 
		 history_power.power_on_battery,
		 history_power.power_seconds_left,
		 history_power.power_charge_percentage,
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
	temperature_uuid	uuid				primary key,
	temperature_host_uuid	uuid				not null,			-- The name of the node or dashboard that this temperature came from.
	temperature_agent_name	text				not null,
	temperature_sensor_host	text				not null,
	temperature_sensor_name	text				not null,
	temperature_celsius	numeric				not null,
	temperature_state	text				not null,			-- ok, warning, critical
	temperature_is		text				not null,			-- nominal, high or low
	modified_date		timestamp with time zone	not null,
	
	FOREIGN KEY(temperature_host_uuid) REFERENCES hosts(host_uuid)
);
ALTER TABLE temperature OWNER TO #!variable!user!#;

CREATE TABLE history.temperature (
	history_id		bigserial,
	temperature_uuid	uuid				not null,
	temperature_host_uuid	uuid				not null,
	temperature_agent_name	text				not null,
	temperature_sensor_host	text				not null,
	temperature_sensor_name	text				not null,
	temperature_celsius	numeric				not null,
	temperature_state	text				not null,
	temperature_is		text				not null,
	modified_date		timestamp with time zone	not null
);
ALTER TABLE history.temperature OWNER TO #!variable!user!#;

CREATE FUNCTION history_temperature() RETURNS trigger
AS $$
DECLARE
	history_temperature RECORD;
BEGIN
	SELECT INTO history_temperature * FROM temperature WHERE temperature_uuid = new.temperature_uuid;
	INSERT INTO history.temperature
		(temperature_uuid,
		 temperature_host_uuid,
		 temperature_agent_name,
		 temperature_sensor_host, 
		 temperature_sensor_name,
		 temperature_celsius,
		 temperature_state,
		 temperature_is,
		 modified_date)
	VALUES
		(history_temperature.temperature_uuid,
		 history_temperature.temperature_host_uuid,
		 history_temperature.temperature_agent_name,
		 history_temperature.temperature_sensor_host, 
		 history_temperature.temperature_sensor_name,
		 history_temperature.temperature_celsius,
		 history_temperature.temperature_state,
		 history_temperature.temperature_is,
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
	agent_uuid		uuid				primary key,
	agent_host_uuid		uuid				not null,
	agent_name		text				not null,			-- This is the name of the scan agent file name
	agent_exit_code		int				not null,			-- This is the exit code from the last run
	agent_runtime		int				not null,			-- This is the number of seconds it took for the agent to run last time.
	modified_date		timestamp with time zone	not null,
	
	FOREIGN KEY(agent_host_uuid) REFERENCES hosts(host_uuid)
);
ALTER TABLE agents OWNER TO #!variable!user!#;

CREATE TABLE history.agents (
	history_id		bigserial,
	agent_uuid		uuid				not null,
	agent_host_uuid		uuid				not null,
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
	SELECT INTO history_agents * FROM agents WHERE agent_uuid = new.agent_uuid;
	INSERT INTO history.agents
		(agent_uuid,
		 agent_host_uuid,
		 agent_name,
		 agent_exit_code,
		 agent_runtime,
		 modified_date)
	VALUES
		(history_agents.agent_uuid,
		 history_agents.agent_host_uuid,
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


-- ------------------------------------------------------------------------------------------------------- --
-- NOTE: This table is unique in that it does NOT link to a specific host_uuid!                            --
-- ------------------------------------------------------------------------------------------------------- --

-- This stores information that belongs to shared objects, like a server's XML data or the user's notes. 
-- Anything here can be updated by any ScanCore system.
CREATE TABLE public.shared (
	shared_uuid		uuid				primary key,
	shared_source_name	text				not null,	-- This is the name of the agent that created this shared object
	shared_record_locator	uuid				not null,	-- This is the UUID of the object this record belongs to. Usually it will be '<table>_uuid'
	shared_name		text				not null,	-- This is the name of the object (like 'definition', 'note', etc.
	shared_data		text,						-- This is the stored value, which can be empty.
	modified_date		timestamp with time zone	not null
);
ALTER TABLE public.shared OWNER TO #!variable!user!#;

CREATE TABLE history.shared (
	history_id		bigserial,
	shared_uuid		uuid,
	shared_source_name	text,
	shared_record_locator	uuid,
	shared_name		text,
	shared_data		text,
	modified_date		timestamp with time zone
);
ALTER TABLE history.shared OWNER TO #!variable!user!#;

CREATE FUNCTION history_shared() RETURNS trigger
AS $$
DECLARE
	history_shared RECORD;
BEGIN
	SELECT INTO history_shared * FROM shared WHERE shared_uuid = new.shared_uuid;
	INSERT INTO history.shared
		(shared_uuid, 
		 shared_source_name, 
		 shared_record_locator, 
		 shared_name, 
		 shared_data,
		 modified_date)
	VALUES
		(history_shared.shared_uuid, 
		 history_shared.shared_source_name, 
		 history_shared.shared_record_locator, 
		 history_shared.shared_name, 
		 history_shared.shared_data,
		 history_shared.modified_date);
	RETURN NULL;
END;
$$
LANGUAGE plpgsql;
ALTER FUNCTION history_shared() OWNER TO #!variable!user!#;

CREATE TRIGGER trigger_shared
	AFTER INSERT OR UPDATE ON shared
	FOR EACH ROW EXECUTE PROCEDURE history_shared();


-- ------------------------------------------------------------------------------------------------------- --
-- NOTE: This table does NOT link to a specific host_uuid!                                                 --
-- ------------------------------------------------------------------------------------------------------- --

-- This stores information about the server.
CREATE TABLE servers (
	server_uuid			uuid				not null	primary key,	-- This comes from the server's XML definition file.
	server_name			text				not null,
	server_stop_reason		text,								-- Set by Striker to 'clean' when stopped via the webui. This prevents anvil-safe-start from starting it on node boot.
	server_start_after		uuid,								-- This can be the UUID of another server. If set, this server will boot 'server_start_delay' seconds after the referenced server boots. A value of '00000000-0000-0000-0000-000000000000' will tell 'anvil-safe-start' to not boot the server at all.
	server_start_delay		integer				not null	default 0,	-- How many seconds to delay booting for after the last server in the previous group boots.
	server_note			text,								-- User's place to keep notes about their server.
	server_definition		text				not null,			-- The XML definition file for the server.
	server_host			text,								-- This is the current host for this server, which may be empty if it's off.
	server_state			text,								-- This is the current state of this server.
	server_migration_type		text				not null	default 'live',	-- This is either 'live' or 'cold'. Cold migration involves "shut down" -> "Boot" on the peer.
	server_pre_migration_script	text,								-- This is set to the name of a script to run before migrating a server. This must match an entry in /shared/files/.
	server_pre_migration_arguments	text,								-- These are arguments to pass to the pre-migration script
	server_post_migration_script	text,								-- This is set to the name of a script to run after migrating a server. This must match an entry in /shared/files/.
	server_post_migration_arguments	text,								-- These are arguments to pass to the post-migration script
	modified_date			timestamp with time zone	not null
);
ALTER TABLE servers OWNER TO #!variable!user!#;

CREATE TABLE history.servers (
	history_id			bigserial,
	server_uuid			uuid,
	server_name			text,
	server_stop_reason		text,
	server_start_after		uuid,
	server_start_delay		integer,
	server_note			text,
	server_definition		text,
	server_host			text,
	server_state			text,
	server_migration_type		text,
	server_pre_migration_script	text,
	server_pre_migration_arguments	text,
	server_post_migration_script	text,
	server_post_migration_arguments	text,
	modified_date			timestamp with time zone	not null
);
ALTER TABLE history.servers OWNER TO #!variable!user!#;

CREATE FUNCTION history_servers() RETURNS trigger
AS $$
DECLARE
	history_servers RECORD;
BEGIN
	SELECT INTO history_servers * FROM servers WHERE server_uuid = new.server_uuid;
	INSERT INTO history.servers
		(server_uuid,
		 server_name, 
		 server_stop_reason, 
		 server_start_after, 
		 server_start_delay, 
		 server_note, 
		 server_definition, 
		 server_host, 
		 server_state, 
		 server_migration_type, 
		 server_pre_migration_script, 
		 server_pre_migration_arguments, 
		 server_post_migration_script, 
		 server_post_migration_arguments, 
		 modified_date)
	VALUES
		(history_servers.server_uuid, 
		 history_servers.server_name, 
		 history_servers.server_stop_reason, 
		 history_servers.server_start_after, 
		 history_servers.server_start_delay, 
		 history_servers.server_note, 
		 history_servers.server_definition, 
		 history_servers.server_host, 
		 history_servers.server_state, 
		 history_servers.server_migration_type, 
		 history_servers.server_pre_migration_script, 
		 history_servers.server_pre_migration_arguments, 
		 history_servers.server_post_migration_script, 
		 history_servers.server_post_migration_arguments, 
		 history_servers.modified_date);
	RETURN NULL;
END;
$$
LANGUAGE plpgsql;
ALTER FUNCTION history_servers() OWNER TO #!variable!user!#;

CREATE TRIGGER trigger_servers
	AFTER INSERT OR UPDATE ON servers
	FOR EACH ROW EXECUTE PROCEDURE history_servers();


-- This stores information about dr targets. These can be local (USB/LV) or remote (SSH targets).
CREATE TABLE dr_targets (
	dr_target_uuid			uuid				not null	primary key,	-- 
	dr_target_name			text				not null,			-- A human-friendly target name
	dr_target_note			text,								-- An optional notes section
	dr_target_ip_or_name		text				not null,			-- This is the IP or (resolvable) host name of the target machine.
	dr_target_password		text,								-- This is the target's root user's password. It can be left blank if passwordless SSH has been configured on both nodes.
	dr_target_tcp_port		numeric,							-- This is the target's SSH TCP port to use. 22 will be used if this is not set.
	dr_target_use_cache		boolean				not null	default TRUE,	-- If true, a dr will first look for a USB drive plugged into either node with enough space to store the image. if that is not found, but there is enough space on the cluster storage, a temporary LV will be created and used. Otherwise, the dr will directly dd over SSH to the target.
	dr_target_store			text				not null,			-- This indicates where images should be stored on the target machine. Format is: <device_type>:<name>. Examples; 'vg:dr01_vg0' (Create an LV on the 'dr01_vg0' VG), 'fs:/drs' (store as a flat file under the /drs directory).
	dr_target_copies		numeric				not null,			-- When set to '1', no images are kept and the copy overwrites any previous copy. This is the most space efficient, but leaves the dr target vulnerable during a dr operation because the last good copy is ruined. So a disaster during a dr would leave no functional drs. 2 or higher will cause a .X suffix to be used on flat files and _X on LVs. The oldest dr will be purged, then all remaining drs will be renamed to increment their number, and then the dr will write to '.0' or '_0'. This requires (a lot) more space, but it is the safest. Default is 2, which should always leave one good image available.
	dr_target_bandwidth_limit	text,								-- This is an optional bandwidth limit to restrict how fast the copy over SSH runs. Default, when no set, is full speed.
	modified_date			timestamp with time zone	not null 
);
ALTER TABLE dr_targets OWNER TO #!variable!user!#;

CREATE TABLE history.dr_targets (
	history_id			bigserial, 
	dr_target_uuid			uuid, 
	dr_target_name			text, 
	dr_target_note			text, 
	dr_target_ip_or_name		text, 
	dr_target_password		text, 
	dr_target_tcp_port		numeric, 
	dr_target_use_cache		boolean, 
	dr_target_store			text, 
	dr_target_copies		numeric, 
	dr_target_bandwidth_limit	text, 
	modified_date			timestamp with time zone	not null 
);
ALTER TABLE history.dr_targets OWNER TO #!variable!user!#;

CREATE FUNCTION history_dr_targets() RETURNS trigger
AS $$
DECLARE
	history_dr_targets RECORD;
BEGIN
	SELECT INTO history_dr_targets * FROM dr_targets WHERE dr_target_uuid = new.dr_target_uuid;
	INSERT INTO history.dr_targets
		(dr_target_uuid, 
		 dr_target_name, 
		 dr_target_note, 
		 dr_target_ip_or_name, 
		 dr_target_password, 
		 dr_target_tcp_port, 
		 dr_target_use_cache, 
		 dr_target_store, 
		 dr_target_copies, 
		 dr_target_bandwidth_limit, 
		 modified_date)
	VALUES
		(history_dr_targets.dr_target_uuid,
		 history_dr_targets.dr_target_name, 
		 history_dr_targets.dr_target_note, 
		 history_dr_targets.dr_target_ip_or_name, 
		 history_dr_targets.dr_target_password, 
		 history_dr_targets.dr_target_tcp_port, 
		 history_dr_targets.dr_target_use_cache, 
		 history_dr_targets.dr_target_store, 
		 history_dr_targets.dr_target_copies, 
		 history_dr_targets.dr_target_bandwidth_limit, 
		 history_dr_targets.modified_date);
	RETURN NULL;
END;
$$
LANGUAGE plpgsql;
ALTER FUNCTION history_dr_targets() OWNER TO #!variable!user!#;

CREATE TRIGGER trigger_dr_targets
	AFTER INSERT OR UPDATE ON dr_targets
	FOR EACH ROW EXECUTE PROCEDURE history_dr_targets();


-- This stores information about dr jobs. This contains a run frequency, a (list of) server(s) to dr
-- (together), what target to use and how often to run.
CREATE TABLE dr_jobs (
	dr_job_uuid			uuid				not null	primary key,	-- 
	dr_job_dr_target_uuid		uuid				not null,			-- This is the target to use for this dr job.
	dr_job_name			text				not null,			-- A human-friendly job name
	dr_job_note			text,								-- An optional notes section
	dr_job_servers			text				not null,			-- One or more server UUIDs to back up. If more than one, the UUIDs must be CSV. When two or more servers are defined, all will be shut down at the same time and none will boot until all are backed up. 
	dr_job_auto_prune		boolean				not null	default TRUE,	-- When set to true, if a server is found to be missing (because it was deleted), it will automatically be removed from the server list. If set to false, and a server is missing, the dr will not occur (and an alert will be sent).
	dr_job_schedule			text				not null,			-- This is the schedule for the drs to run. It is stored internally using 'cron' timing format (.
	modified_date			timestamp with time zone	not null, 
	
	FOREIGN KEY(dr_job_dr_target_uuid) REFERENCES dr_targets(dr_target_uuid)
);
ALTER TABLE dr_jobs OWNER TO #!variable!user!#;

CREATE TABLE history.dr_jobs (
	history_id			bigserial, 
	dr_job_uuid			uuid, 
	dr_job_dr_target_uuid		uuid, 
	dr_job_name			text, 
	dr_job_note			text, 
	dr_job_servers			text, 
	dr_job_auto_prune		boolean, 
	dr_job_schedule			text, 
	modified_date			timestamp with time zone	not null 
);
ALTER TABLE history.dr_jobs OWNER TO #!variable!user!#;

CREATE FUNCTION history_dr_jobs() RETURNS trigger
AS $$
DECLARE
	history_dr_jobs RECORD;
BEGIN
	SELECT INTO history_dr_jobs * FROM dr_jobs WHERE dr_job_uuid = new.dr_job_uuid;
	INSERT INTO history.dr_jobs
		(dr_job_uuid, 
		 dr_job_dr_target_uuid, 
		 dr_job_name, 
		 dr_job_note, 
		 dr_job_servers, 
		 dr_job_auto_prune, 
		 dr_job_schedule, 
		 modified_date)
	VALUES
		(history_dr_jobs.dr_job_uuid,
		 history_dr_jobs.dr_job_dr_target_uuid, 
		 history_dr_jobs.dr_job_name, 
		 history_dr_jobs.dr_job_note, 
		 history_dr_jobs.dr_job_servers, 
		 history_dr_jobs.dr_job_auto_prune, 
		 history_dr_jobs.dr_job_schedule, 
		 history_dr_jobs.modified_date);
	RETURN NULL;
END;
$$
LANGUAGE plpgsql;
ALTER FUNCTION history_dr_jobs() OWNER TO #!variable!user!#;

CREATE TRIGGER trigger_dr_jobs
	AFTER INSERT OR UPDATE ON dr_jobs
	FOR EACH ROW EXECUTE PROCEDURE history_dr_jobs();


-- ------------------------------------------------------------------------------------------------------- --
-- NOTE: Because this will be updated on every run, we will use its modified_data comlumn to determine if  --
--       the tables in this schema need to be updated.                                                     --
-- ------------------------------------------------------------------------------------------------------- --

-- This stores information about the RAM used by ScanCore and it's agents.
CREATE TABLE ram_used (
	ram_used_uuid		bigserial,
	ram_used_host_uuid	uuid				not null,
	ram_used_by		text				not null,			-- Either 'ScanCore' or the scan agent name
	ram_used_bytes		numeric				not null,
	modified_date		timestamp with time zone	not null,
	
	FOREIGN KEY(ram_used_host_uuid) REFERENCES hosts(host_uuid)
);
ALTER TABLE ram_used OWNER TO #!variable!user!#;

CREATE TABLE history.ram_used (
	history_id		bigserial,
	ram_used_uuid		bigint				not null,
	ram_used_host_uuid	uuid				not null,
	ram_used_by		text				not null,			-- Either 'ScanCore' or the scan agent name
	ram_used_bytes		numeric				not null,
	modified_date		timestamp with time zone	not null
);
ALTER TABLE history.ram_used OWNER TO #!variable!user!#;

CREATE FUNCTION history_ram_used() RETURNS trigger
AS $$
DECLARE
	history_ram_used RECORD;
BEGIN
	SELECT INTO history_ram_used * FROM ram_used WHERE ram_used_uuid = new.ram_used_uuid;
	INSERT INTO history.ram_used
		(ram_used_uuid,
		 ram_used_host_uuid,
		 ram_used_by,
		 ram_used_bytes,
		 modified_date)
	VALUES
		(history_ram_used.ram_used_uuid,
		 history_ram_used.ram_used_host_uuid,
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


-- ------------------------------------------------------------------------------------------------------- --
-- These are special tables with no history or tracking UUIDs that simply record transient information.    --
-- ------------------------------------------------------------------------------------------------------- --

-- This table records the last time a scan ran.
CREATE TABLE updated (
	updated_host_uuid	uuid				not null,
	updated_by		text				not null,			-- The name of the agent (or "ScanCore' itself) that updated.
	modified_date		timestamp with time zone	not null,
	
	FOREIGN KEY(updated_host_uuid) REFERENCES hosts(host_uuid)
);
ALTER TABLE updated OWNER TO #!variable!user!#;


-- To avoid "waffling" when a sensor is close to an alert (or cleared) threshold, a gap between the alarm 
-- value and the clear value is used. If the sensor climbs above (or below) the "clear" value, but didn't 
-- previously pass the "alert" threshold, we DON'T want to send an "all clear" message. So do solve that, 
-- this table is used by agents to record when a warning message was sent. 
CREATE TABLE alert_sent (
	alert_sent_host_uuid	uuid				not null,			-- The node associated with this alert
	alert_sent_by		text				not null,			-- name of the agent
	alert_record_locator	text,								-- Optional string used by the agent to identify the source of the alert (ie: UPS serial number)
	alert_name		text				not null,			-- A free-form name used by the caller to identify this alert.
	modified_date		timestamp with time zone	not null,
	
	FOREIGN KEY(alert_sent_host_uuid) REFERENCES hosts(host_uuid)
);
ALTER TABLE updated OWNER TO #!variable!user!#;
