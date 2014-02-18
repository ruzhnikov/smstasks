#!/usr/bin/perl

use strict;
use warnings;

use 5.008009;
use Test::More  tests => 7;

use FindBin qw/ $Bin /;
use lib "$Bin/../lib";

my @modules = qw/ SmsTasks SmsTasks::DB SmsTasks::DB::Queries SmsTasks::Log
        SmsTasks::UserAgent SmsTasks::UserAgent::Requests SmsTasks::UserAgent::Response /;

for my $module ( @modules ) {
    require_ok( $module );
}

done_testing();
