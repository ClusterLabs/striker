drop table    if exists raid_controllers cascade;
drop table    if exists history.raid_controllers cascade;
drop function if exists history_raid_controllers();
drop trigger  if exists trigger_raid_controllers;

drop table    if exists raid_drives cascade;
drop table    if exists history.raid_drives cascade;
drop function if exists history_raid_drives();
drop trigger  if exists trigger_raid_drives;

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
-- Name: raid_controllers, raid_drives;
-- Type: TABLE; Schema: public; Owner: alteeve; Tablespace: 
--

CREATE TABLE raid_controllers (
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

ALTER TABLE public.raid_controllers OWNER TO alteeve;

CREATE TABLE raid_drives (
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

ALTER TABLE public.raid_drives OWNER TO alteeve;

--
-- Name: raid_controllers_id_seq, raid_drives_id_seq;
-- Type: SEQUENCE; Schema: public; Owner: alteeve
--

CREATE SEQUENCE raid_controllers_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE public.raid_controllers_id_seq OWNER TO alteeve;

CREATE SEQUENCE raid_drives_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE public.raid_drives_id_seq OWNER TO alteeve;

--
-- Name: raid_controllers_id_seq, raid_drives_id_seq;
-- Type: SEQUENCE OWNED BY; Schema: public; Owner: alteeve
--

ALTER SEQUENCE raid_controllers_id_seq OWNED BY raid_controllers.id;
ALTER SEQUENCE raid_drives_id_seq      OWNED BY raid_drives.id;


--
-- Name: id; Type: DEFAULT; Schema: public; Owner: alteeve
--

ALTER TABLE ONLY raid_controllers
ALTER COLUMN id
SET DEFAULT nextval('raid_controllers_id_seq'::regclass);

ALTER TABLE ONLY raid_drives
ALTER COLUMN id
SET DEFAULT nextval('raid_drives_id_seq'::regclass);


--
-- Name: raid_controllers_pkey raid_drives_pkey;
-- Type: CONSTRAINT; Schema: public; Owner: alteeve; Tablespace: 
--

ALTER TABLE ONLY raid_controllers
    ADD CONSTRAINT raid_controllers_pkey PRIMARY KEY (id);

ALTER TABLE ONLY raid_drives
    ADD CONSTRAINT raid_drives_pkey PRIMARY KEY (id);


--
-- Name: raid_controllers_node_id_fkey, raid_drives_node_id_fkey;
-- Type: FK CONSTRAINT; Schema: public; Owner: alteeve
--

ALTER TABLE ONLY raid_controllers
    ADD CONSTRAINT raid_controllers_node_id_fkey
    FOREIGN KEY (node_id) REFERENCES node(node_id);

ALTER TABLE ONLY raid_controllers
    ADD CONSTRAINT raid_drives_node_id_fkey
    FOREIGN KEY (node_id) REFERENCES node(node_id);


\echo Create table history.raid_controllers history.raid_drives

CREATE TABLE history.raid_controllers (
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

ALTER TABLE history.raid_controllers OWNER TO alteeve;

CREATE TABLE history.raid_drives (
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

ALTER TABLE history.raid_drives OWNER TO alteeve;

\echo Create functions history_raid_controllers & history_raid_drives
\echo to populate history.raid_controllers from raid_controllers,
\echo history.raid_drives from raid_drives.

CREATE FUNCTION history_raid_controllers() RETURNS trigger
AS $$
DECLARE
	hist_rec RECORD;
BEGIN
	SELECT INTO hist_rec * FROM raid_controllers WHERE node_id=new.node_id;
	INSERT INTO history.raid_controllers
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

ALTER FUNCTION history_raid_controllers() OWNER TO alteeve;

CREATE FUNCTION history_raid_drives() RETURNS trigger
AS $$
DECLARE
	hist_rec RECORD;
BEGIN
	SELECT INTO hist_rec * FROM raid_drives WHERE node_id=new.node_id;
	INSERT INTO history.raid_drives
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

ALTER FUNCTION history_raid_drives() OWNER TO alteeve;

\echo Create triggers trigger_raid_controllers & trigger_raid_drives
\echo using functions history_raid_controllers & history_raid_drives

CREATE TRIGGER trigger_raid_controllers 
       AFTER INSERT OR UPDATE ON raid_controllers 
       FOR EACH ROW EXECUTE PROCEDURE history_raid_controllers();

CREATE TRIGGER trigger_raid_drives 
       AFTER INSERT OR UPDATE ON raid_drives 
       FOR EACH ROW EXECUTE PROCEDURE history_raid_drives();

--
-- PostgreSQL database dump complete
--

