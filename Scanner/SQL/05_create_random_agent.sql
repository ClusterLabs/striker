
drop trigger if exists trigger_agent_data on agent_data cascade;
drop table if exists agent_data cascade;
drop table if exists history.agent_data cascade;
drop function if exists history_agent_data() cascade;
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
-- Name: agent_data; Type: TABLE; Schema: public; Owner: alteeve; Tablespace: 
--

CREATE TABLE agent_data (
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


ALTER TABLE public.agent_data OWNER TO alteeve;

--
-- Name: agent_data_id_seq; Type: SEQUENCE; Schema: public; Owner: alteeve
--

CREATE SEQUENCE agent_data_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE public.agent_data_id_seq OWNER TO alteeve;

--
-- Name: agent_data_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: alteeve
--

ALTER SEQUENCE agent_data_id_seq OWNED BY agent_data.id;


--
-- Name: id; Type: DEFAULT; Schema: public; Owner: alteeve
--

ALTER TABLE ONLY agent_data ALTER COLUMN id SET DEFAULT nextval('agent_data_id_seq'::regclass);


--
-- Name: agent_data_pkey; Type: CONSTRAINT; Schema: public; Owner: alteeve; Tablespace: 
--

ALTER TABLE ONLY agent_data
    ADD CONSTRAINT agent_data_pkey PRIMARY KEY (id);


--
-- Name: agent_data_node_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: alteeve
--

ALTER TABLE ONLY agent_data
    ADD CONSTRAINT agent_data_node_id_fkey FOREIGN KEY (node_id) REFERENCES node(node_id);


\echo Create table history.agent_data

CREATE TABLE history.agent_data (
    id 	     integer NOT NULL,
    node_id  bigint,
    field    text,
    value    text,
    units    text,
    status   status,
    msg_tag  text,
    msg_args text,
    "timestamp"	timestamp with time zone	not null	default now()
);

ALTER TABLE history.agent_data OWNER TO alteeve;

\echo Create function history_agent_data to populate history.agent_data from agent_data

CREATE FUNCTION history_agent_data() RETURNS trigger
AS $$
DECLARE
	hist_agent_data RECORD;
BEGIN
	SELECT INTO hist_agent_data * FROM node WHERE id=new.id;
	INSERT INTO history.agent_data
		(id,
		 node_id,	
    		 field,
		 value,
		 units,
		 status,
		 msg_tag,
		 msg_args,
	         timestamp_id,
	)
	VALUES
		(hist_agent_data.id,
		 hist_agent_data.node_id,
		 hist_agent_data.field,
                 hist_agent_data.value,
                 hist_agent_data.units,
                 hist_agent_data.status,
                 hist_agent_data.msg_tag,
		 hist_agent_data.msg_args);
	RETURN NULL;
END;
$$
LANGUAGE plpgsql;

 ALTER FUNCTION history_agent_data() OWNER TO alteeve;

\echo Create trigger trigger_agent_data using function history_agent_data

CREATE TRIGGER trigger_agent_data
       AFTER INSERT OR UPDATE ON agent_data
       FOR EACH ROW EXECUTE PROCEDURE history_agent_data();


--
-- PostgreSQL database dump complete
--

