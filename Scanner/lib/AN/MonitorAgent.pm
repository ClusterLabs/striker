package AN::MonitorAgent;

# _Perl_
use warnings;
use strict;
use 5.014;

our $VERSION = 1.0;

use English '-no_match_vars';
use File::Basename;
use FileHandle;

use FindBin qw($Bin);
use Time::HiRes qw( time alarm sleep );
use DBI;

use Const::Fast;

## no critic ( ControlStructures::ProhibitPostfixControls )
## no critic ( ProhibitMagicNumbers )
# ======================================================================
# CONSTANTS
#
const my $BRIEF               => 1;
const my $COMMA               => q{,};
const my $DOTSLASH            => q{./};
const my $LIFETIME            => 24 * 60 * 60;
const my $MAX_RATE            => 600;
const my $MIN_RATE            => 1;
const my $PROG                => (fileparse( $PROGRAM_NAME ))[0];
const my $REP_RATE            => 30;
const my $SLASH               => q{/};
const my $SUFFIX_QR           => qr{         # regex to extract filename suffix
                                       [.]   # starts with a literal dot
                                       [^.]+ # sequence of non-dot characters
                                       \z    # continuing until end of string
                                   }xms;
const my $TIMED_OUT_ALARM_MSG => 'alarm timed out';
const my $VERBOSE             => 2;

## use critic ( ProhibitMagicNumbers )
# ======================================================================
# Methods
#
# ......................................................................
# Standard constructor. In subclasses, 'inherit' this constructor, but
# write a new _init()
#
sub new {
    my ( $class, @args ) = @_;

    my $obj = bless {}, $class;

    $obj->_init(@args);
    
    return $obj;
}

# ......................................................................
#
sub _init {
    my $self = shift;
    my ( @args ) = @_;

    if ( scalar @args > 1 ) {
        for my $i ( 0 .. $#args ) {
            my ( $k, $v ) = ( $args[$i], $args[ $i + 1 ] );
            $self->{$k} = $v;
        }
    }
    elsif ( 'HASH' eq ref $args[0] ) {
        @{$self}{ keys %{ $args[0] } } = values %{ $args[0] };
    }
    
    $self->_set_defaults();
    $self->_verify_args();

    return;
}


# ......................................................................
# set values that were not set on call
#
sub _set_defaults {
    my $self = shift;

    # loop repetition rate in seconds.
    #
    $self->rate($REP_RATE)            unless  $self->rate();

    # How long should one process live?
    #
    $self->duration( $LIFETIME )      unless  $self->duration();
    
    # directory to scan.
    #
    $self->agentdir($Bin . '/agents') unless  $self->agentdir();

    # print strings for no change?
    #
    $self->verbose(0)                 unless  $self->verbose();
        
    # ignore files with these suffixes.
    #
    $self->ignore( [qw( .conf .rc .init )]) unless $self->ignore();

    
    # If agentdir is relative path './xxx', convert to fully qualified
    # relative to location of this script.
    #
    $self->agentdir( $Bin . $SLASH . substr $self->agentdir(), 2 )
      if 0 == index $self->agentdir(), $DOTSLASH;

    # Separate CSV values into separate arg elements.
    #
    $self->ignore( [ split $COMMA, join $COMMA, @{ $self->{ignore} } ]);

    return;
}

