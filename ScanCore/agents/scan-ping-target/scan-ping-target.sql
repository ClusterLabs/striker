-- This is the database schema for the 'remote-access Scan Agent'.

CREATE TABLE ping_targets (
	ping_target_uuid			uuid				primary key,
	ping_target_host_uuid			uuid				not null,
	ping_target_target_name			text				not null,	-- The hostname or IP address we pinged
	ping_target_target_pinged		text				not null,
	ping_target_ping_time			text,
	modified_date				timestamp with time zone	not null,
	
	FOREIGN KEY(ping_target_host_uuid) REFERENCES hosts(host_uuid)
);
ALTER TABLE ping_targets OWNER TO #!variable!user!#;

CREATE TABLE history.ping_targets (
	history_id				bigserial,
	ping_target_uuid			uuid,
	ping_target_host_uuid			uuid,
	ping_target_target_name			text,
	ping_target_target_pinged		text,
	ping_target_ping_time			text,
	modified_date				timestamp with time zone	not null
);
ALTER TABLE history.ping_targets OWNER TO #!variable!user!#;

CREATE FUNCTION history_ping_targets() RETURNS trigger
AS $$
DECLARE
	history_ping_targets RECORD;
BEGIN
	SELECT INTO history_ping_targets * FROM ping_targets WHERE ping_target_uuid=new.ping_target_uuid;
	INSERT INTO history.ping_targets
		(ping_target_uuid,
		 ping_target_host_uuid, 
		 ping_target_target_name, 
		 ping_target_target_pinged, 
		 ping_target_ping_time, 
		 modified_date)
	VALUES
		(history_ping_targets.ping_target_uuid,
		 history_ping_targets.ping_target_host_uuid, 
		 history_ping_targets.ping_target_target_name, 
		 history_ping_targets.ping_target_target_pinged, 
		 history_ping_targets.ping_target_ping_time, 
		 history_ping_targets.modified_date);
	RETURN NULL;
END;
$$
LANGUAGE plpgsql;
ALTER FUNCTION history_ping_targets() OWNER TO #!variable!user!#;

CREATE TRIGGER trigger_ping_targets
	AFTER INSERT OR UPDATE ON ping_targets
	FOR EACH ROW EXECUTE PROCEDURE history_ping_targets();
