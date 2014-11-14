#!/usr/bin/env perl

use Test::More;

use lib '../cgi-bin/lib/';
use AN::InstallManifest;


# ......................................................................
#
sub test__run_new_install_manifest {

}


# ......................................................................
#
sub test__install_programs {

}

# ......................................................................
#
sub test__install_missing_packages {

}

# ......................................................................
#
sub test__get_installed_package_list {

}

# ......................................................................
#
sub test__add_an_repo {

}

# ......................................................................
#
sub test__add_an_repo_to_node {

}

# ......................................................................
#
sub test__update_nodes {

}

# ......................................................................
#
sub test__update_node {

}

# ......................................................................
#
sub test__verify_internet_access {

}

# ......................................................................
#
sub test__ping_website {

}

# ......................................................................
#
sub test__verify_matching_free_space {

}

# ......................................................................
#
sub test__get_partition_data {

}

# ......................................................................
#
sub test__verify_node_is_not_in_a_cluster {

}

# ......................................................................
#
sub test__read_cluster_conf {

}

# ......................................................................
#
sub test__verify_os {

}

# ......................................................................
#
sub test__get_node_os_version {

}

# ......................................................................
#
sub test__check_connection {

}

# ......................................................................
#
sub test__check_node_access {

}

sub main {
    test__run_new_install_manifest();
    test__install_programs();
    test__install_missing_packages();
    test__get_installed_package_list();
    test__add_an_repo();
    test__add_an_repo_to_node();
    test__update_nodes();
    test__update_node();
    test__verify_internet_access();
    test__ping_website();
    test__verify_matching_free_space();
    test__get_partition_data();
    test__verify_node_is_not_in_a_cluster();
    test__read_cluster_conf();
    test__verify_os();
    test__get_node_os_version();
    test__check_connection();
    test__check_node_access();
}

main();

done_testing();
