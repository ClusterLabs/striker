package AN::DBS;

# _Perl_
use warnings;
use strict;
use 5.010;

use version;
our $VERSION = '1.0.0';

use Const::Fast;
use English '-no_match_vars';
use File::Basename;

use AN::Common;
use AN::OneDB;
use AN::OneAlert;
use AN::Listener;

# ======================================================================
# CLASS ATTRIBUTES & CONSTRUCTOR
#
use Class::Tiny qw( current dbconf  dbs     logdir    maxN    node_args
    owner   path    switched_to_new_db verbose );

sub BUILD {
    my $self = shift;
    my ($args) = @_;

    $self->node_args( $args->{node_args} )
        if exists $args->{node_args};
    $self->connect_dbs();
    $self->maxN( scalar @{ $self->dbs() } );
}

# ======================================================================
# CONSTANTS
#
const my $PROG => ( fileparse($PROGRAM_NAME) )[0];

# ======================================================================
# METHODS
#

# ----------------------------------------------------------------------
# Add a (OneDB) database object to the list in dbs.
#
sub add_db {
    my $self = shift;
    my ($db) = @_;

    push @{ $self->dbs() }, $db;
    return;
}

# ----------------------------------------------------------------------
# scanCore has the concept of a current database from which it is
# reading; agents leave it undef cause they want to write to all
# available databases. So don't do anything if $self->current is
# undef, but if it exists, restart the scanCore. Would like to
# swap DBs, but leads to too many complications.
#
sub increment_current {
    my $self = shift;

    return unless defined $self->current;

    $self->current( 1 + $self->current );
    if ( $self->current >= $self->maxN ) {
        warn __PACKAGE__, '::Increment_current ran out of DBS. Restarting!!';
        $self->owner->restart;
    }
    return;
}

# ----------------------------------------------------------------------
# Create connections to the databases, in the form of AN::OneDB objects.
#
# ->current() is descussed above, at ->increment_current().
#
sub connect_dbs {
    my $self = shift;

    # Read and archive config file containing info about database.
    #
    my %cfg = ( path => $self->path );
    AN::Common::read_configuration_file( \%cfg );
    $self->dbconf( $cfg{db} );
    $self->maxN( scalar keys %{ $cfg{db} } );    # Number of DB in dbconf

    $self->dbs( [] );
    my ( $idx, $connect_flag, $failedN ) = ( 0, 1, 0 );

    # $self->current is incremented when connection fails.
    #
    for my $tag ( sort keys %{ $self->dbconf } ) {
        $connect_flag = ( $idx++ == $self->current )
            if defined $self->current;

        my $onedb_args = { dbconf    => $self->dbconf->{$tag},
                           node_args => $self->node_args,
                           connect   => $connect_flag,
                           owner     => $self,
                           logdir    => $self->logdir, };
        my $onedb = AN::OneDB->new($onedb_args);

        # If connection failed, replace with an inactive instance, and
        # increment pointer to current index.
        #
        if ( $connect_flag && !ref $onedb->dbh ) {
            $onedb_args->{connect} = 0;
            $onedb = AN::OneDB->new($onedb_args);
            $self->increment_current;
            $failedN++;
        }
        else {    # Succeeded, report
            my $verb = defined $self->current ? 'reading from' : 'writing to';
            say "Program $PROG $verb DB '@{[$self->dbconf->{$tag}{host}]}'."
                if $connect_flag;
        }
        $self->add_db($onedb);
    }

    # Ran out of databases to try.
    #
    die "Failed to connect to any DB, $failedN failures out of",
        "@{[$self->maxN]} attempts."
        if $failedN == $self->maxN;

    return;
}

# ----------------------------------------------------------------------
# Called from AN::OneDB::fail_read, to handle a OneDB database
# communication failure. The program restarts and connects to another
# database.
#
sub switch_next_db {
    my $self = shift;
    return unless defined $self->current;

    warn __PACKAGE__, "::switch_next_db(): Restarting!!\n",
        "called from ", join ' ', caller;
    $self->owner->restart;
    return;
}

