package SmsTasks::Cache;

use strict;
use warnings;
use 5.008009;

use Carp qw/ confess /;
use Cache::Memcached::Fast;

use constant {
    SERVER  => '127.0.0.1:11211',
};

sub new {
    my $class = shift;

    bless {}, $class;
}

sub init {
    my ( $self ) = @_;

    # проверить, подключился или нет
    my $version = $self->memd->server_versions;
    confess "can't connect to memcached" if ( scalar keys %{ $version } == 0 );
}

sub memd {
    my ( $self ) = @_;

    $self->{memd} ||= Cache::Memcached::Fast->new( {
        servers => [ { address => SERVER, weight => 2.5 } ],
        namespace => 'smstasks:',
        close_on_error => 1,
        compress_threshold => 100_000,
        compress_ratio => 0.8,
        max_failures => 3,
        failure_timeout => 2,
        nowait => 0,
        utf8 => 1,
    } );

    return $self->{memd};
}

sub set {
    my ( $self, $key, $value ) = @_;

    return unless ( $key && $value );
    return $self->memd->set( $key, $value );
}

sub get {
    my ( $self, $key ) = @_;

    return unless ( $key );
    return $self->memd->get( $key );
}

sub del {
    my ( $self, $key ) = @_;

    return unless ( $key );
    return $self->memd->delete( $key );
}

1;