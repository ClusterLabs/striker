package AN::DBS;

# _Perl_
use warnings;
use strict;
use 5.010;

use version;
our $VERSION = '0.0.1';

use English '-no_match_vars';
use Carp;

use File::Basename;

use FindBin qw($Bin);
use Const::Fast;
use DBI;

use AN::Common;
use AN::OneDB;
use AN::OneAlert;
use AN::Listener;

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
const my $ASSIGN      => q{=};
const my $DOUBLECOLON => q{::};
const my $DB          => q{db};
const my $PROG        => ( fileparse($PROGRAM_NAME) )[0];

# ======================================================================
# Subroutines
#

# ......................................................................
# Private Methods
#
sub is_pw_field {
    return 1 <= scalar @_
        && $_[0] eq 'password';
}

sub add_db {
    my $self = shift;
    my ($db) = @_;

    push @{ $self->dbs() }, $db;
    return;
}

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

# ......................................................................
# Methods
#

sub connect_dbs {
    my $self = shift;

    my %cfg = ( path => $self->path );
    AN::Common::read_configuration_file( \%cfg );

    $self->dbconf( $cfg{db} );
    $self->maxN( scalar keys %{ $cfg{db} } );    # Number of DB in dbconf

    $self->dbs( [] );
    my ( $idx, $connect_flag, $failedN ) = ( 0, 1, 0 );

    # $self->current is automatically incremented when connection
    # fails.
    for my $tag ( sort keys %{ $self->dbconf } ) {
        $connect_flag = ( $idx++ == $self->current )
            if defined $self->current;

        my $onedb = AN::OneDB->new(
                                    { dbconf    => $self->dbconf->{$tag},
                                      node_args => $self->node_args,
                                      connect   => $connect_flag,
                                      owner     => $self,
                                      logdir    => $self->logdir,
                                    } );

        # If connection failed, replace with an inactive instance, and increment
        # pointer to current index.
        if ( $connect_flag && !ref $onedb->dbh ) {
            $onedb = AN::OneDB->new(
                                     { dbconf    => $self->dbconf->{$tag},
                                       node_args => $self->node_args,
                                       owner     => $self,
                                       logdir    => $self->logdir,
                                     } );
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
    die "Failed to connect to any DB, $failedN failures out of",
        "@{[$self->maxN]} attempts."
        if $failedN == $self->maxN;

    return;
}

sub load_db_from_files {
    my $self = shift;

    for my $db ( @{ $self->dbs } ) {
        $db->load_db_from_file
            if $db->connected();
    }
    return;
}

sub switch_next_db {
    my $self = shift;
    return unless defined $self->current;

    warn __PACKAGE__, "::switch_next_db(): Restarting!!\n",
        "called from ", join ' ', caller;
    $self->owner->restart;
    return;
}

sub finalize_node_table_status {
    my $self = shift;

    for my $db ( @{ $self->dbs() } ) {
        $db->finalize_node_table_status()
            if $db->connected();
    }
    return;
}

sub tell_db_Im_dying {
    my $self = shift;

    for my $db ( @{ $self->dbs() } ) {
        $db->startup()
            unless $db->connected();
        $db->tell_db_Im_dying();
    }
    return;
}

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

sub fetch_data {
    my $self = shift;
    my ($proc_info) = @_;

    my $number_of_db_attempted = 0;
    my $current_db             = $self->dbs()->[ $self->current ];
    if ( $self->verbose ) {
        state $debug = grep {/debug DBS fetch_data/} $ENV{VERBOSE} || '';
        my $cdb = $current_db;
        if ($debug) {
            warn "\$current_db is undef" unless defined $cdb;
            warn "\$current_db is not a OneDB." unless 'AN::ONeDB' eq ref $cdb;
            warn "current db # is @{[$self->current()]}; scalar ->dbs() is ",
                scalar @{ $self->dbs() };
            warn "\$current_db->dbconf is undef" unless defined $cdb->dbconf;
            warn "\$current_db->dbconf is not a hashref."
                unless 'HASH' eq ref $cdb->dbconf;
            warn "$current_db dbh isa ", ref $self->dbh, "\n";
        }
        say "DBS::fetch_alert_data reading from @{[$cdb->dbconf->{host}]}.";
    }
    my $db_data = $current_db->fetch_alert_data($proc_info);

    while (   !$db_data
            && $self->switched_to_new_db ) {

        warn "fetch_data() failed and switched to new db.\n";
        warn "self is '$self'.";
        my $maxN = $self->maxN;
        die "Failed query with all $maxN DBs.\n"
            if ++$$number_of_db_attempted == $maxN;

        $self->switched_to_new_db(0);
        $current_db = $self->dbs()->[ $self->current ];
        $db_data    = $current_db->fetch_alert_data($proc_info);
    }
    return $db_data;
}

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

        next ENTRY
            if (
            $seen{ $entry->{agent_name} }                   # older instance?
            && ( $entry->{age} > $seen{ $entry->{agent_name} } ) );
        $seen{ $entry->{agent_name} }{age}
            = $entry->{age};    # archive instance's age

        $nodes{ $entry->{agent_name} }{node_id} = $entry->{node_id};
    }
    return \%nodes;
}

sub fetch_alert_listeners {
    my $self = shift;
    my ($owner) = @_;

    my $db = $self->dbs()->[ $self->current ];

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

    # Add a default HealthMonitor if there isn't a customized one
    # already specified.
    #
    push @{$listeners},
        AN::Listener->new(
                           { added_by     => 0,
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
                           } )
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

     Scanner.pm - System monitoring loop

=head1 VERSION

This document describes Scanner.pm version 0.0.1

=head1 SYNOPSIS

    use AN::Scanner;
    my $scanner = AN::Scanner->new();


=head1 DESCRIPTION

This module provides the Scanner program implementation. It monitors a
HA system to ensure the system is working properly.

=head1 METHODS

An object of this class represents a scanner object.

=over 4

=item B<new>

The constructor takes a hash reference or a list of scalars as key =>
value pairs. The key list must include :

=over 4

=item B<agentdir>

The directory that is scanned for scanning plug-ins.

=item B<rate>

How often the loop should scan.

=back


=back

=head1 DEPENDENCIES

=over 4

=item B<English> I<core>

Provides meaningful names for Perl 'punctuation' variables.

=item B<version> I<core since 5.9.0>

Parses version strings.

=item B<File::Basename> I<core>

Parses paths and file suffixes.

=item B<FileHandle> I<code>

Provides access to FileHandle / IO::* attributes.

=item B<FindBin> I<core>

Determine which directory contains the current program.

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

