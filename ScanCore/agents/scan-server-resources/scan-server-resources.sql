-- This is the database schema for the 'remote-access Scan Agent'.

CREATE TABLE server_resources (
	server_resource_uuid			uuid				primary key,	-- This is set by the target, not by us!
	server_resource_host_uuid		uuid				not null,
	server_resource_target_access		text				not null,
	server_resource_host_name		text				not null,
	server_resource_os			text				not null,
	server_resource_boot_time		text				not null,
	server_resources_ram_size		numeric				not null,	-- In bytes
	server_resources_ram_used		numeric				not null,	-- In bytes
	server_resources_swap_size		numeric				not null,	-- In bytes
	server_resources_swap_used		numeric				not null,	-- In bytes
	modified_date				timestamp with time zone	not null,
	
	FOREIGN KEY(server_resource_host_uuid) REFERENCES hosts(host_uuid)
);
ALTER TABLE server_resources OWNER TO #!variable!user!#;

CREATE TABLE history.server_resources (
	history_id				bigserial,
	server_resource_uuid			uuid,
	server_resource_host_uuid		uuid,
	server_resource_target_access		text,
	server_resource_host_name		text,
	server_resource_os			text,
	server_resource_boot_time		text,
	server_resources_ram_size		numeric, 
	server_resources_ram_used		numeric, 
	server_resources_swap_size		numeric, 
	server_resources_swap_used		numeric, 
	modified_date				timestamp with time zone	not null
);
ALTER TABLE history.server_resources OWNER TO #!variable!user!#;

CREATE FUNCTION history_server_resources() RETURNS trigger
AS $$
DECLARE
	history_server_resources RECORD;
BEGIN
	SELECT INTO history_server_resources * FROM server_resources WHERE server_resource_uuid=new.server_resource_uuid;
	INSERT INTO history.server_resources
		(server_resource_uuid,
		 server_resource_host_uuid, 
		 server_resource_target_access, 
		 server_resource_host_name, 
		 server_resource_os, 
		 server_resource_boot_time, 
		 server_resources_ram_size, 
		 server_resources_ram_used, 
		 server_resources_swap_size, 
		 server_resources_swap_used, 
		 modified_date)
	VALUES
		(history_server_resources.server_resource_uuid,
		 history_server_resources.server_resource_host_uuid, 
		 history_server_resources.server_resource_target_access, 
		 history_server_resources.server_resource_host_name, 
		 history_server_resources.server_resource_os, 
		 history_server_resources.server_resource_boot_time, 
		 history_server_resources.server_resources_ram_size, 
		 history_server_resources.server_resources_ram_used, 
		 history_server_resources.server_resources_swap_size, 
		 history_server_resources.server_resources_swap_used, 
		 history_server_resources.modified_date);
	RETURN NULL;
END;
$$
LANGUAGE plpgsql;
ALTER FUNCTION history_server_resources() OWNER TO #!variable!user!#;

CREATE TRIGGER trigger_server_resources
	AFTER INSERT OR UPDATE ON server_resources
	FOR EACH ROW EXECUTE PROCEDURE history_server_resources();


-- Disk drives on the target
CREATE TABLE server_resources_disks (
	server_resources_disk_uuid			uuid				primary key,
	server_resources_disk_server_resource_uuid	uuid				not null,
	server_resources_disk_host_uuid			uuid				not null,
	server_resources_disk_mount_point		text				not null,	-- Drive letter or path
	server_resources_disk_filesystem		text,
	server_resources_disk_options			text,
	server_resources_disk_size			numeric				not null,	-- In bytes
	server_resources_disk_used			numeric				not null,	-- In bytes
	modified_date					timestamp with time zone	not null,
	
	FOREIGN KEY(server_resources_disk_server_resource_uuid) REFERENCES server_resources(server_resource_uuid)
);
ALTER TABLE server_resources_disks OWNER TO #!variable!user!#;

CREATE TABLE history.server_resources_disks (
	history_id					bigserial,
	server_resources_disk_uuid			uuid,
	server_resources_disk_server_resource_uuid	uuid,
	server_resources_disk_host_uuid			uuid,
	server_resources_disk_mount_point		text,
	server_resources_disk_filesystem		text,
	server_resources_disk_options			text,
	server_resources_disk_size			numeric,
	server_resources_disk_used			numeric,
	modified_date					timestamp with time zone
);
ALTER TABLE history.server_resources_disks OWNER TO #!variable!user!#;

