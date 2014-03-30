#!/usr/bin/perl

use strict;
use warnings;
use 5.008009;

use Test::More  tests => 5;
use FindBin qw/ $Bin /;
use lib "$Bin/../lib";

require_ok( 'SmsTasks::Cache' );

my $redis;

eval {
    $redis = SmsTasks::Cache->new;
};

ok( !$@, 'object create success' );
is( ref $redis, 'SmsTasks::Cache', 'object belongs to SmsTasks::Cache' );
ok( $redis->{redis}, 'get redis');

delete $redis->{redis};

eval {
    $redis->r;
};

ok( $redis->{redis}, 'get redis again' );

done_testing();