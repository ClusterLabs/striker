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

--
-- Data for Name: alert_listeners; Type: TABLE DATA; Schema: public; Owner: alteeve
--

insert into alert_listeners
(
   id, name, mode, level, contact_info, language, added_by, updated
)
VALUES
(
   1,'screen','Screen','DEBUG','screen','en_CA',0,'2014-12-11 14:42:13.273057-05'
);

insert into alert_listeners
(
   id, name, mode, level, contact_info, language, added_by, updated
)
VALUES
(
   2,'Tom Legrady','Email','DEBUG','tom@alteeve.ca','en_CA',0,'2014-12-11 16:54:25.477321-05'
);

insert into alert_listeners
(
   id, name, mode, level, contact_info, language, added_by, updated
)
VALUES
(
   3,'Health Monitor','HealthMonitor','WARNING','','en_CA',0,'2015-01-14 14:08:15-05'
);


--
-- Name: alert_listeners_id_seq; Type: SEQUENCE SET; Schema: public; Owner: alteeve
--

SELECT pg_catalog.setval('alert_listeners_id_seq', 4, true);


--
-- PostgreSQL database dump complete
--

