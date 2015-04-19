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
-- Name: snmp_apc_pdu; Type: TABLE; Schema: public; Owner: striker; Tablespace: 
--

CREATE TABLE snmp_apc_pdu (
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


ALTER TABLE public.snmp_apc_pdu OWNER TO striker;

--
-- Name: snmp_apc_pdu_id_seq; Type: SEQUENCE; Schema: public; Owner: striker
--

CREATE SEQUENCE snmp_apc_pdu_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE public.snmp_apc_pdu_id_seq OWNER TO striker;

--
-- Name: snmp_apc_pdu_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: striker
--

ALTER SEQUENCE snmp_apc_pdu_id_seq OWNED BY snmp_apc_pdu.id;


--
-- Name: id; Type: DEFAULT; Schema: public; Owner: striker
--

ALTER TABLE ONLY snmp_apc_pdu ALTER COLUMN id SET DEFAULT nextval('snmp_apc_pdu_id_seq'::regclass);


--
-- Name: snmp_apc_pdu_pkey; Type: CONSTRAINT; Schema: public; Owner: striker; Tablespace: 
--

ALTER TABLE ONLY snmp_apc_pdu
    ADD CONSTRAINT snmp_apc_pdu_pkey PRIMARY KEY (id);


--
-- Name: snmp_apc_pdu_node_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: striker
--

ALTER TABLE ONLY snmp_apc_pdu
    ADD CONSTRAINT snmp_apc_pdu_node_id_fkey FOREIGN KEY (node_id) REFERENCES node(node_id);


\echo Create table history.snmp_apc_pdu

CREATE TABLE history.snmp_apc_pdu (
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

ALTER TABLE history.snmp_apc_pdu OWNER TO striker;

\echo Create function history_snmp_apc_pdu to populate history.snmp_apc_pdu from snmp_apc_pdu

CREATE FUNCTION history_snmp_apc_pdu() RETURNS trigger
AS $$
DECLARE
	hist_rec RECORD;
BEGIN
	SELECT INTO hist_rec * FROM snmp_apc_pdu WHERE node_id=new.node_id;
	INSERT INTO history.snmp_apc_pdu
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

ALTER FUNCTION history_snmp_apc_pdu() OWNER TO striker;

\echo Create trigger trigger_snmp_apc_pdu using function history_snmp_apc_pdus

CREATE TRIGGER trigger_snmp_apc_pdu 
       AFTER INSERT OR UPDATE ON snmp_apc_pdu 
       FOR EACH ROW EXECUTE PROCEDURE history_snmp_apc_pdu();

--
-- PostgreSQL database dump complete
--

-- ----------------------------------------------------------------------
-- End of File
