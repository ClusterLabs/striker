-- This is the database schema for the 'remote_access Scan Agent'.

CREATE TABLE remote_access (
	remote_access_uuid			uuid				primary key,
	remote_access_host_uuid			uuid				not null,
	remote_access_target_name		text				not null,	-- The hostname or IP address we logged into (in 'user@target:port' format)
	remote_access_target_access		text				not null,
	modified_date				timestamp with time zone	not null,
	
	FOREIGN KEY(remote_access_host_uuid) REFERENCES hosts(host_uuid)
);
ALTER TABLE remote_access OWNER TO #!variable!user!#;

CREATE TABLE history.remote_access (
	history_id				bigserial,
	remote_access_uuid			uuid,
	remote_access_host_uuid			uuid,
	remote_access_target_name		text,
	remote_access_target_access		text,
	modified_date				timestamp with time zone	not null
);
ALTER TABLE history.remote_access OWNER TO #!variable!user!#;

CREATE FUNCTION history_remote_access() RETURNS trigger
AS $$
DECLARE
	history_remote_access RECORD;
BEGIN
	SELECT INTO history_remote_access * FROM remote_access WHERE remote_access_uuid=new.remote_access_uuid;
	INSERT INTO history.remote_access
		(remote_access_uuid,
		 remote_access_host_uuid, 
		 remote_access_target_name, 
		 remote_access_target_access, 
		 modified_date)
	VALUES
		(history_remote_access.remote_access_uuid,
		 history_remote_access.remote_access_host_uuid, 
		 history_remote_access.remote_access_target_name, 
		 history_remote_access.remote_access_target_access, 
		 history_remote_access.modified_date);
	RETURN NULL;
END;
$$
LANGUAGE plpgsql;
ALTER FUNCTION history_remote_access() OWNER TO #!variable!user!#;

CREATE TRIGGER trigger_remote_access
	AFTER INSERT OR UPDATE ON remote_access
	FOR EACH ROW EXECUTE PROCEDURE history_remote_access();
