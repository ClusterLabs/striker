#!/usr/bin/env perl

use Test::More;

use lib '../cgi-bin/lib/';
use AN::MediaLibrary;

# ......................................................................
#
sub test__process_task {

}
# ......................................................................
#
sub test__download_url {

}
# ......................................................................
#
sub test__confirm_download_url {

}
# ......................................................................
#
sub test__save_file_to_disk {

}
# ......................................................................
#
sub test__image_and_upload {

}
# ......................................................................
#
sub test__upload_to_shared {

}
# ......................................................................
#
sub test__confirm_image_and_upload {

}
# ......................................................................
#
sub test__confirm_delete_file {

}
# ......................................................................
#
sub test__delete_file {

}
# ......................................................................
#
sub test__check_local_dvd {

}
# ......................................................................
#
sub test__check_status {

}
# ......................................................................
#
sub test__read_shared {

}

sub main {
    test__process_task();
    test__download_url();
    test__confirm_download_url();
    test__save_file_to_disk();
    test__image_and_upload();
    test__upload_to_shared();
    test__confirm_image_and_upload();
    test__confirm_delete_file();
    test__delete_file();
    test__check_local_dvd();
    test__check_status();
    test__read_shared();

}

main();

done_testing();
