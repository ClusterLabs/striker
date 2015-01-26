--
-- PostgreSQL database dump
--

SET statement_timeout = 0;
--SET lock_timeout = 0;
SET client_encoding = 'UTF8';
SET standard_conforming_strings = on;
SET check_function_bodies = false;
SET client_min_messages = warning;

SET search_path = public, pg_catalog;

SET default_tablespace = '';

SET default_with_oids = false;

--
-- Name: alerts; Type: TABLE; Schema: public; Owner: alteeve; Tablespace: 
--

CREATE TABLE alerts (
    id integer NOT NULL,
    node_id bigint,
    target_name text,
    target_type text,
    target_extra text,
    field text,
    value text,
    units text,
    status status,
    message_tag text,
    message_arguments text,
    "timestamp" timestamp with time zone DEFAULT now() NOT NULL
);


ALTER TABLE public.alerts OWNER TO alteeve;

--
-- Name: alerts_id_seq; Type: SEQUENCE; Schema: public; Owner: alteeve
--

CREATE SEQUENCE alerts_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE public.alerts_id_seq OWNER TO alteeve;

--
-- Name: alerts_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: alteeve
--

ALTER SEQUENCE alerts_id_seq OWNED BY alerts.id;


--
-- Name: id; Type: DEFAULT; Schema: public; Owner: alteeve
--

ALTER TABLE ONLY alerts ALTER COLUMN id SET DEFAULT nextval('alerts_id_seq'::regclass);


--
-- Name: alerts_pkey; Type: CONSTRAINT; Schema: public; Owner: alteeve; Tablespace: 
--

ALTER TABLE ONLY alerts
    ADD CONSTRAINT alerts_pkey PRIMARY KEY (id);


--
-- Name: alerts_node_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: alteeve
--

ALTER TABLE ONLY alerts
    ADD CONSTRAINT alerts_node_id_fkey FOREIGN KEY (node_id) REFERENCES node(node_id);



\echo Create table history.alerts

CREATE TABLE history.alerts (
id              integer,
node_id		bigint,
target_name	text,
target_type     text,
target_extra	text,
field 		text,
value 		text,
units 		text,
status 		status,
message_tag 	text,
message_arguments 	text,
"timestamp" 	timestamp with time zone	not null	default now(),
history_id      serial primary key
);

ALTER TABLE history.alerts OWNER TO alteeve;

\echo Create function history_alerts to populate history.alerts from alerts

CREATE FUNCTION history_alerts() RETURNS trigger
AS $$
DECLARE
	hist_alerts RECORD;
BEGIN
	SELECT INTO hist_alerts * FROM alerts WHERE node_id=new.node_id;
	INSERT INTO history.alerts
		(id,
		node_id,
		target_name,
		target_type,
		target_extra,
		field,
		value,
		units,
		status,
		message_tag,
		message_arguments
		)
	VALUES
		(hist_alerts.id,
		 hist_alerts.node_id,
		 hist_alerts.target_name,
                 hist_alerts.target_type,
                 hist_alerts.target_extra,
                 hist_alerts.field,
                 hist_alerts.value,
		 hist_alerts.units,
		 hist_alerts.status,
		 hist_alerts.message_tag,
		 hist_alerts.message_arguments
		 );
	RETURN NULL;
END;
$$
LANGUAGE plpgsql;

 ALTER FUNCTION history_alerts() OWNER TO alteeve;

\echo Create trigger trigger_alerts using function history_alerts

CREATE TRIGGER trigger_alerts 
       AFTER INSERT OR UPDATE ON alerts 
       FOR EACH ROW EXECUTE PROCEDURE history_alerts();



--
-- PostgreSQL database dump complete
--

-- ----------------------------------------------------------------------
-- End of File
