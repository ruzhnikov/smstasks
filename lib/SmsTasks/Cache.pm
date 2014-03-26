package SmsTasks::Cache;

use strict;
use warnings;
use 5.008009;

use Redis::Fast;

use base qw/ SmsTasks::Cache::Queries /;

sub new {
    my $class = shift;

    my $self = {};
    bless $self, $class;

    $self->_init;

    return $self;
}

sub _init {
    my ( $self ) = @_;

    $self->{redis} = Redis::Fast->new;
}

sub r {
    my ( $self ) = @_;

    $self->{redis} ||= Redis::Fast->new;

    return $self->{redis};
}

1;