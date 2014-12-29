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
-- Name: agent_data; Type: TABLE; Schema: public; Owner: alteeve; Tablespace: 
--

CREATE TABLE agent_data (
    id integer NOT NULL,
    node_id bigint,
    value integer,
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


--
-- PostgreSQL database dump complete
--

