package SmsTasks::Utils;

use 5.008009;
use strict;
use warnings;

use POSIX   qw/ strftime /;
use Date::Parse qw/ str2time /;

=head1 METHODS

=over

=item B<get_now>

Get current date and time

=cut

sub get_now {

    return strftime "%Y:%m:%d %H:%M:%S", localtime(time);
}

=item B<check_run_time>( $time_start, $time_end )

Adjudged whether the current time in a specified interval

=cut

sub check_run_time {
    my ( $time_start, $time_end ) = @_;

    return unless ( $time_start && $time_end );

    my $year = (localtime(time))[5];
    my $mon  = (localtime(time))[4];
    my $mday = (localtime(time))[3];

    $mon += 1;
    $year += 1900;

    my $date_start = $year . ':' . $mon . ':' . $mday . ' ' . $time_start;
    my $date_end   = $year . ':' . $mon . ':' . $mday . ' ' . $time_end;

    if ( time > str2time( $date_start ) && time < str2time( $date_end ) ) {
        return 1;
    }

    return;
}

1;

=back

head1 DESCRIPTION

additional functions

=head1 AUTHOR

Alexander Ruzhnikov, C<< ruzhnikov85@gmail.com >>

=cut