#!/usr/bin/perl

use strict;
use warnings;
use 5.008009;

use FindBin qw/ $Bin /;
use lib "$Bin/../lib";

use Carp;
use Data::Dumper;
use Date::Parse qw/ str2time /;
use POSIX   qw/ setsid /;

use IPC::Shareable;

use SmsTasks;

use constant {
    DEFAULT_WAIT_TIME   => 7,
    NUMBERS_PER_ITER    => 2,   # количество номеров из задачи на итерацию
    MAX_FORK_COUNT      => 2,   # кол-во форков
    DEFAULT_TIME_START  => '11:00',
    DEFAULT_TIME_END    => '20:00',
};

# проверяем, не запущен ли скрипт ранее
do_exit() if ( me_running() );
do_wait() unless ( check_run_time() );

# объявляем переменные
# глобальный список задач -- делаем видимым из разных процессов
tie my %TASKS, 'IPC::Shareable' or die "tied failed: $!";

# частота обращения к БД
my $db_wait_time = SmsTasks::get_config->{general}->{db_poll_frequency};
$db_wait_time ||= DEFAULT_WAIT_TIME;

# сон основной программы
my $wait_time = DEFAULT_WAIT_TIME;

my @child_pids;

my $st = SmsTasks->new();

# главный процесс
sub work {

    # TODO: приделать обработку сигналов %SIG из операционной системы
    # в т.ч. $SIG{CHLD}

    while ( 1 ) {

        do_wait() unless ( check_run_time() );

        if ( scalar keys %TASKS == 0 ) {
            sleep( $wait_time );
            next;
        }

        # TODO: идём дальше

        kill -9, @child_pids;
        exit;   # TODO: убрать потом
    }
}

# процесс, перечитывающий задачи из БД
sub db_process {

    # TODO: приделать обработку сигналов %SIG

    while( 1 ) {

        do_wait() unless ( check_run_time() );

        $st->log( "try get tasks" );
        check_db();
        my $tasks = $st->db->get_tasks;

        if ( ! $tasks || scalar @{ $tasks } == 0 ) {
            sleep( $wait_time );
            next;
        }

        my %_tasks_id;

        for ( @{ $tasks } ) {
            my $task_id = $_->{id};
            my $task_status = $_->{status};

            next unless ( $task_id && $task_status );
            $_tasks_id{ $task_id } = 1;

            if ( $task_status  eq 'new' ) {
                check_db();
                $st->db->set_task_new( $task_id );
                $st->db->set_task_run( $task_id );
            }
            elsif ( $task_status eq 'running' ) {
                next if ( $TASKS{ $task_id } );
                check_db();
                $st->db->set_task_run( $task_id );
                $TASKS{ $task_id }->{status} = 'running';
                $TASKS{ $task_id }->{numbers} = {};
            }
            else {
                $st->log( "wrong status $task_status for the task $task_id, skipped" );
            }
        }

        $st->log( "obtained tasks with id's: " . join ', ', keys %_tasks_id );

        _check_unknown_ids( %_tasks_id );

        sleep( $db_wait_time );
    }
}

# процесс, проверяющий статусы отправленных СМС
sub ua_process {
    
    # TODO: приделать обработку сигналов %SIG

    while ( 1 ) {

        do_wait() unless ( check_run_time() );

        # ...
    }
}

setsid();

my $child_pid_1 = fork();

# основная нить программы: родитель и потомки
if ( $child_pid_1 ) { # родитель

    push @child_pids, $child_pid_1;
    $st->log("start working");

    my $child_pid_2 = fork or die "cannot create fork: $!";

    if ( $child_pid_2 ) {    
        push @child_pids, $child_pid_2;
        die "MAX COUNT ALREDY PROCESS RUNNING!" if ( scalar @child_pids > MAX_FORK_COUNT );
        work();
    }
    else {  # потомок #2
        db_process();
    }
}
else {  # потомок #1
    ua_process();
}

sub get_numbers_of_task {
    my $task_id = shift;

    return unless ( $task_id );

    check_db();
    my $num_data = $st->db->get_numbers( $task_id );

    set_task_suc( $task_id ) if ( scalar @{ $num_data } == 0 );

    # TODO: доделать функцию
}

# помечаем задачу как выполненную
sub set_task_suc {
    my $task_id = shift;

    return unless ( $task_id );

    check_db();
    $st->db->set_task_suc( $task_id );

    delete $TASKS{ $task_id };

    return 1;
}

sub task_status {
    my $task_id = shift;

    return unless ( $task_id && $TASKS{ $task_id }->{status} );
    return $TASKS{ $task_id }->{status};
}

sub number {
    my ( $task, $number_id ) = @_;

    return unless ( $task && $number_id );
    return $task->{numbers}->{ $number_id };
}

# проверяем доступность БД
sub check_db {

    while( 1 ) {
        last if ( $st->db->ping );
        $st->log("Cannot get DB connect, wait to connect...");
        $st->db->connect();
        sleep( $wait_time );
    }

    return 1;
}

# проверяем, нет ли в массиве %TASKS удалённых из БД задач
# %task_ids -- задачи, полученные на очередной итерации обращения к бд за задачами
sub _check_unknown_ids {
    my ( %task_ids ) = @_;

    return unless ( %task_ids && scalar keys %task_ids == 0 );

    my @unknown_ids;
    for ( keys %TASKS ) {
        push @unknown_ids, $_ unless ( $task_ids{$_} );
    }

    if ( scalar @unknown_ids > 0 ) {

        $st->log( "found unused tasks with id's: " . join( ', ', @unknown_ids ) );
        $st->log( "these tasks will be deleted" );

        delete $TASKS{ $_ } for ( @unknown_ids );
    }

    return 1;
}

# проверяем, попадаем ли в разрешённые временные рамки
sub check_run_time {
    my $time_start = $SmsTasks::get_config->{general}->{time_start};
    my $time_end   = $SmsTasks::get_config->{general}->{time_end};

    $time_start ||= DEFAULT_TIME_START;
    $time_end   ||= DEFAULT_TIME_END;

    my $year = (localtime(time))[5];
    my $mon = (localtime(time))[4];
    my $mday = (localtime(time))[3];

    $mon += 1;
    $year += 1900;

    my $date_start = $year . ':' . $mon . ':' . $mday . ' ' . $time_start;
    my $date_end = $year . ':' . $mon . ':' . $mday . ' ' . $time_end;

    return 1 if ( time > str2time( $date_start ) && 
                    time < str2time( $date_end ) );

    return;
}

sub do_wait {
    my $wait_time = DEFAULT_WAIT_TIME + 60;

    while ( 1 ) {
        sleep( $wait_time );
        next unless ( check_run_time() );
        return 1;
    }    
}

sub me_running {
    my $cnt = `ps -ef | grep $0 | grep -v $$ | wc -l`;

    return $cnt >= 2;
}

sub do_exit {
    warn "Program alredy running!";
    exit;
}

__END__

=head1 DESCRIPTION

Скрипт отправки СМС. Использует модули SmsTasks::*

=head1 AUTHOR

Alexander Ruzhnikov, C<< ruzhnikov85@gmail.com >>

=cut