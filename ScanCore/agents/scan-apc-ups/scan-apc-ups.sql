-- This is the database schema for the 'APC UPS Scan Agent'.

CREATE TABLE apc_ups (
	apc_ups_id	serial				primary key,
	apc_ups_host_id	serial,
	apc_ups_fqdn	text,
	apc_ups_ip	text,								-- Might want to make this inet or cidr later.
	apc_ups_status	text,
	modified_user	integer				not null	default 1,
	modified_date	timestamp with time zone	not null	default now(),
	
	FOREIGN KEY(apc_ups_host_id) REFERENCES hosts(host_id)
);
ALTER TABLE apc_ups OWNER TO #!variable!user!#;

CREATE TABLE history.apc_ups (
	apc_ups_id	serial,
	history_id	serial,
	apc_ups_fqdn	text,
	apc_ups_bcn_ip	text,								-- Might want to make this inet or cidr later.
	apc_ups_ifn_ip	text,								-- Might want to make this inet or cidr later.
	apc_ups_status	text,
	modified_user	int				not null	default 1,
	modified_date	timestamp with time zone	not null	default now()
);
ALTER TABLE history.apc_ups OWNER TO #!variable!user!#;

CREATE FUNCTION history_apc_ups() RETURNS trigger
AS $$
DECLARE
	history_apc_ups RECORD;
BEGIN
	SELECT INTO history_apc_ups * FROM apc_ups WHERE apc_ups_id=new.apc_ups_id;
	INSERT INTO history.apc_ups
		(apc_ups_id,
		apc_ups_fqdn,
		apc_ups_bcn_ip,
		apc_ups_ifn_ip,
		apc_ups_status,
		modified_user,
		modified_date)
	VALUES
		(history_apc_ups.apc_ups_id,
		history_apc_ups.apc_ups_fqdn,
		history_apc_ups.apc_ups_bcn_ip,
		history_apc_ups.apc_ups_ifn_ip,
		history_apc_ups.apc_ups_status,
		history_apc_ups.modified_user,
		history_apc_ups.modified_user);
	RETURN NULL;
END;
$$
LANGUAGE plpgsql;
ALTER FUNCTION history_apc_ups() OWNER TO #!variable!user!#;

CREATE TRIGGER trigger_apc_ups
	AFTER INSERT OR UPDATE ON apc_ups
	FOR EACH ROW EXECUTE PROCEDURE history_apc_ups();
