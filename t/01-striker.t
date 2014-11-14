#!/usr/bin/env perl

use Test::More;

use lib '../cgi-bin/lib/';
use AN::Striker;

sub test__get_peer_node {
  my $conf = {cgi => { cluster => 'test_cluster' },
	      clusters => {test_cluster => {nodes => ['abc','xyz'] }}
	     };

  is( 'xyz', AN::Cdb::get_peer_node( $conf, 'abc' ),
      qq{finds peer for 'abc'});
  is( 'abc', AN::Cdb::get_peer_node( $conf, 'xyz' ),
      qq{finds peer for 'xyz'});
 TODO: {
    local $TODO = 'seeking missing node should fail.';
    is( 'abc', AN::Cdb::get_peer_node( $conf, 'Tom' ),
	qq{Seek missing node 'Tom'});
  }
 TODO: {
    todo_skip 'Testing error conditions results in hard_die()', 1;

  $conf->{clusters}{test_cluster}{nodes} = undef;
    my $result = eval{AN::Cdb::get_peer_node( $conf, 'abc' )};
    is( 'error msg', $result, qq{finds peer for 'abc'});
  }
}



# ......................................................................
#
sub test__get_peer_node {

}

# ......................................................................
#
sub test__process_task {

}

# ......................................................................
#
sub test__restart_tomcat {

}

# ......................................................................
#
sub test__call_restart_tomcat_guacd {

}

# ......................................................................
#
sub test__lsi_control_unmake_disk_as_hot_spare {

}

# ......................................................................
#
sub test__lsi_control_clear_foreign_state {

}

# ......................................................................
#
sub test__lsi_control_make_disk_hot_spare {

}

# ......................................................................
#
sub test__lsi_control_mark_disk_missing {

}

# ......................................................................
#
sub test__lsi_control_spin_disk_up {

}

# ......................................................................
#
sub test__lsi_control_spin_disk_down {

}

# ......................................................................
#
sub test__lsi_control_get_rebuild_progress {

}

# ......................................................................
#
sub test__lsi_control_put_disk_offline {

}

# ......................................................................
#
sub test__lsi_control_put_disk_online {

}

# ......................................................................
#
sub test__lsi_control_add_disk_to_array {

}

# ......................................................................
#
sub test__lsi_control_get_missing_disks {

}

# ......................................................................
#
sub test__lsi_control_make_disk_good {

}

# ......................................................................
#
sub test__lsi_control_disk_id_led {

}

# ......................................................................
#
sub test__display_node_health {

}

# ......................................................................
#
sub test__get_storage_data {

}

# ......................................................................
#
sub test__get_storage_data_lsi {

}

# ......................................................................
#
sub test__change_vm {

}

# ......................................................................
#
sub test__vm_insert_media {

}

# ......................................................................
#
sub test__vm_eject_media {

}

# ......................................................................
#
sub test__manage_vm {

}

# ......................................................................
#
sub test__switch_vm_xml_to_vnc {

}

# ......................................................................
#
sub test__update_guacamole_config {

}

# ......................................................................
#
sub test__get_current_vm_vnc_info {

}

# ......................................................................
#
sub test__read_live_xml {

}

# ......................................................................
#
sub test__find_node_storage_pool {

}

# ......................................................................
#
sub test__update_vm_definition {

}

# ......................................................................
#
sub test__add_vm_to_cluster {

}

# ......................................................................
#
sub test__find_vm_host {

}

# ......................................................................
#
sub test__provision_vm {

}

# ......................................................................
#
sub test__verify_vm_config {

}

# ......................................................................
#
sub test__confirm_provision_vm {

}

# ......................................................................
#
sub test__confirm_withdraw_node {

}

# ......................................................................
#
sub test__confirm_join_cluster {

}

# ......................................................................
#
sub test__confirm_dual_join {

}

# ......................................................................
#
sub test__confirm_fence_node {

}

# ......................................................................
#
sub test__confirm_poweroff_node {

}

# ......................................................................
#
sub test__confirm_poweron_node {

}

# ......................................................................
#
sub test__confirm_dual_boot {

}

# ......................................................................
#
sub test__confirm_start_vm {

}

# ......................................................................
#
sub test__confirm_stop_vm {

}

# ......................................................................
#
sub test__confirm_force_off_vm {

}

# ......................................................................
#
sub test__confirm_delete_vm {

}

# ......................................................................
#
sub test__confirm_migrate_vm {

}

# ......................................................................
#
sub test__start_vm {

}

# ......................................................................
#
sub test__parse_text_line {

}

# ......................................................................
#
sub test__migrate_vm {

}

