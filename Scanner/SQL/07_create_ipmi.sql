drop table    if exists ipmi_temp cascade;
drop table    if exists history.ipmi_temp cascade;
drop function if exists history_ipmi_temp();
drop trigger  trigger_ipmi_temp;

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
-- Name: ipmi_temp; Type: TABLE; Schema: public; Owner: alteeve; Tablespace: 
--

CREATE TABLE ipmi_temp (
    id       integer NOT NULL,
    node_id  bigint,
    target   text,
    field    text,
    value    text,
    units    text,
    status   status,
    msg_tag  text,
    msg_args text,
    "timestamp" timestamp with time zone DEFAULT now() NOT NULL
);


ALTER TABLE public.ipmi_temp OWNER TO alteeve;

--
-- Name: ipmi_temp_id_seq; Type: SEQUENCE; Schema: public; Owner: alteeve
--

CREATE SEQUENCE ipmi_temp_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE public.ipmi_temp_id_seq OWNER TO alteeve;

--
-- Name: ipmi_temp_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: alteeve
--

ALTER SEQUENCE ipmi_temp_id_seq OWNED BY ipmi_temp.id;


--
-- Name: id; Type: DEFAULT; Schema: public; Owner: alteeve
--

ALTER TABLE ONLY ipmi_temp ALTER COLUMN id SET DEFAULT nextval('ipmi_temp_id_seq'::regclass);


--
-- Name: ipmi_temp_pkey; Type: CONSTRAINT; Schema: public; Owner: alteeve; Tablespace: 
--

ALTER TABLE ONLY ipmi_temp
    ADD CONSTRAINT ipmi_temp_pkey PRIMARY KEY (id);


--
-- Name: ipmi_temp_node_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: alteeve
--

ALTER TABLE ONLY ipmi_temp
    ADD CONSTRAINT ipmi_temp_node_id_fkey FOREIGN KEY (node_id) REFERENCES node(node_id);


\echo Create table history.ipmi_temp

CREATE TABLE history.ipmi_temp (
    history_id serial primary key,
    id         integer NOT NULL,
    node_id    bigint,
    target     text,
    field      text,
    value      text,
    units      text,
    status     status,
    msg_tag    text,
    msg_args   text,
    "timestamp" timestamp with time zone DEFAULT now() NOT NULL
);

ALTER TABLE history.ipmi_temp OWNER TO alteeve;

\echo Create function history_ipmi_temp to populate history.ipmi_temp from ipmi_temp

CREATE FUNCTION history_ipmi_temp() RETURNS trigger
AS $$
DECLARE
	hist_rec RECORD;
BEGIN
	SELECT INTO hist_rec * FROM ipmi_temp WHERE node_id=new.node_id;
	INSERT INTO history.ipmi_temp
		(id,
                 node_id,
		 target,
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
		 hist_rec.target,
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

ALTER FUNCTION history_ipmi_temp() OWNER TO alteeve;

\echo Create trigger trigger_ipmi_temp using function history_ipmi_temps

CREATE TRIGGER trigger_ipmi_temp 
       AFTER INSERT OR UPDATE ON ipmi_temp 
       FOR EACH ROW EXECUTE PROCEDURE history_ipmi_temp();

--
-- PostgreSQL database dump complete
--

