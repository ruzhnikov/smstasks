#!/usr/bin/perl

=NAME

check_depending.pl

=DESCRIPTION

Скрипт для проверки всех необходимых для работы программы модулей

=cut

use strict;
use warnings;
use Test::More  tests => 16;

use 5.008009;

# список всех необходимых модулей
my @required_modules = qw/ base Carp Config::Tiny constant DBI Digest::MD5 
            Log::Log4perl LWP::UserAgent utf8 XML::Fast Data::Dumper Date::Parse Redis::Fast
            LWP::Protocol::https IO::Socket::SSL Getopt::Long /;

for my $module ( @required_modules ) {
    require_ok( $module );
}

done_testing();