# ----------------------------------------------------------------------
# Update program status to 'halted'in node database record via OneDB.
#
sub finalize_node_table_status {
    my $self = shift;

    for my $db ( @{ $self->dbs() } ) {
        $db->finalize_node_table_status()
            if $db->connected();
    }
    return;
}

# ----------------------------------------------------------------------
# Create an alerts table record to indicate unexpected program failure.
#
sub tell_db_Im_dying {
    my $self = shift;

    for my $db ( @{ $self->dbs() } ) {
        $db->startup()
            unless $db->connected();
        $db->tell_db_Im_dying();
    }
    return;
}

# ----------------------------------------------------------------------
# Called from AN::Agent::dump_metadata() to report the node_id for each
# database with which we have a connection.
#
sub node_id {
    my $self = shift;
    my ( $prefix, $separator ) = @_;

    my ( $dbs, @ids ) = ( $self->dbs() );
DB:
    for my $idx ( 0 .. $#{$dbs} ) {
        next DB
            unless exists $dbs->[$idx]{node_table_id};
        push @ids,
              $prefix
            . ( $idx + 1 )
            . $separator
            . 'node_table_id='
            . $dbs->[$idx]{node_table_id};
    }
    return @ids;
}

# ----------------------------------------------------------------------
# Delegate to OneDB - Store raw variable data into database tables.
#
sub insert_raw_record {
    my $self = shift;
    my ($args) = @_;

    for my $db ( @{ $self->dbs() } ) {
        $db->insert_raw_record($args)
            or $db->insert_raw_record($args)    # retry
            or warn "Problem inserting record '"
            . Data::Dumper::Dumper( [$args] ), "' into '", $db->dbconf->{host},
            "'.";
    }
    return;
}

# ----------------------------------------------------------------------
# Delegate to OneDB - fetch records pertaining to enabling / disabling
# autoboot ( AUTO_BOOT), and to failed servers (NODE_SERVER_STATUS).
#
sub check_node_server_status {
    my $self = shift;
    my ($ns_host) = @_;

    my @results;
DB:
    for my $db ( @{ $self->dbs() } ) {
        next DB unless $db->connected();
        my $records = $db->check_node_server_status($ns_host);
        push @results, @$records
            if @$records;
    }
    return \@results;
}

# ----------------------------------------------------------------------
# Utility to print some debugging messages, if flags are set.
#
sub print_debug_msgs_re_current_db {
    my $self = shift;
    my ($cdb) = @_;

    state $debug = grep {/debug DBS fetch_data/} $ENV{VERBOSE} || '';

    if ($debug) {
        warn "\$current_db is undef" unless defined $cdb;
        warn "\$current_db is not a OneDB." unless 'AN::ONeDB' eq ref $cdb;
        warn "current db # is @{[$self->current()]}; scalar ->dbs() is ",
            scalar @{ $self->dbs() };
        warn "\$current_db->dbconf is undef" unless defined $cdb->dbconf;
        warn "\$current_db->dbconf is not a hashref."
            unless 'HASH' eq ref $cdb->dbconf;
        warn "\$current_db dbh isa ", ref $self->dbh, "\n";
    }
    say "DBS::fetch_alert_data reading from @{[$cdb->dbconf->{host}]}.";
    return;
}

# ----------------------------------------------------------------------
# Fetch data from alert table.
#
sub fetch_data {
    my $self = shift;
    my ($proc_info) = @_;

    my $current_db = $self->dbs()->[ $self->current ];

    $self->print_debug_msgs_re_current_db( $current_db )
        if $self->verbose;
    my $db_data = $current_db->fetch_alert_data($proc_info);

    return $db_data;
}

# ----------------------------------------------------------------------
# Fetch data from alert table and add fields about source data table.
#
sub fetch_alert_data {
    my $self = shift;
    my ($proc_info) = @_;

    my $alerts  = [];
    my $db_data = $self->fetch_data($proc_info);
    return unless 'HASH' eq ref $db_data;

    # Process newest first; Add info about source DB to alert record.
    #
    my $dbconf = $self->dbs()->[ $self->current ]->dbconf();

    for my $idx ( sort { $b <=> $a } keys %$db_data ) {
        my $record = $db_data->{$idx};
        @{$record}{qw(db db_type)} = ( @{$dbconf}{qw(host db_type)} );
        push @$alerts, AN::OneAlert->new($record);
    }
    return $alerts;
}

