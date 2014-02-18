#!/usr/bin/perl

use strict;
use warnings;

use 5.008009;
use Test::More;

use FindBin qw/ $Bin /;
use lib "$Bin/../lib";

require_ok( 'SmsTasks' );

done_testing();