# ......................................................................
# Check command line argument validity
#
sub _verify_args {
    my $self = shift;

    local $LIST_SEPARATOR = $COMMA;
    
    pod2usage(
        -verbose => $BRIEF,
        -message => "rate '$self->rate()' < $MIN_RATE"
    ) if $self->rate() < $MIN_RATE;

    pod2usage(
        -verbose => $BRIEF,
        -message => "rate '$self->rate()' > $MAX_RATE"
    ) if $self->rate() > $MAX_RATE;

    pod2usage(
        -verbose => $BRIEF,
        -message => "agentdir '$self->agentdir()' not found"
    ) unless -e $self->agentdir();
    pod2usage(
        -verbose => $BRIEF,
        -message => "Cannot read agentdir '$self->agentdir()'"
    ) unless -r $self->agentdir();
    pod2usage(
        -verbose => $BRIEF,
        -message => "Cannot execute agentdir '$self->agentdir()'"
    ) unless -x $self->agentdir();

    pod2usage(
        -verbose => $BRIEF,
        -message =>
          "Total life '$self->duration()' < repetition rate $self->rate()"
    ) if $self->duration() <= $self->rate();

    pod2usage(
        -verbose => $BRIEF,
        -message =>
          "Illegal character '/' in suffix ignore list '$self->ignore()'"
      ) if scalar grep { m{/}xms } $self->ignore();

    return;
}

# ......................................................................
# accessor
#
sub agentdir {
    my $self = shift;
    my ( $new_value ) = @_;

    return $self->{agentdir} if not defined $new_value;

    $self->{agentdir} = $new_value;
    return;
}

sub core {
    my $self = shift;
    my ( $new_value ) = @_;

    return $self->{core} if not defined $new_value;

    $self->{core} = $new_value;
    return;
}

sub rate {
    my $self = shift;
    my ( $new_value ) = @_;

    return $self->{rate} if not defined $new_value;

    $self->{rate} = $new_value;
    return;
}

sub duration {
    my $self = shift;
    my ( $new_value ) = @_;

    return $self->{duration} if not defined $new_value;

    $self->{duration} = $new_value;
    return;
}

sub verbose {
    my $self = shift;
    my ( $new_value ) = @_;

    return $self->{verbose} if not defined $new_value;

    $self->{verbose} = $new_value;
    return;
}

sub ignore {
    my $self = shift;
    my ( $new_value ) = @_;

    return $self->{ignore} if not defined $new_value;

    $self->{ignore} = $new_value;
    return;
}

# ......................................................................
# Scan files in the directory, comparing against a persistent list
# return list of additions and deletions. Ignore specified suffixes.
#
sub scan_files {
    my $self = shift;

    # If any suffixes are specified in 'ignore', turn them
    # into keys in a persistent hash. Use '1' as the value for the key,
    # value is never used. only do the expansion the first time through.
    #
    state $ignore;
    @{$ignore}{ @{$self->ignore()} } = (1) x scalar @{ $self->ignore() }
      if ( not $ignore ) && scalar @{ $self->ignore() };

    # Persistent list of files. Reset associated values to zero. During
    # scan, update value to 1. At end, any file names with a value of
    # zero have been removed, and so value has not been update.
    #
    state %files;
    @files{ keys %files } = (0) x scalar keys %files;

    my (@added);
  FILE:
    for my $file ( glob $self->agentdir() . "/*" ) {
        my ( $name, $dir, $suffix ) = fileparse( $file, $SUFFIX_QR );
        next FILE
          if $suffix and exists $ignore->{$suffix};
        my $fullname = $suffix ? $name . $suffix : $name;
        push @added, $fullname
          unless exists $files{$fullname};
        $files{$fullname} = 1;    # mark as present
    }

    # detect and drop deleted files
    #
    my (@dropped) =
      sort grep { 0 == $files{$_} } keys %files;    # file keys with zero value.
    delete @files{@dropped};

    @added = sort @added;
    return ( \@added, \@dropped );
}

# ......................................................................
# run a loop once every 'rate' seconds, to check 'agentdir' for new
# files, ignoring files with a suffix listed in 'ignore'
#
sub run_timed_loop {
    my $self = shift;

    my ($start_time) = time;
    my ($end_time)   = $start_time + $self->duration();
    my ($now)        = $start_time;

    while ( $now < $end_time ) {    # loop until this time tomorrow
        my ( $new, $deleted ) = $self->scan_files();
        local $LIST_SEPARATOR = $COMMA;

        my ($elapsed) = time - $now;
        my $pending = $self->rate() - $elapsed;

        my $extra_arg = (
            $self->showsleep()
            ? sprintf '%7.3f:%7.3f mSec', 1000 * $elapsed, 1000 * $pending
            : q{}
        );
        say "$PROG @{[time]} [@{$new}], [@{$deleted}]$extra_arg."
          if $self->verbose()
          or @{$new}
          or @{$deleted};

        sleep $pending;
        $now = time;
    }
    return;
}