# ----------------------------------------------------------------------
# Fetch node table entries, keep only most recent entries for this host,
# for whatever agents are running.
#
sub fetch_node_entries {
    my $self = shift;
    my ($pids) = @_;

    my $nodes = $self->dbs()->[ $self->current ]->fetch_node_entries($pids);
    return unless 'ARRAY' eq ref $nodes;

    my %nodes;
    my $host = AN::Unix::hostname '-short';
    my %seen;
ENTRY:
    for my $entry (@$nodes) {
        next ENTRY unless $entry->{agent_host} eq $host;    # wrong host

        next ENTRY    # ignore older records
            if $seen{ $entry->{agent_name} }
            && $entry->{age} > $seen{ $entry->{agent_name} };

        # This one is newer, keep it for later
        #
        $seen{ $entry->{agent_name} }{age}      = $entry->{age};
        $nodes{ $entry->{agent_name} }{node_id} = $entry->{node_id};
    }
    return \%nodes;
}

# ----------------------------------------------------------------------
# Create a deault health_monitor lilstener. Invoked if custom version not
# specified in alert_listeners table.
#
sub create_health_monitor_listener {
    my $self = shift;
    my ( $db, $owner ) = @_;

    my $health_monitor = { added_by     => 0,
			   contact_info => '',
			   id           => 0,
			   language     => 'en_CA',
			   level        => 'WARNING',
			   mode         => 'HealthMonitor',
			   name         => 'Health Monitor',
			   update       => 'Jan 14 14:01:41 2015',
			   db           => $db->dbconf()->{host},
			   db_type      => $db->dbconf()->{db_type},
			   owner        => $owner,
    };
    my $hm = AN::Listener->new( $health_monitor );
    return $hm;
}

# ----------------------------------------------------------------------
# Fetch records from alert_listeners table. Add info about database
# from which they were read, and a link to the parent object, for
# access to weighted summary and for health montior to invoke
# shutdown.
#
sub fetch_alert_listeners {
    my $self = shift;
    my ($owner) = @_;

    my $db         = $self->dbs()->[ $self->current ];
    my $hlisteners = $db->fetch_alert_listeners();

    my $listeners = [];
    my $found_health_monitor;
    for my $idx ( sort keys %$hlisteners ) {
        my $data = $hlisteners->{$idx};
        $data->{db}      = $db->dbconf()->{host};
        $data->{db_type} = $db->dbconf()->{db_type};
        $data->{owner}   = $owner;
        push @{$listeners}, AN::Listener->new($data);

        $found_health_monitor++
            if $data->{mode} eq 'HealthMonitor';
    }

    # Add default HealthMonitor unless read Health Monitor record.
    #
    push @{$listeners}, $self->create_health_monitor_listener( $db, $owner )
        unless $found_health_monitor++;

    return $listeners;
}

# ----------------------------------------------------------------------
# end of code
1;
__END__

# ======================================================================
# POD

=head1 NAME

     DBS.pm - Interface between DB users and  multiple databases.

=head1 VERSION

This document describes AN::DBS.pm version 1.0.0

=head1 SYNOPSIS

    use AN::DBS;
    my $args = { path    => { config_file => $self->dbconf },
                 logdir  => $self->logdir,
                 verbose => $self->verbose,
                 owner   => $self, };
    $args->{current} = 0    # In scanner, activate only one DB at a time
        if $self->isa_scanner;
  
    my $dbs = AN::DBS->new();
    $dbs->insert_raw_record( $args );
    my $records = $dbs->fetch_alert_data($proc_info);
    my $node_ids = $dbs->fetch_node_entries( $pids );
    my $listeners = $dbs->fetch_alert_listeners( $owner );

    # set node table entry to 'halted'
    #
    $dbs->finalize_node_table_status();

    # create an alert to report server is shutting down.
    #
    $dbs->tell_db_Im_dying();

