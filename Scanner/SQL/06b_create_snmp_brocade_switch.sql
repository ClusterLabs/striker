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
-- Name: snmp_brocade_switch; Type: TABLE; Schema: public; Owner: striker; Tablespace: 
--

CREATE TABLE snmp_brocade_switch (
    id       integer NOT NULL,
    node_id  bigint,
    target   text,
    field    text,
    value    text,
    units    text,
    status   status,
    message_tag  text,
    message_arguments text,
    "timestamp" timestamp with time zone DEFAULT now() NOT NULL
);


ALTER TABLE public.snmp_brocade_switch OWNER TO striker;

--
-- Name: snmp_brocade_switch_id_seq; Type: SEQUENCE; Schema: public; Owner: striker
--

CREATE SEQUENCE snmp_brocade_switch_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE public.snmp_brocade_switch_id_seq OWNER TO striker;

--
-- Name: snmp_brocade_switch_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: striker
--

ALTER SEQUENCE snmp_brocade_switch_id_seq OWNED BY snmp_brocade_switch.id;


--
-- Name: id; Type: DEFAULT; Schema: public; Owner: striker
--

ALTER TABLE ONLY snmp_brocade_switch ALTER COLUMN id SET DEFAULT nextval('snmp_brocade_switch_id_seq'::regclass);


--
-- Name: snmp_brocade_switch_pkey; Type: CONSTRAINT; Schema: public; Owner: striker; Tablespace: 
--

ALTER TABLE ONLY snmp_brocade_switch
    ADD CONSTRAINT snmp_brocade_switch_pkey PRIMARY KEY (id);


--
-- Name: snmp_brocade_switch_node_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: striker
--

ALTER TABLE ONLY snmp_brocade_switch
    ADD CONSTRAINT snmp_brocade_switch_node_id_fkey FOREIGN KEY (node_id) REFERENCES node(node_id);


\echo Create table history.snmp_brocade_switch

CREATE TABLE history.snmp_brocade_switch (
    history_id serial primary key,
    id integer NOT NULL,
    node_id bigint,
    target   text,
    field text,
    value text,
    units text,
    status status,
    message_tag text,
    message_arguments text,
    "timestamp" timestamp with time zone DEFAULT now() NOT NULL
);

ALTER TABLE history.snmp_brocade_switch OWNER TO striker;

\echo Create function history_snmp_brocade_switch to populate history.snmp_brocade_switch from snmp_brocade_switch

CREATE FUNCTION history_snmp_brocade_switch() RETURNS trigger
AS $$
DECLARE
	hist_rec RECORD;
BEGIN
	SELECT INTO hist_rec * FROM snmp_brocade_switch WHERE node_id=new.node_id;
	INSERT INTO history.snmp_brocade_switch
		(id,
                 node_id,
		 target,
		 field,
		 value,
                 units,
		 status,
                 message_tag,
                 message_arguments,
                 timestamp
		 )
	VALUES
		(hist_rec.id,
		 hist_rec.node_id,
		 hist_rec.target,
		 hist_rec.field,
		 hist_rec.value,
                 hist_rec.units,
                 hist_rec.status,
                 hist_rec.message_tag,
                 hist_rec.message_arguments,
		 hist_rec.timestamp);
	RETURN NULL;
END;
$$
LANGUAGE plpgsql;

ALTER FUNCTION history_snmp_brocade_switch() OWNER TO striker;

\echo Create trigger trigger_snmp_brocade_switch using function history_snmp_brocade_switchs

CREATE TRIGGER trigger_snmp_brocade_switch 
       AFTER INSERT OR UPDATE ON snmp_brocade_switch 
       FOR EACH ROW EXECUTE PROCEDURE history_snmp_brocade_switch();

--
-- PostgreSQL database dump complete
--

-- ----------------------------------------------------------------------
-- End of File
