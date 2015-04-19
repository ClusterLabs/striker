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
-- Name: bonding, bonding;
-- Type: TABLE; Schema: public; Owner: striker; Tablespace: 
--

CREATE TABLE bonding (
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

ALTER TABLE public.bonding OWNER TO striker;

--
-- Name: bonding_id_seq, bonding_id_seq;
-- Type: SEQUENCE; Schema: public; Owner: striker
--

CREATE SEQUENCE bonding_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE public.bonding_id_seq OWNER TO striker;

--
-- Name: bonding_id_seq, bonding_id_seq;
-- Type: SEQUENCE OWNED BY; Schema: public; Owner: striker
--

ALTER SEQUENCE bonding_id_seq OWNED BY bonding.id;

--
-- Name: id; Type: DEFAULT; Schema: public; Owner: striker
--

ALTER TABLE ONLY bonding
ALTER COLUMN id
SET DEFAULT nextval('bonding_id_seq'::regclass);

--
-- Name: bonding_pkey bonding_pkey;
-- Type: CONSTRAINT; Schema: public; Owner: striker; Tablespace: 
--

ALTER TABLE ONLY bonding
    ADD CONSTRAINT bonding_pkey PRIMARY KEY (id);

--
-- Name: bonding_node_id_fkey, bonding_drives_node_id_fkey;
-- Type: FK CONSTRAINT; Schema: public; Owner: striker
--

ALTER TABLE ONLY bonding
    ADD CONSTRAINT bonding_node_id_fkey
    FOREIGN KEY (node_id) REFERENCES node(node_id);

\echo Create table history.bonding history.bonding_drives

CREATE TABLE history.bonding (
    history_id serial primary key,
    id         integer NOT NULL,
    node_id    bigint,
    target     text,
    field      text,
    value      text,
    units      text,
    status     status,
    message_tag    text,
    message_arguments   text,
    "timestamp" timestamp with time zone DEFAULT now() NOT NULL
);

ALTER TABLE history.bonding OWNER TO striker;

CREATE TABLE history.bonding (
    history_id serial primary key,
    id         integer NOT NULL,
    node_id    bigint,
    target     text,
    field      text,
    value      text,
    units      text,
    status     status,
    message_tag    text,
    message_arguments   text,
    "timestamp" timestamp with time zone DEFAULT now() NOT NULL
);

ALTER TABLE history.bonding OWNER TO striker;

\echo Create functions history_bonding
\echo to populate history.bonding from bonding.

CREATE FUNCTION history_bonding() RETURNS trigger
AS $$
DECLARE
	hist_rec RECORD;
BEGIN
	SELECT INTO hist_rec * FROM bonding WHERE node_id=new.node_id;
	INSERT INTO history.bonding
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

ALTER FUNCTION history_bonding() OWNER TO striker;

\echo Create triggers trigger_bonding using functions history_bonding

CREATE TRIGGER trigger_bonding 
       AFTER INSERT OR UPDATE ON bonding 
       FOR EACH ROW EXECUTE PROCEDURE history_bonding();

--
-- PostgreSQL database dump complete
--

-- ----------------------------------------------------------------------
-- End of File