# ......................................................................
#
sub test__stop_vm {

}

# ......................................................................
#
sub test__join_cluster {

}

# ......................................................................
#
sub test__dual_join {

}

# ......................................................................
#
sub test__force_off_vm {

}

# ......................................................................
#
sub test__delete_vm {

}

# ......................................................................
#
sub test__remove_vm_definition {

}

# ......................................................................
#
sub test__archive_file {

}

# ......................................................................
#
sub test__update_cluster_conf {

}

# ......................................................................
#
sub test__poweroff_node {

}

# ......................................................................
#
sub test__dual_boot {

}

# ......................................................................
#
sub test__poweron_node {

}

# ......................................................................
#
sub test__fence_node {

}

# ......................................................................
#
sub test__withdraw_node {

}

# ......................................................................
#
sub test__recover_rgmanager {

}

# ......................................................................
#
sub test__display_details {

}

# ......................................................................
#
sub test__display_free_resources {

}

# ......................................................................
#
sub test__long_host_name_to_node_name {

}

# ......................................................................
#
sub test__node_name_to_long_host_name {

}

# ......................................................................
#
sub test__display_vm_details {

}

# ......................................................................
#
sub test__check_node_daemons {

}

# ......................................................................
#
sub test__check_node_readiness {

}

# ......................................................................
#
sub test__read_vm_definition {

}

# ......................................................................
#
sub test__check_lv {

}

# ......................................................................
#
sub test__check_vms {

}

# ......................................................................
#
sub test__find_prefered_host {

}

# ......................................................................
#
sub test__set_node_names {

}

# ......................................................................
#
sub test__display_vm_state_and_controls {

}

# ......................................................................
#
sub test__display_drbd_details {

}

# ......................................................................
#
sub test__display_gfs2_details {

}

# ......................................................................
#
sub test__display_node_details {

}

# ......................................................................
#
sub test__display_node_controls {

}

sub main {
    test__get_peer_node();
    test__process_task();
    test__restart_tomcat();
    test__call_restart_tomcat_guacd();
    test__lsi_control_unmake_disk_as_hot_spare();
    test__lsi_control_clear_foreign_state();
    test__lsi_control_make_disk_hot_spare();
    test__lsi_control_mark_disk_missing();
    test__lsi_control_spin_disk_up();
    test__lsi_control_spin_disk_down();
    test__lsi_control_get_rebuild_progress();
    test__lsi_control_put_disk_offline();
    test__lsi_control_put_disk_online();
    test__lsi_control_add_disk_to_array();
    test__lsi_control_get_missing_disks();
    test__lsi_control_make_disk_good();
    test__lsi_control_disk_id_led();
    test__display_node_health();
    test__get_storage_data();
    test__get_storage_data_lsi();
    test__change_vm();
    test__vm_insert_media();
    test__vm_eject_media();
    test__manage_vm();
    test__switch_vm_xml_to_vnc();
    test__update_guacamole_config();
    test__get_current_vm_vnc_info();
    test__read_live_xml();
    test__find_node_storage_pool();
    test__update_vm_definition();
    test__add_vm_to_cluster();
    test__find_vm_host();
    test__provision_vm();
    test__verify_vm_config();
    test__confirm_provision_vm();
    test__confirm_withdraw_node();
    test__confirm_join_cluster();
    test__confirm_dual_join();
    test__confirm_fence_node();
    test__confirm_poweroff_node();
    test__confirm_poweron_node();
    test__confirm_dual_boot();
    test__confirm_start_vm();
    test__confirm_stop_vm();
    test__confirm_force_off_vm();
    test__confirm_delete_vm();
    test__confirm_migrate_vm();
    test__start_vm();
    test__parse_text_line();
    test__migrate_vm();
    test__stop_vm();
    test__join_cluster();
    test__dual_join();
    test__force_off_vm();
    test__delete_vm();
    test__remove_vm_definition();
    test__archive_file();
    test__update_cluster_conf();
    test__poweroff_node();
    test__dual_boot();
    test__poweron_node();
    test__fence_node();
    test__withdraw_node();
    test__recover_rgmanager();
    test__display_details();
    test__display_free_resources();
    test__long_host_name_to_node_name();
    test__node_name_to_long_host_name();
    test__display_vm_details();
    test__check_node_daemons();
    test__check_node_readiness();
    test__read_vm_definition();
    test__check_lv();
    test__check_vms();
    test__find_prefered_host();
    test__set_node_names();
    test__display_vm_state_and_controls();
    test__display_drbd_details();
    test__display_gfs2_details();
    test__display_node_details();
    test__display_node_controls();
}

main();

done_testing();
