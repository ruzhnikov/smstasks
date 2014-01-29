#!/usr/bin/perl

#===============================================================================
#
#          FILE: smstasks.pl
#
#         USAGE: ./smstasks.pl
#
#   DESCRIPTION: Скрипт отправки СМС
#
#  REQUIREMENTS: Carp, Date::Parse, POSIX, IPC::Shareable, constant, SmsTasks::*
#
#       AUTHORS: Alexander Ruzhnikov <ruzhnikov85@gmail.com>
#
#       LICENSE: GPLv3
#
#===============================================================================

use strict;
use warnings;
use 5.008009;

use FindBin qw/ $Bin /;
use lib "$Bin/../lib";

use Carp;
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

# главный процесс, занимается отправкой СМС
sub work {

    # TODO: приделать обработку сигналов %SIG из операционной системы
    # в т.ч. $SIG{CHLD}

    while ( 1 ) {

        do_wait() unless ( check_run_time() );

        if ( scalar keys %TASKS == 0 ) {
            sleep( $wait_time );
            next;
        }

        for my $task_id ( keys %TASKS ) {

            do_wait() unless ( check_run_time() );

            # выбираем номера для задачи
            my $numbers = $st->db->get_numbers( $task_id, NUMBERS_PER_ITER );

            # проверяем, отработала ли задача или остались ещё не доставленные номера СМС
            if ( scalar @{ $numbers } == 0 ) {
                if ( scalar keys %{ $TASKS{ $task_id }->{numbers} } == 0 ) {
                    set_task_suc( $task_id );
                    next;
                }
                else {
                    next;
                }
            }

            for my $number_data ( @{ $numbers } ) {

                my $number_id = $number_data->{id};

                # отправляем СМС
                my $res = $st->ua->send_sms(
                    number  => $number_data->{number},
                    message => $number_data->{message},
                );

                my $res_code = $res->response_field('push')->{'-res'};
                my $res_descr = $res->response_field('push')->{'-description'};
                my $push_id = $res->response_field('push')->{'-push_id'};

                my $stat_hash = {
                    task_id => $task_id,
                    number  => $number_data->{number},
                    date    => $st->db->get_now,
                    uid     => $number_data->{uid},
                };

                my $db_method;

                if ( $res_descr ) {
                    require utf8;
                    utf8::encode( $res_descr );
                    $stat_hash->{log} = $res_descr;
                }

                if ( $res_code == 0 || $res_code == 4 ) { # доставлено
                    $stat_hash->{status} = 'success';
                    $db_method = 'set_number_suc';
                }
                elsif ( $res_code == 1 || $res_code == 2 ) { # передано в обработку, не доставлено пока
                    $stat_hash->{status} = 'running';
                    $db_method = 'set_number_run';

                    $TASKS{ $task_id }->{numbers}->{ $number_id } = {
                        push_id => $push_id,
                        number  => $number_data->{number},
                        uid     => $number_data->{uid},
                    };
                }
                else {  # ошибка
                    $stat_hash->{status} = 'fail';
                    $db_method = 'set_number_fail';
                }

                check_db();

                my @db_method_data;
                push @db_method_data, $number_id;
                push @db_method_data, $push_id if ( $db_method eq 'running' );

                $st->db->$db_method( @db_method_data );
                $st->db->set_stat( 'numbers', $stat_hash );
            }
        }

        kill -9, @child_pids;   # TODO: убрать потом
        exit;   # TODO: убрать потом
    }
}

# процесс, перечитывающий задачи из БД
# добавляет новые задачи в глобальный массив
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
                set_task_run( $task_id );
                $TASKS{ $task_id }->{status} = 'running';
                $TASKS{ $task_id }->{numbers} = {};
            }
            elsif ( $task_status eq 'running' ) {
                next if ( $TASKS{ $task_id } );
                check_db();
                set_task_run( $task_id );
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

        if ( scalar keys %TASKS == 0 ) {
            sleep( $wait_time );
            next;
        }

        for my $task_id ( keys %TASKS ) {

            my $numbers = $TASKS{ $task_id }->{numbers};
            next if ( ! $numbers || scalar keys %{ $numbers } == 0 );

            for my $number_id ( keys %{ $numbers } ) {
                next unless $numbers->{$number_id}->{push_id};

                my $res = $st->ua->get_status(
                    push_id => $numbers->{$number_id}->{push_id},
                    number  => $numbers->{$number_id}->{number},
                );

                # берём данные из ответа
                my $res_code = $res->response_field('sms')->{'-status'};
                my $res_descr = $res->response_field('sms')->{'-description'};

                my $stat_hash = {
                    task_id => $task_id,
                    number  => $numbers->{$number_id}->{number},
                    uid     => $numbers->{$number_id}->{uid},
                };

                my ( $db_method, $delivery_date, $delivery_time, $date );

                if ( $res_descr ) {
                    require utf8;
                    utf8::encode( $res_descr );
                    $stat_hash->{log} = $res_descr;
                }

                if ( $res_code == 0 || $res_code == 4 ) {

                    # сообщение доставлено, пишем статистику и удаляем номер из глобального хэша
                    $stat_hash->{status} = 'success';
                    $db_method = 'set_number_suc';
                    delete $numbers->{ $number_id };

                    $date = $res->date_delivery_sms;
                }
                elsif ( $res_code == 1 || $res_code == 2 ) {
                    next;
                }
                else {  # ошибка при доставке
                    $stat_hash->{status} = 'fail';
                    $db_method = 'set_number_fail';
                    delete $numbers->{ $number_id };
                }

                $date ||= $st->db->get_now;
                $stat_hash->{date} = $date;

                $st->db->$db_method( $number_id );
                $st->db->set_stat( 'numbers', $stat_hash );
            }
        }

        sleep( $wait_time );
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

# помечаем задачу как запущенную
sub set_task_run {
    my $task_id = shift;

    return unless ( $task_id );

    check_db();
    $st->db->set_task_run( $task_id );

    return 1;
}

# помечаем задачу как выполненную
sub set_task_suc {
    my $task_id = shift;

    return unless ( $task_id );

    check_db();
    $st->db->set_task_suc( $task_id );

    my $date_start = $st->db->get_task_date_start( $task_id );
    my $stat_hash = {
        task_id     => $task_id,
        date_end    => $st->db->get_now,
        status      => 'success'
    };

    $stat_hash->{date_start} = $date_start if ( $date_start );

    $st->db->set_stat( 'tasks', $stat_hash );

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