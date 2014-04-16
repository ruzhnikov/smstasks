#!/usr/bin/perl

=NAME
    insert_number.pl

=DESCRIPTION
    скрипт для быстрой вставки в таблицу smstasks.sms_task_numbers

=cut

use FindBin qw/ $Bin /;
use lib "$Bin/../lib";
use Getopt::Long;

use SmsTasks;

my ( $help, $task_id, $msg_id, $number, $uid );

my $NAME = 'insert_number.pl';

GetOptions(
    help        => \$help,
    'task_id:s' => \$task_id,
    'msg_id:s'  => \$msg_id,
    'number:s'  => \$number,
    'uid:s'     => \$uid,
);

if ( $help ) {
    print_help();
}
elsif ( ! $task_id ) {
    print "Parameter task_id required!\n";
    print_help();
}
elsif ( ! $msg_id ) {
    print "Parameter $msg_id required!\n";
    print_help();
}
elsif ( ! $number ) {
    print "Parameter number required!\n";
    print_help();
}
elsif ( ! $uid ) {
    print "Parameter uid required!\n";
    print_help();
}
else {
    insert_number();
}

sub print_help {
    print "USAGE: perl $NAME --task_id <id> --msg_id <id> --number <number> --uid <uid> [-h]\n";
}

sub insert_number {
    my $db = SmsTasks::DB->new( SmsTasks::get_config->{database} );
    $db->connect();
    
    $db->dbh->do("INSERT INTO sms_task_numbers (task_id, message_id, number, uid) VALUES (?,?,?,?)",
                    undef, $task_id, $msg_id, $number, $uid );
}