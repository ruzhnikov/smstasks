#!/usr/bin/perl

use strict;
use warnings;
use 5.008009;

use Test::More  tests => 7;
use FindBin qw/ $Bin /;
use lib "$Bin/../lib";

use constant {
    DBINDEX   => 9,
    ITER      => 4,
};

use constant DATA_NUMBER_FIELDS  => qw/ push_id number uid /;

require_ok( 'SmsTasks::Cache' );

my $redis = SmsTasks::Cache->new;

ok( $redis->select( DBINDEX ), 'change dbindex' );
ok( $redis->flushdb, 'flush db' );
is( $redis->dbsize, '0', 'db empty' );

subtest simple_keys => sub {

    # обычные ключи
    for my $i ( 1 .. ITER ) {
        my $key = 'key' . $i;
        my $val = 'value' . $i;
        ok( $redis->set( key => $key, value => $val ), 'set value for ' . $key );
    }

    is($redis->keys( 'key*' ), '4', 'keys count' );

    for my $i ( 1 .. ITER ) {
        my $key = 'key' . $i;
        my $val = 'value' . $i;
        ok( $redis->exists( key => $key ), 'exists ' . $key );
        is( $redis->get(key => $key ), $val, 'get value for ' . $key );
        ok( $redis->del( key => $key), 'delete ' . $key );
    }

    is( $redis->dbsize, '0', 'db empty' );
};

# хеши
my @number_ids  = ();
my %number_hash = ();

subtest hash_keys_set => sub {

    for my $i ( 1 .. ITER ) {
        my $hash = 'key' . $i;
        my $number_id = get_data();
        push @number_ids, $number_id;
        ok( $redis->hset( $hash, $number_id, 1 ), 'set ' . $number_id . ' for hash ' . $hash );

        for my $key ( DATA_NUMBER_FIELDS ) {
            my $value = get_data( $key );
            ok( $redis->hset( $number_id, $key, $value ), 'set ' . $key . ' for hash ' . $number_id );
            $number_hash{ $number_id }->{ $key } = $value;
        }
    }

    is( $redis->dbsize, '8', 'dbsize' );
};

subtest hash_keys_get_and_del => sub {

    for my $i ( 1 .. ITER ) {
        my $hash = 'key' . $i;
        my $number_id = $number_ids[ $i - 1 ];
        ok( $redis->exists( key => $hash ), 'exists hash ' . $hash );
        ok( $redis->hexists( $hash, $number_id ), 'exists hash key ' . $number_id );
        is( $redis->hget( $hash, $number_id ), '1', 'hget from hash ' . $hash );
        ok( $redis->exists( key => $number_id ), 'exists hash ' . $number_id );
        ok( $redis->hdel( $hash, $number_id ), 'del ' . $number_id . ' from hash ' . $hash );

        for my $key ( DATA_NUMBER_FIELDS ) {
            my $value = $number_hash{ $number_id }->{ $key };
            ok( $redis->hexists( $number_id, $key ), 'exists hash key ' . $key );
            is( $redis->hget( $number_id, $key ), $value, 'hget ' . $key . ' from hash ' . $number_id );
            ok( $redis->hdel( $number_id, $key ), 'del ' . $key . ' from hash ' . $number_id );
        }
    }

    is( $redis->dbsize, '0', 'db empty' );
};

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