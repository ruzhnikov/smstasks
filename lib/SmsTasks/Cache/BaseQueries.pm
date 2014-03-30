package SmsTasks::Cache::BaseQueries;

use strict;
use warnings;
use 5.008009;

our $VERSION = '0.10';

sub set {
    my ( $self, %param ) = @_;

    return if ( scalar keys %param == 0 );
    return unless ( $param{key} && $param{value} );

    my $key   = $param{key};
    my $value = $param{value};
    my $hash  = $param{hash};

    if ( $hash ) {
        return $self->r->hset( $hash, $key => $value );
    }
    else {
        return $self->r->set( $key => $value );
    }
}

sub hset {
    my ( $self, $hash, $key, $value ) = @_;

    return $self->set(
        hash  => $hash,
        key   => $key,
        value => $value,
    );
}

sub get {
    my ( $self, %param ) = @_;

    return if ( scalar keys %param == 0 );
    return unless ( $param{key} );

    my $key   = $param{key};
    my $hash  = $param{hash};

    if ( $hash ) {
        return $self->r->hget( $hash, $key );
    }
    else {
        return $self->r->get( $key );
    }
}

sub hget {
    my ( $self, $hash, $key ) = @_;

    return unless ( $hash && $key );
    return $self->get( hash => $hash, key => $key );
}

sub exists {
    my ( $self, %param ) = @_;

    return if ( scalar keys %param == 0 );
    return unless ( $param{key} );

    my $key   = $param{key};
    my $hash  = $param{hash};

    if ( $hash ) {
        return $self->r->hexists( $hash, $key );
    }
    else {
        return $self->r->exists( $key );
    }
}

sub hexists {
    my ( $self, $hash, $key ) = @_;

    return $self->exists( hash => $hash, key => $key );
}

sub flushdb {
    my ( $self ) = @_;

    return $self->r->flushdb;
}

sub del {
    my ( $self, %param ) = @_;

    return if ( scalar keys %param == 0 );
    return unless ( $param{key} );

    my $key   = $param{key};
    my $hash  = $param{hash};

    if ( $hash ) {
        return $self->r->hdel( $hash, $key );
    }
    else {
        return $self->r->del( $key );
    }
}

sub hdel {
    my ( $self, $hash, $key ) = @_;

    return unless ( $hash && $key );
    return $self->del( hash => $hash, key => $key );
}

sub hkeys {
    my ( $self, $hash ) = @_;

    return unless ( $hash );

    return $self->r->hkeys( $hash );
}

sub keys {
    my ( $self, $regexp ) = @_;

    $regexp ||= '*';

    return $self->r->keys( $regexp );
}

sub dbsize {
    my ( $self ) = @_;

    return $self->r->dbsize;
}

sub select {
    my ( $self, $dbindex ) = @_;

    return unless ( $dbindex );
    return $self->r->select( $dbindex );
}

1;