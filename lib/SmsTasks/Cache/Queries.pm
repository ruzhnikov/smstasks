package SmsTasks::Cache::Queries;

use strict;
use warnings;
use 5.008009;

use constant {
    TASKS_DBINDEX       => 2,
    NUMBERS_DBINDEX     => 3,
};

use constant DATA_NUMBER_FIELDS  => qw/ push_id number uid /;

use base qw/ SmsTasks::Cache::BaseQueries /;

our $VERSION = $SmsTasks::Cache::BaseQueries::VERSION;

sub set_task_data {
    my ( $self, $task_id, $data ) = @_;

    return unless ( $task_id && $data && $data->{number_id} );

    my $number_id = delete $data->{number_id};

    $self->select( TASKS_DBINDEX );
    $self->hset( $task_id, $number_id, 1 );

    return 1 if ( scalar keys %{ $data } == 0 );

    $self->select( NUMBERS_DBINDEX );
    for my $field ( DATA_NUMBER_FIELDS ) {
        $self->hset( $number_id, $field, $data->{$field} ) if ( $data->{$field} );
    }

    return 1;
}

sub get_task_data {
    my ( $self, $task_id, $number_id ) = @_;

    $self->select( TASKS_DBINDEX );
    return unless ( $task_id && $self->exists( key => $task_id ) );

    if ( $number_id ) { # получить данные только по одному ключу
        return $self->_get_task_data_by_number_id( $number_id )
    }
    else { # получить данные по всем ключам
        return $self->_get_task_keys( $task_id );
    }
}

sub _get_task_data_by_number_id {
    my ( $self, $number_id ) = @_;

    $self->select( NUMBERS_DBINDEX );
    return unless ( $number_id && $self->exists( key => $number_id ) );

    my $number_id_data;
    my @number_id_keys = $self->hkeys( $number_id );

    for my $key ( @number_id_keys ) {
        $number_id_data->{$key} = $self->hget( $number_id, $key );
    }

    return $number_id_data;
}

sub _get_task_keys {
    my ( $self, $task_id ) = @_;

    return unless ( $task_id );

    $self->select( TASKS_DBINDEX );

    my @task_keys = $self->hkeys( $task_id );
    for my $i ( 0..$#task_keys ) {
        delete $task_keys[ $i ] if ( $task_keys[ $i ] eq 'status' );
    }

    return @task_keys;
}

sub del_task_data {
    my ( $self, $task_id, $number_id ) = @_;

    return unless ( $task_id );

    if ( $number_id ) {
        $self->select( TASKS_DBINDEX );
        $self->hdel( $task_id, $number_id );

        $self->select( NUMBERS_DBINDEX );
        $self->del( key => $number_id );
    }
    else {
        $self->select( TASKS_DBINDEX );
        $self->del( key => $task_id );
    }

    return 1;
}

sub get_tasks_count {
    my ( $self ) = @_;

    $self->select( TASKS_DBINDEX );
    return $self->dbsize;
}

sub get_tasks {
    my ( $self ) = @_;

    $self->select( TASKS_DBINDEX );
    return $self->keys;
}

sub get_task_data_count {
    my ( $self, $task_id ) = @_;

    return 0 unless ( $task_id );

    my @task_data = $self->_get_task_keys( $task_id );

    return scalar keys @task_data;
}

sub set_task_status {
    my ( $self, $task_id, $status ) = @_;

    $status ||= 'running';

    return unless ( $task_id );

    $self->select( TASKS_DBINDEX );
    return $self->hset( $task_id, 'status', $status );
}

sub task_exists {
    my ( $self, $task_id ) = @_;

    return unless ( $task_id );

    $self->select( TASKS_DBINDEX );
    return $self->exists( key => $task_id );
}

sub clear {
    my ( $self ) = @_;

    $self->select( TASKS_DBINDEX );
    $self->flushdb;

    $self->select( NUMBERS_DBINDEX );
    $self->flushdb;

    return 1;
}

1;