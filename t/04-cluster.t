#!/usr/bin/env perl

use Test::More;

use lib '../cgi-bin/lib/';
use AN::Cluster;

# ......................................................................
#
sub test__configure_local_system {

}

# ......................................................................
#
sub test__check_for_updates {

}

# ......................................................................
#
sub test__read_network_settings {

}

# ----------------------------------------------------------------------
#
sub test__call_gather_system_info {

}

# ......................................................................
#
sub test__sanity_check_an_conf {

}

# ......................................................................
#
sub test__write_new_an_conf {

}

# ......................................................................
#
sub test__read_hosts {

}

# ......................................................................
#
sub test__read_ssh_config {

}

# ......................................................................
#
sub test__copy_file {

}

# ......................................................................
#
sub test__write_new_ssh_config {

}

# ......................................................................
#
sub test__write_new_hosts {

}

# ......................................................................
#
sub test__save_dashboard_configure {

}

# ......................................................................
#
sub test__load_configuration_defaults {

}

# ......................................................................
#
sub test__show_anvil_config_header {

}

# ......................................................................
#
sub test__show_global_config_header {

}

# ......................................................................
#
sub test__show_common_config_section {

}

# ......................................................................
#
sub test__show_global_anvil_list {

}

# ......................................................................
#
sub test__push_config_to_anvil {

}

# ......................................................................
#
sub test__show_archive_options {

}

# ......................................................................
#
sub test__create_backup_file {

}

# ......................................................................
#
sub test__load_backup_configuration {

}

# ......................................................................
#
sub test__create_install_manifest {

}

# ......................................................................
#
sub test__load_install_manifest {

}

# ......................................................................
#
sub test__show_existing_install_manifests {

}

# ......................................................................
#
sub test__generate_install_manifest {

}

# ......................................................................
#
sub test__confirm_install_manifest_run {

}

# ......................................................................
#
sub test__show_summary_manifest {

}

# ......................................................................
#
sub test__sanity_check_manifest_answers {

}

# ......................................................................
#
sub test__is_string_integer_or_unsigned_float {

}

# ......................................................................
#
sub test__is_domain_name {

}

# ......................................................................
#
sub test__is_string_ipv4_with_subnet {

}

# ......................................................................
#
sub test__is_string_ipv4 {

}

# ......................................................................
#
sub test__configure_dashboard {

}

# ......................................................................
#
sub test__convert_text_to_html {

}

# ......................................................................
#
sub test__convert_html_to_text {

}

# ......................................................................
#
sub test__ask_which_cluster {

}

# ......................................................................
#
sub test__convert_cluster_config {

}

# ......................................................................
#
sub test__error {

}

# ......................................................................
#
sub test__header {

}

# ......................................................................
#
sub test__find_executables {

}

# ......................................................................
#
sub test__get_guacamole_link {

}

# ......................................................................
#
sub test__footer {

}

# ......................................................................
#
sub test__get_date {

}

# ......................................................................
#
sub test__get_cgi_vars {

}

# ......................................................................
#
sub test__read_conf {

}

# ......................................................................
#
sub test__build_select {

}

# ......................................................................
#
sub test__read_files_on_shared {

}

# ......................................................................
#
sub test__record {

}

# ......................................................................
#
sub test__scan_cluster {

}

# ......................................................................
#
sub test__check_nodes {

}

# ......................................................................
#
sub test__check_node_status {

}

# ......................................................................
#
sub test__post_scan_calculations {

}

# ......................................................................
#
sub test__post_node_calculations {

}

# ......................................................................
#
sub test__comma {

}

# ......................................................................
#
sub test__bytes_to_hr {

}

# ......................................................................
#
sub test__hr_to_bytes {

}

# ......................................................................
#
sub test__ping_node {

}

# ......................................................................
#
sub test__gather_node_details {

}

# ......................................................................
#
sub test__get_rsa_public_key {

}

# ......................................................................
#
sub test__get_hostname {

}

