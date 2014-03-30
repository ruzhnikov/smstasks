#!/usr/bin/perl

use strict;
use warnings;
use 5.008009;

use Test::More  tests => 11;
use FindBin qw/ $Bin /;
use lib "$Bin/../lib";

my @modules = qw/ SmsTasks SmsTasks::DB SmsTasks::DB::Queries SmsTasks::Log
        SmsTasks::UserAgent SmsTasks::UserAgent::Requests SmsTasks::UserAgent::Response
        SmsTasks::Utils SmsTasks::Cache SmsTasks::Cache::BaseQueries SmsTasks::Cache::Queries /;

for my $module ( @modules ) {
    require_ok( $module );
}

done_testing();