CREATE FUNCTION history_server_resources_disks() RETURNS trigger
AS $$
DECLARE
	history_server_resources_disks RECORD;
BEGIN
	SELECT INTO history_server_resources_disks * FROM server_resources_disks WHERE server_resources_disk_uuid=new.server_resources_disk_uuid;
	INSERT INTO history.server_resources_disks
		(server_resources_disk_uuid, 
		 server_resources_disk_server_resource_uuid,
		 server_resources_disk_host_uuid,
		 server_resources_disk_mount_point,
		 server_resources_disk_filesystem,
		 server_resources_disk_options,
		 server_resources_disk_size,
		 server_resources_disk_used,
		 modified_date)
	VALUES
		(history_server_resources_disks.server_resources_disk_uuid,
		 history_server_resources_disks.server_resources_disk_server_resource_uuid,
		 history_server_resources_disks.server_resources_disk_host_uuid,
		 history_server_resources_disks.server_resources_disk_mount_point,
		 history_server_resources_disks.server_resources_disk_filesystem,
		 history_server_resources_disks.server_resources_disk_options,
		 history_server_resources_disks.server_resources_disk_size,
		 history_server_resources_disks.server_resources_disk_used,
		 history_server_resources_disks.modified_date);
	RETURN NULL;
END;
$$
LANGUAGE plpgsql;
ALTER FUNCTION history_server_resources_disks() OWNER TO #!variable!user!#;

CREATE TRIGGER trigger_server_resources_disks
	AFTER INSERT OR UPDATE ON server_resources_disks
	FOR EACH ROW EXECUTE PROCEDURE history_server_resources_disks();


-- CPUs drives on the target
CREATE TABLE server_resources_cpus (
	server_resources_cpu_uuid			uuid				primary key,
	server_resources_cpu_server_resource_uuid	uuid				not null,
	server_resources_cpu_host_uuid			uuid				not null,
	server_resources_cpu_number			text				not null,
	server_resources_cpu_load			numeric				not null,
	modified_date					timestamp with time zone	not null,
	
	FOREIGN KEY(server_resources_cpu_server_resource_uuid) REFERENCES server_resources(server_resource_uuid)
);
ALTER TABLE server_resources_cpus OWNER TO #!variable!user!#;

CREATE TABLE history.server_resources_cpus (
	history_id					bigserial,
	server_resources_cpu_uuid			uuid,
	server_resources_cpu_server_resource_uuid	uuid,
	server_resources_cpu_host_uuid			uuid,
	server_resources_cpu_number			text,
	server_resources_cpu_load			numeric,
	modified_date					timestamp with time zone
);
ALTER TABLE history.server_resources_cpus OWNER TO #!variable!user!#;

CREATE FUNCTION history_server_resources_cpus() RETURNS trigger
AS $$
DECLARE
	history_server_resources_cpus RECORD;
BEGIN
	SELECT INTO history_server_resources_cpus * FROM server_resources_cpus WHERE server_resources_cpu_uuid=new.server_resources_cpu_uuid;
	INSERT INTO history.server_resources_cpus
		(server_resources_cpu_uuid, 
		 server_resources_cpu_server_resource_uuid,
		 server_resources_cpu_host_uuid,
		 server_resources_cpu_number,
		 server_resources_cpu_load,
		 modified_date)
	VALUES
		(history_server_resources_cpus.server_resources_cpu_uuid,
		 history_server_resources_cpus.server_resources_cpu_server_resource_uuid,
		 history_server_resources_cpus.server_resources_cpu_host_uuid,
		 history_server_resources_cpus.server_resources_cpu_number,
		 history_server_resources_cpus.server_resources_cpu_load,
		 history_server_resources_cpus.modified_date);
	RETURN NULL;
END;
$$
LANGUAGE plpgsql;
ALTER FUNCTION history_server_resources_cpus() OWNER TO #!variable!user!#;

CREATE TRIGGER trigger_server_resources_cpus
	AFTER INSERT OR UPDATE ON server_resources_cpus
	FOR EACH ROW EXECUTE PROCEDURE history_server_resources_cpus();