# ----------------------------------------------------------------------
# Main code
#

sub main {
    say "Starting $PROGRAM_NAME at @{[ scalar localtime()]}.";
#    my $options = process_args();

#    run_timed_loop $options;

    say "Halting $PROGRAM_NAME at @{[ scalar localtime()]}.";
    return;
}

# ----------------------------------------------------------------------
# Now invoke main()

#STDOUT->autoflush();
#main();

1;

__END__
# ======================================================================
# POD

__END__

=head1 NAME

     scan_for_agents - Check agents dir for added or removed files.

=head1 SYNOPSIS

     scan_for_agents [options]

     Options:
         -duration N         How long the program should run before
                             spawning a replacement. Default value
                             is 24 hrs, or 86400 seconds.
         -rate     N         How often test is performed, by default
                             every 30 seconds.
         -agentdir <path>    Which directory to check, by default
                             the 'agents directory next to this program.
         -ignore   .conf,.rc Files with these suffixes will be ignored.
         -help               Brief help message.
         -man                Full documentation.

=head1 OPTIONS

=over 4

=item B<-rate N>

How often loop is run, in seconds. Must be one or greater; larger than
600 is considered an error.

=item B<-agentdir path>

Path to the directory to be scanned for additions and removals.

=item B<-ignore .conf,.rc,.init>

Ignore filenames with these suffixes. These additional files are meant
to provide configuration data for the code files. A CSV list can be
provided, or else multiple calls to the same command-line argument
invoked, in the more verbose format:

    -ignore .conf  -ignore .rc  -ignore .init

By default, .conf, .rc and .init files are ignored. But the default
list is discarded if the user specifies any -ignore options. So if you
want to add to the default list, rather than replace it, you will need
to include '.conf,.rc,.init' in your ignore list.

=item B<duration N>

How long should the program run, before spawning a fresh replacement?
Typically 24 hours, i.e. 86400 seconds.

=item B<-verbose>

Output a message even if no files have been added or deleted.

=item B<showsleep>

Adds a component to the output string showing the duration of
processing, and the amount of time that will be spent sleeping before
the next iteration. =item B<-help>

Print a brief help message and exits.

=item B<-help>

Prints guide to command line arguments.

=item B<-man>

Prints the manual page and exits.

=back

=head1 DESCRIPTION

B<scan_for_agents> is one of scanning agents for the scan-core
program. It checks the specified directory for files that have been
added or removed.

When the program begins to run, it outputs a message, 

C<Starting ./scan_for_agents at Sat Nov  1 23:53:51 2014.>

to report the program being run, and the start time.

Similarly when the program terminates because the run duration has
expired, a similar message is output:

C<Halting ./scan_for_agents at Sat Nov  1 23:59:46 2014.>

Immediately after the start message, the first scan is performed. A
sample output string looks like:

C<scan_for_agents 1414898302.50597 [abc,xyz,zyx], [] 0.290:29999.710 mSec.>

Where

C<scan_for_agents> is the program name,

C<1414898302.50597> is the Unix time(), i.e. Sat Nov  1 23:18:22 2014,

C<[abc,xyz,zyx]> are files added since the previous scan,

C<[]> indicates no files deleted,

C<0.290:29999.710 mSec> indicates it took 0.290 milli-seconds (290
microseconds) to scan the directory, and there are 29999.710
milli-seconds to sleep till the next iteration.

The scan time and time to sleep are only displayed if the -showsleep
option was specified.

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

=head1 DEPENDENCIES

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