# ......................................................................
#
sub test__remote_call {

}

# ......................................................................
#
sub test__parse_hosts {

}

# ......................................................................
#
sub test__parse_dmesg {

}

# ......................................................................
#
sub test__parse_bonds {

}

# ......................................................................
#
sub test__parse_vm_defs {

}

# ......................................................................
#
sub test__parse_dmidecode {

}

# ......................................................................
#
sub test__parse_meminfo {

}

# ......................................................................
#
sub test__parse_proc_drbd {

}

# ......................................................................
#
sub test__old_parse_drbd_status {

}

# ......................................................................
#
sub test__parse_drbdadm_dumpxml {

}

# ......................................................................
#
sub test__parse_clustat {

}

# ......................................................................
#
sub test__parse_cluster_conf {

}

# ......................................................................
#
sub test__parse_daemons {

}

# ......................................................................
#
sub test__parse_lvm_scan {

}

# ......................................................................
#
sub test__parse_lvm_data {

}

# ......................................................................
#
sub test__parse_virsh {

}

# ......................................................................
#
sub test__parse_gfs2 {

}

# ......................................................................
#
sub test__set_daemons {

}

# ......................................................................
#
sub test__check_if_on {

}

# ......................................................................
#
sub test__on_same_network {

}

# ......................................................................
#
sub test__write_node_cache {

}

# ......................................................................
#
sub test__read_node_cache {

}

main {
    test__configure_local_system();
    test__check_for_updates();
    test__read_network_settings();
    test__call_gather_system_info();
    test__sanity_check_an_conf();
    test__write_new_an_conf();
    test__read_hosts();
    test__read_ssh_config();
    test__copy_file();
    test__write_new_ssh_config();
    test__write_new_hosts();
    test__save_dashboard_configure();
    test__load_configuration_defaults();
    test__show_anvil_config_header();
    test__show_global_config_header();
    test__show_common_config_section();
    test__show_global_anvil_list();
    test__push_config_to_anvil();
    test__show_archive_options();
    test__create_backup_file();
    test__load_backup_configuration();
    test__create_install_manifest();
    test__load_install_manifest();
    test__show_existing_install_manifests();
    test__generate_install_manifest();
    test__confirm_install_manifest_run();
    test__show_summary_manifest();
    test__sanity_check_manifest_answers();
    test__is_string_integer_or_unsigned_float();
    test__is_domain_name();
    test__is_string_ipv4_with_subnet();
    test__is_string_ipv4();
    test__configure_dashboard();
    test__convert_text_to_html();
    test__convert_html_to_text();
    test__ask_which_cluster();
    test__convert_cluster_config();
    test__error();
    test__header();
    test__find_executables();
    test__get_guacamole_link();
    test__footer();
    test__get_date();
    test__get_cgi_vars();
    test__read_conf();
    test__build_select();
    test__read_files_on_shared();
    test__record();
    test__scan_cluster();
    test__check_nodes();
    test__check_node_status();
    test__post_scan_calculations();
    test__post_node_calculations();
    test__comma();
    test__bytes_to_hr();
    test__hr_to_bytes();
    test__ping_node();
    test__gather_node_details();
    test__get_rsa_public_key();
    test__get_hostname();
    test__remote_call();
    test__parse_hosts();
    test__parse_dmesg();
    test__parse_bonds();
    test__parse_vm_defs();
    test__parse_dmidecode();
    test__parse_meminfo();
    test__parse_proc_drbd();
    test__old_parse_drbd_status();
    test__parse_drbdadm_dumpxml();
    test__parse_clustat();
    test__parse_cluster_conf();
    test__parse_daemons();
    test__parse_lvm_scan();
    test__parse_lvm_data();
    test__parse_virsh();
    test__parse_gfs2();
    test__set_daemons();
    test__check_if_on();
    test__on_same_network();
    test__write_node_cache();
    test__read_node_cache();

}

main();

done_testing();
