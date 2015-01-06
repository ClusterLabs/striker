drop table if exists alerts cascade;
--
-- PostgreSQL database dump
--

SET statement_timeout = 0;
SET lock_timeout = 0;
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
    msg_tag text,
    msg_args text,
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
node_id		bigint,
agent_name	text	not null,	-- I break the short name off of the FQDN
agent_host      text,
pid             int,
target_name     text,
target_type     text,
target_ip       text,
status          text,
history_id	serial  primary key,
modified_user	int	not null,
modified_date	timestamp with time zone	not null	default now()
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
		(node_id,
		 agent_name,
		 agent_host,
                 pid,
		 target_name,
                 target_type,
                 target_ip,
		 status,
		 modified_user)
	VALUES
		(hist_alerts.node_id,
		 hist_alerts.agent_name,
		 hist_alerts.agent_host,
                 hist_alerts.pid,
                 hist_alerts.target_name,
                 hist_alerts.target_type,
                 hist_alerts.target_ip,
		 hist_alerts.status,
		 hist_alerts.modified_user);
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