=head1 DESCRIPTION

This module provides the DBS object, an interface to multiple database
objects.

=head1 METHODS

The AN::DBS class provides access to database storage through the
following methods.

=over 4

=item B<insert_raw_record $args>

Store data into a specified table. Can store records into (one of ) an
agent's personal tables, or into the alerts table. Invoked with a
single hash argument, with the following fields:

=over 4

=item B<table database_table_name>

The name of the database table where the record is to be stored.

=item B<with_node_table_id 'node_id'>

The name of the field in the table which stores a foreign key to the
node table entry for the currently running process.

=item B<args record>

The actual data to be stored in the record. It takes the form of a
hash with the following fields:

=over 4

=item B<value string_or_number>

The core of the record, the variable being stored.

=item B<units string>

Units defining the meaning of the value, such as B<Volts>, B<Amps>,
B<degrees C>, etc.

=item B<field name>

The name of the variable with which this value is associated, such as
B<battery runtime remaining>.

=item B<status enum>

Interpretation of whether this value is normal, of concern, or critical.

=item B<message_tag tag>

A short text value which is looked up in a message file to access a
longer string in a specified language. Example:

     Value warning

=item B<message_arguments args>

Specific values which B<personalize> the message retrieved via the
message_tag. The B<message_arguments> stores a semi-colon delimited
set of B<key>=B<value> pairs. Example:

    value=75;controller=0

=back

=back


=item B<fetch_alert_data $proc_info>

Fetch all the records stored in the specified table in the past 60
seconds.

=item B<fetch_node_entries $pids>

Select from the node table records matching a list of specified PIDs.

=item B<fetch_alert_listeners $owner>

Fetch all records from the alert_listeners table, and augment by
adding a link to the invoking object. The owner is requested for the
weighted sum of all alerts, as well as being invoked by the Health
Monitor to shutdown the server.

=item B<finalize_node_table_status>

Set the node table entry for this process to 'halted'

=item B<tell_db_Im_dying>

Create a NODE_SERVER_STATUS record in the alerts table to indicate the
server is being shut down.

=back

=head1 DEPENDENCIES

=over 4

=item B<AN::Common>

=item B<AN::OneDB>

=item B<AN::OneAlert>

=item B<AN::Listener>

ScanCore utiliities and components. B<AN::Common> reads config files.
B<AN::OneDB> is the interface to a single database
instance. B<AN::OneAlert> is the object representation of an alert
table record. B<AN::Listener> obejects distribute messages once a loop
to listener.

=item B<Class::Tiny>

A simple OO framework. "Boilerplate is the root of all evil"

=item B<Const::Fast>

Provides fast constants.

=item B<English> I<core>

Provides meaningful names for Perl 'punctuation' variables.

=item B<File::Basename> I<core>

Parses paths and file suffixes.

=item B<version> I<core since 5.9.0>

Parses version strings.

=back

=head1 LICENSE AND COPYRIGHT

This program is part of Aleeve's Anvil! system, and is released under
the GNU GPL v2+ license.

=head1 BUGS AND LIMITATIONS

We don't yet know of any bugs or limitations. Report problems to 

    Alteeve's Niche!  -  https://alteeve.ca

No warranty is provided. Do not use this software unless you are
willing and able to take full liability for it's use. The authors take
care to prevent unexpected side effects when using this
program. However, no software is perfect and bugs may exist which
could lead to hangs or crashes in the program, in your cluster and
possibly even data loss.

=begin unused

=head1  INCOMPATIBILITIES

There are no current incompatabilities.


=head1 CONFIGURATION

=head1 EXIT STATUS

=head1 DIAGNOSTICS

=head1 REQUIRED ARGUMENTS

=head1 USAGE

=end unused

=head1 AUTHOR

Alteeve's Niche!  -  https://alteeve.ca

Tom Legrady       -  tom@alteeve.ca	November 2014

=cut

# End of File
# ======================================================================

