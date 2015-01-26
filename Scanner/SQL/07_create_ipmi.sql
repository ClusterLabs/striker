drop table    if exists ipmi_temperatures cascade;
drop table    if exists history.ipmi_temperatures cascade;
drop function if exists history_ipmi_temperatures();
drop trigger  trigger_ipmi_temperatures;

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
-- Name: ipmi_temperatures; Type: TABLE; Schema: public; Owner: alteeve; Tablespace: 
--

CREATE TABLE ipmi_temperatures (
    id       integer NOT NULL,
    node_id  bigint,
    target   text,
    field    text,
    value    text,
    units    text,
    status   status,
    message_tag  text,
    message_arguements text,
    "timestamp" timestamp with time zone DEFAULT now() NOT NULL
);


ALTER TABLE public.ipmi_temperatures OWNER TO alteeve;

--
-- Name: ipmi_temperatures_id_seq; Type: SEQUENCE; Schema: public; Owner: alteeve
--

CREATE SEQUENCE ipmi_temperatures_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE public.ipmi_temperatures_id_seq OWNER TO alteeve;

--
-- Name: ipmi_temperatures_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: alteeve
--

ALTER SEQUENCE ipmi_temperatures_id_seq OWNED BY ipmi_temperatures.id;


--
-- Name: id; Type: DEFAULT; Schema: public; Owner: alteeve
--

ALTER TABLE ONLY ipmi_temperatures ALTER COLUMN id SET DEFAULT nextval('ipmi_temperatures_id_seq'::regclass);


--
-- Name: ipmi_temperatures_pkey; Type: CONSTRAINT; Schema: public; Owner: alteeve; Tablespace: 
--

ALTER TABLE ONLY ipmi_temperatures
    ADD CONSTRAINT ipmi_temperatures_pkey PRIMARY KEY (id);


--
-- Name: ipmi_temperatures_node_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: alteeve
--

ALTER TABLE ONLY ipmi_temperatures
    ADD CONSTRAINT ipmi_temperatures_node_id_fkey FOREIGN KEY (node_id) REFERENCES node(node_id);


\echo Create table history.ipmi_temperatures

CREATE TABLE history.ipmi_temperatures (
    history_id serial primary key,
    id         integer NOT NULL,
    node_id    bigint,
    target     text,
    field      text,
    value      text,
    units      text,
    status     status,
    message_tag    text,
    message_arguements   text,
    "timestamp" timestamp with time zone DEFAULT now() NOT NULL
);

ALTER TABLE history.ipmi_temperatures OWNER TO alteeve;

\echo Create function history_ipmi_temperatures to populate history.ipmi_temperatures from ipmi_temperatures

CREATE FUNCTION history_ipmi_temperatures() RETURNS trigger
AS $$
DECLARE
	hist_rec RECORD;
BEGIN
	SELECT INTO hist_rec * FROM ipmi_temperatures WHERE node_id=new.node_id;
	INSERT INTO history.ipmi_temperatures
		(id,
                 node_id,
		 target,
		 field,
		 value,
                 units,
		 status,
                 message_tag,
                 message_arguements,
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
                 hist_rec.message_arguements,
		 hist_rec.timestamp);
	RETURN NULL;
END;
$$
LANGUAGE plpgsql;

ALTER FUNCTION history_ipmi_temperatures() OWNER TO alteeve;

\echo Create trigger trigger_ipmi_temperatures using function history_ipmi_temperaturess

CREATE TRIGGER trigger_ipmi_temperatures 
       AFTER INSERT OR UPDATE ON ipmi_temperatures 
       FOR EACH ROW EXECUTE PROCEDURE history_ipmi_temperatures();

--
-- PostgreSQL database dump complete
--

