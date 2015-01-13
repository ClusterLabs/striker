drop table    if exists raid_temp cascade;
drop table    if exists history.raid_temp cascade;
drop function if exists history_raid_temp();
drop trigger  trigger_raid_temp;

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
-- Name: raid_temp; Type: TABLE; Schema: public; Owner: alteeve; Tablespace: 
--

CREATE TABLE raid_temp (
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


ALTER TABLE public.raid_temp OWNER TO alteeve;

--
-- Name: raid_temp_id_seq; Type: SEQUENCE; Schema: public; Owner: alteeve
--

CREATE SEQUENCE raid_temp_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE public.raid_temp_id_seq OWNER TO alteeve;

--
-- Name: raid_temp_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: alteeve
--

ALTER SEQUENCE raid_temp_id_seq OWNED BY raid_temp.id;


--
-- Name: id; Type: DEFAULT; Schema: public; Owner: alteeve
--

ALTER TABLE ONLY raid_temp ALTER COLUMN id SET DEFAULT nextval('raid_temp_id_seq'::regclass);


--
-- Name: raid_temp_pkey; Type: CONSTRAINT; Schema: public; Owner: alteeve; Tablespace: 
--

ALTER TABLE ONLY raid_temp
    ADD CONSTRAINT raid_temp_pkey PRIMARY KEY (id);


--
-- Name: raid_temp_node_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: alteeve
--

ALTER TABLE ONLY raid_temp
    ADD CONSTRAINT raid_temp_node_id_fkey FOREIGN KEY (node_id) REFERENCES node(node_id);


\echo Create table history.raid_temp

CREATE TABLE history.raid_temp (
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

ALTER TABLE history.raid_temp OWNER TO alteeve;

\echo Create function history_raid_temp to populate history.raid_temp from raid_temp

CREATE FUNCTION history_raid_temp() RETURNS trigger
AS $$
DECLARE
	hist_rec RECORD;
BEGIN
	SELECT INTO hist_rec * FROM raid_temp WHERE node_id=new.node_id;
	INSERT INTO history.raid_temp
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

ALTER FUNCTION history_raid_temp() OWNER TO alteeve;

\echo Create trigger trigger_raid_temp using function history_raid_temps

CREATE TRIGGER trigger_raid_temp 
       AFTER INSERT OR UPDATE ON raid_temp 
       FOR EACH ROW EXECUTE PROCEDURE history_raid_temp();

--
-- PostgreSQL database dump complete
--

