#!/usr/bin/perl

=NAME
    insert_msg.pl

=DESCRIPTION
    скрипт для быстрой вставки в таблицу smstasks.sms_task_messages

=cut

use strict;
use warnings;

use FindBin qw/ $Bin /;
use lib "$Bin/../lib";
use Getopt::Long;

use SmsTasks;

my ( $help, $msg );

my $NAME = 'insert_msg.pl';

GetOptions(
    help    => \$help,
    'msg:s' => \$msg,
);

print_help() if ( $help || ! $msg );
msg() if ( $msg );

sub print_help {
    print "USAGE: perl $NAME --msg 'message' [-h]\n";
}

sub msg {
    my $db = SmsTasks::DB->new( SmsTasks::get_config->{database} );
    $db->connect();

    $db->dbh->do("INSERT INTO sms_task_messages(message) VALUES (?)", undef, $msg);
}
