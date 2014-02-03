package SmsTasks::Log;

=head1 NAME

SmsTasks::Log

=cut

use strict;
use warnings;
use 5.008009;

use Log::Log4perl   qw/ :easy /;

sub new {
    my ( $class, %param ) = @_;

    $class = ref $class || $class;

    my $logfile = $param{logfile} ? $param{logfile} : '';

    my $self = bless {}, $class;
    $self->_init( $logfile );
}

sub _init {
    my ( $self, $logfile ) = @_;

    Log::Log4perl->easy_init( {
        level   => $DEBUG,
        file    => ">>$logfile",
    } );

    $self->{logger} = get_logger();

    return $self;
}

sub log {
    my ( $self, $message ) = @_;

    if ( $self->{logger} ) {
        $self->{logger}->info( $message );
    }

    return 1;
}

1;

=head1 DESCRIPTION

Класс для логгирования

=head1 AUTHOR

Alexander Ruzhnikov, C<< ruzhnikov85@gmail.com >>

=cut