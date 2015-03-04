\echo Create enum data type for the mode and level fields.
CREATE TYPE mode  AS ENUM ( 'NONE', 'Screen', 'Email', 'HealthMonitor' );
CREATE TYPE level AS ENUM ( 'NONE', 'DEBUG', 'WARNING', 'CRISIS' );


\echo Create table alert_listeners

CREATE TABLE alert_listeners (
id		serial	primary key ,
name		text    not null,
mode            mode,
level           level,
contact_info	text    not null,
language        text,
added_by        int     not null,
updated         timestamp with time zone	not null	default now()
);

ALTER TABLE alert_listeners OWNER TO striker;

\echo Create table history.alert_listeners

CREATE TABLE history.alert_listeners (
history_id	serial primary key,
id		bigint,
name		text,
mode            mode,
level           level,
contact_info	text,
language        text,
added_by        int,
updated         timestamp with time zone        not null default now()
);

ALTER TABLE history.alert_listeners OWNER TO striker;

\echo Create function history_nodes to populate history.alert_listeners from alert_listeners

CREATE FUNCTION history_alert_listeners() RETURNS trigger
AS $$
DECLARE
	tmp RECORD;
BEGIN
	SELECT INTO tmp *
	FROM        alert_listeners
	WHERE       id = new.id;

	INSERT INTO history.alert_listeners
		(id,
		 name,
		 mode,
		 level,
                 language,
		 contact_info,
		 added_by
		 )	
	VALUES
		(tmp.id,
		 tmp.name,
		 tmp.mode,
                 tmp.level,
                 tmp.language,
		 tmp.contact_info,
		 tmp.added_by
		 );
	RETURN NULL;
END;
$$
LANGUAGE plpgsql;

ALTER FUNCTION history_alert_listeners() OWNER TO striker;

\echo Create trigger trigger_alert_listeners using function history_alert_listeners

--CREATE TRIGGER trigger_alert_listeners 
--AFTER INSERT OR UPDATE ON alert_listeners 
--FOR EACH ROW EXECUTE PROCEDURE history_alert_listeners();


\echo All done!

-- ----------------------------------------------------------------------
-- end of file
