drop table    if exists snmp_apc_ups cascade;
drop table    if exists history.snmp_apc_ups cascade;
drop function if exists history_snmp_apc_ups();
drop trigger  trigger_snmp_apc_ups;

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
-- Name: snmp_apc_ups; Type: TABLE; Schema: public; Owner: alteeve; Tablespace: 
--

CREATE TABLE snmp_apc_ups (
    id integer NOT NULL,
    node_id bigint,
    field text,
    value text,
    units text,
    status status,
    msg_tag text,
    msg_args text,
    "timestamp" timestamp with time zone DEFAULT now() NOT NULL
);


ALTER TABLE public.snmp_apc_ups OWNER TO alteeve;

--
-- Name: snmp_apc_ups_id_seq; Type: SEQUENCE; Schema: public; Owner: alteeve
--

CREATE SEQUENCE snmp_apc_ups_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE public.snmp_apc_ups_id_seq OWNER TO alteeve;

--
-- Name: snmp_apc_ups_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: alteeve
--

ALTER SEQUENCE snmp_apc_ups_id_seq OWNED BY snmp_apc_ups.id;


--
-- Name: id; Type: DEFAULT; Schema: public; Owner: alteeve
--

ALTER TABLE ONLY snmp_apc_ups ALTER COLUMN id SET DEFAULT nextval('snmp_apc_ups_id_seq'::regclass);


--
-- Name: snmp_apc_ups_pkey; Type: CONSTRAINT; Schema: public; Owner: alteeve; Tablespace: 
--

ALTER TABLE ONLY snmp_apc_ups
    ADD CONSTRAINT snmp_apc_ups_pkey PRIMARY KEY (id);


--
-- Name: snmp_apc_ups_node_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: alteeve
--

ALTER TABLE ONLY snmp_apc_ups
    ADD CONSTRAINT snmp_apc_ups_node_id_fkey FOREIGN KEY (node_id) REFERENCES node(node_id);


\echo Create table history.snmp_apc_ups

CREATE TABLE history.snmp_apc_ups (
    history_id serial primary key,
    id integer NOT NULL,
    node_id bigint,
    field text,
    value text,
    units text,
    status status,
    msg_tag text,
    msg_args text,
    "timestamp" timestamp with time zone DEFAULT now() NOT NULL
);

ALTER TABLE history.snmp_apc_ups OWNER TO alteeve;

\echo Create function history_snmp_apc_ups to populate history.snmp_apc_ups from snmp_apc_ups

CREATE FUNCTION history_snmp_apc_ups() RETURNS trigger
AS $$
DECLARE
	hist_rec RECORD;
BEGIN
	SELECT INTO hist_rec * FROM snmp_apc_ups WHERE node_id=new.node_id;
	INSERT INTO history.snmp_apc_ups
		(id,
                 node_id,
		 field,
		 value,
                 units,
		 status,
                 msg_tag,
                 msg_args,
                 timestamp
		 )
	VALUES
		(hist_rec.id,
		 hist_rec.node_id,
		 hist_rec.field,
		 hist_rec.value,
                 hist_rec.units,
                 hist_rec.status,
                 hist_rec.msg_tag,
                 hist_rec.msg_args,
		 hist_rec.timestamp);
	RETURN NULL;
END;
$$
LANGUAGE plpgsql;

ALTER FUNCTION history_snmp_apc_ups() OWNER TO alteeve;

\echo Create trigger trigger_snmp_apc_ups using function history_snmp_apc_upss

CREATE TRIGGER trigger_snmp_apc_ups 
       AFTER INSERT OR UPDATE ON snmp_apc_ups 
       FOR EACH ROW EXECUTE PROCEDURE history_snmp_apc_ups();

--
-- PostgreSQL database dump complete
--

