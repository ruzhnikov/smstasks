#!/usr/bin/perl

use strict;
use warnings;
use 5.008009;

use Test::More  tests => 101;
use FindBin qw/ $Bin /;
use lib "$Bin/../lib";

use constant {
    ITER    => 4,
};

use constant DATA_NUMBER_FIELDS  => qw/ push_id number uid /;

use SmsTasks::Cache::Queries;

require_ok( 'SmsTasks::Cache' );

my $redis = SmsTasks::Cache->new;

ok( $redis->clear, 'clear db' );
is( $redis->dbsize, '0', 'db empty' );

my @number_ids  = ();

# сначала просто task_id && number_id
for my $i ( 1 .. ITER ) {
    my $hash = 'key' . $i;
    my $number_id = get_data();
    push @number_ids, $number_id;

    ok( $redis->set_task_data( $hash, { number_id => $number_id } ), 'set number_id for hash ' . $hash );
    ok( $redis->set_task_status( $hash ), 'set task status' );
}

is( $redis->get_tasks_count, '4', 'get tasks count' );

for my $i ( 1 .. ITER ) {
    my $hash = 'key' . $i;
    my $number_id = $number_ids[ $i - 1 ];

    ok( $redis->task_exists( $hash ), 'task ' . $hash . ' exists' );
    is( $redis->get_task_data_count( $hash ), '1', 'task data count = 1' );

    my @data1 = $redis->_get_task_keys( $hash );
    is( $data1[0], $number_id, 'get data for ' . $hash . ' from _get_task_keys' );

    my @data2 = $redis->get_task_data( $hash );
    is( $data2[0], $data1[0], 'get data for ' . $hash . ' from get_task_data');

    ok( $redis->del_task_data( $hash ), 'del task ' . $hash );
}

is( $redis->get_tasks_count, 0, 'get tasks count' );

@number_ids  = ();

# теперь наполняем данными базу с number_id
for my $i ( 1 .. ITER ) {
    my $hash = 'key' . $i;
    my $number_id = get_data();
    push @number_ids, $number_id;

    ok( $redis->set_task_status( $hash ), 'set task status' );
    ok( $redis->set_task_data( $hash, {
            number_id   => $number_id,
            push_id     => get_data( 'push_id' ),
            number      => get_data( 'number' ),
            uid         => get_data( 'uid' ),
        } ), 'set task data with number_id ' . $number_id
    );
}

is( $redis->get_tasks_count, '4', 'get tasks count' );

ok( $redis->select( SmsTasks::Cache::Queries::NUMBERS_DBINDEX ), 'select number_ids db' );
is( $redis->keys, ITER, 'get number_ids count' );

for my $i ( 1 .. ITER ) {
    my $hash = 'key' . $i;
    my $number_id = $number_ids[ $i - 1 ];
    
    ok( $redis->task_exists( $hash ), 'task ' . $hash . ' exists' );

    my $numbers_data = $redis->_get_task_data_by_number_id( $number_id );
    is( ref $numbers_data, 'HASH', 'ref data' );
    is( scalar keys %{ $numbers_data }, 3, 'count numbers data' );

    for my $key ( DATA_NUMBER_FIELDS ) {
        ok( $numbers_data->{ $key }, 'keys numbers data' );
    }

    $numbers_data = undef;
    $numbers_data = $redis->get_task_data( $hash, $number_id );

    is( ref $numbers_data, 'HASH', 'ref data' );
    is( scalar keys %{ $numbers_data }, 3, 'count numbers data' );

    for my $key ( DATA_NUMBER_FIELDS ) {
        ok( $numbers_data->{ $key }, 'keys numbers data' );
    }

    ok( $redis->del_task_data( $hash, $number_id ), 'del number_id data' );

    $redis->select( SmsTasks::Cache::Queries::NUMBERS_DBINDEX );
    ok( !$redis->exists( key => $number_id ), 'number_id ' . $number_id . ' hash will be deleted' );

    $redis->select( SmsTasks::Cache::Queries::TASKS_DBINDEX );
    ok( $redis->exists( key => $hash ), 'hash ' . $hash . ' exists' );
}

ok( $redis->clear, 'clear db' );

sub get_data {
    my ( $key ) = shift;

    if ( $key && $key eq 'number' ) {
        return '89994353' . int(rand(50));
    }
    else {
        return int(rand(10000) * 3 );
    }
}

done_testing();