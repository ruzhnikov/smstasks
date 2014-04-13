#!/usr/bin/perl

#===============================================================================
#
#          FILE: smstasks.pl
#
#         USAGE: ./smstasks.pl
#
#   DESCRIPTION: Application to send SMS
#
#  REQUIREMENTS: Carp, Date::Parse, POSIX, constant, Data::Dumper, Getopt::Long, SmsTasks::*
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

use POSIX   qw/ setsid :sys_wait_h /;
use Data::Dumper;
use Getopt::Long;

use SmsTasks;
use SmsTasks::Utils;

use constant {
    DEFAULT_WAIT_TIME   => 7,
    NUMBERS_PER_ITER    => 2,   # количество номеров из задачи на итерацию
    DEFAULT_VERBOSE     => 0,
    GENERAL_WAIT_TIME   => 120, # время "сна" главного управляющего процесса
};


my $VERSION = '0.12';

my $version_flag;

GetOptions(
        'version|V' => \$version_flag,
);

print_version() if $version_flag;

# проверяем, не запущен ли скрипт ранее
do_exit() if ( me_running() );

# частота обращения к БД
my $db_wait_time = SmsTasks::get_config->{general}->{db_poll_frequency};
$db_wait_time ||= DEFAULT_WAIT_TIME;

my $VERBOSE = SmsTasks::get_config->{general}->{verbose};
$VERBOSE ||= DEFAULT_VERBOSE;

# длительность сна на итерациях
my $wait_time = DEFAULT_WAIT_TIME;

my %child_pids;

my $st = SmsTasks->new;

# проверяем, попадаем ли в разрешённый временной интервал
do_wait() unless ( $st->check_run_time );

# почистим кэш
$st->cache->clear;

# проверим ранее запущенные задачи
check_previous_run_tasks();

setsid();

# основная нить программы: родитель и потомки
$st->log("start working");

for my $num ( 1..3 ) {
    my $pid = fork();

    if ( $pid ) { # родитель
        if ( $num == 1 ) {
            $child_pids{$pid} = 'ua_process';
        }
        elsif ( $num == 2 ) {
            $child_pids{$pid} = 'db_process';
        }
        else {
            $child_pids{$pid} = 'work_process';
        }
    }
    else { # потомки
        ua_process() if ( $num == 1 );
        db_process() if ( $num == 2 );
        work_process() if ( $num == 3 );
    }
}

general_process();


sub general_process {

    $SIG{CHLD} = \&handle_sig_chld;

    while ( 1 ) {
        my $pids_cnt = scalar keys %child_pids;
        $st->log("running " . $pids_cnt . " pids");
        $st->log("pids is " . Dumper( \%child_pids ) );

        sleep( GENERAL_WAIT_TIME );
    }
}

# обрабатываем сигналы потомков
sub handle_sig_chld {
    my $chldpid = waitpid( -1, &WNOHANG );
    $st->log("child with pid $chldpid down!");
    $st->log("restart child");
    kill -9, $chldpid;
    my $process = delete $child_pids{$chldpid};

    my $pid = fork();
    if ( $pid ) {
        $child_pids{$pid} = $process;
    }
    else {
        ua_process() if ( $process eq 'ua_process' );
        db_process() if ( $process eq 'db_process' );
        work_process() if ( $process eq 'work_process' );
    }
}

# главный процесс, занимается отправкой СМС
sub work_process {

    $st->log("begin working work_process with pid $$");

    while ( 1 ) {

        do_wait() unless ( $st->check_run_time );

        if ( $st->cache->get_tasks_count == 0 ) {
            sleep( $wait_time );
            next;
        }
        else {
            $st->log( "proceed to sending sms for tasks..." );
        }

        for my $task_id ( $st->cache->get_tasks ) {

            do_wait() unless ( $st->check_run_time );
            $st->log( "task id: $task_id" );

            # выбираем номера для задачи
            my $numbers;
            eval {
                $numbers = $st->db->get_numbers( $task_id, NUMBERS_PER_ITER );
            };
            if ( $@ ) {
                $st->log( "error when requesting data: $@" );
                sleep( $wait_time );
                next;
            }

            # проверяем, отработала ли задача или остались ещё не доставленные номера СМС
            if ( scalar @{ $numbers } == 0 ) {
                $st->log("numbers for task $task_id has not been found");

                # если в БД номеров нет, а в кэше ещё остались, значит держим задачу,
                # т.к. есть ещё недоставленные сообщения
                if ( $st->cache->get_task_data_count( $task_id ) == 0 ) {
                    $st->log( "set task $task_id as success" );
                    set_task_suc( $task_id );
                    next;
                }
                else {
                    next;
                }
            }

            require utf8;
            grep { utf8::encode( $_->{message} ) if utf8::is_utf8( $_->{message} ) } @{ $numbers };

            $st->log( "obtained numbers data: " . Dumper( $numbers ) ) if ( $VERBOSE );

            # начинаем обрабатывать полученные номера
            for my $number_data ( @{ $numbers } ) {

                my $number_id = $number_data->{id};

                $st->log("send sms to number " . $number_data->{number});

                # отправляем СМС
                my $res;

                eval {
                    $res = $st->ua->send_sms(
                        number  => $number_data->{number},
                        message => $number_data->{message},
                    );
                };

                if ( $@ ) {
                    $st->log("Can't send message: $@");
                    next;
                }

                my $res_code  = $res->response_field('push')->{'-res'};
                my $res_descr = $res->response_field('push')->{'-description'};
                my $push_id   = $res->response_field('push')->{'-push_id'};

                $st->log("send status is $res_code");
                $st->log("description is $res_descr") if ( $res_descr && $VERBOSE );
                $st->log("push_id is $push_id") if ( $push_id );

                my $stat_hash = {
                    task_id => $task_id,
                    number  => $number_data->{number},
                    date    => SmsTasks::Utils::get_now,
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
                elsif ( $res_code == 1 || $res_code == 2 ) {
                    # передано в обработку, не доставлено пока
                    $stat_hash->{status} = 'running';
                    $db_method = 'set_number_run';

                    $st->cache->set_task_data( $task_id, {
                            number_id   => $number_id,
                            push_id     => $push_id,
                            number      => $number_data->{number},
                            uid         => $number_data->{uid},
                        }
                    );

                }
                else {  # ошибка
                    $stat_hash->{status} = 'fail';
                    $db_method = 'set_number_fail';
                }

                my @db_method_data;
                push @db_method_data, $number_id;
                push @db_method_data, $push_id if ( $push_id && $stat_hash->{status} eq 'running' );

                $st->db->$db_method( @db_method_data );
                $st->db->set_stat( 'numbers', $stat_hash );
            }
        }
    }
}

# процесс, перечитывающий задачи из БД
# добавляет новые задачи в глобальный массив
sub db_process {

    $st->log("begin working db_process with pid $$");

    while( 1 ) {

        do_wait() unless ( $st->check_run_time );

        $st->log( "try get tasks" );
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

            if ( $task_status eq 'new' ) {
                $st->db->set_task_new( $task_id );
                $st->db->set_task_run( $task_id );
                $st->cache->set_task_status( $task_id, 'running' );
            }
            elsif ( $task_status eq 'running' ) {
                next if ( $st->cache->task_exists( $task_id ) );
                $st->cache->set_task_status( $task_id, 'running' );
            }
            else {
                $st->log( "wrong status $task_status for the task $task_id, skipped" );
            }
        }

        $st->log( "obtained tasks with id's: " . join ', ', keys %_tasks_id );

        _check_unknown_ids( \%_tasks_id );

        sleep( $db_wait_time );
    }
}

# процесс, проверяющий статусы отправленных СМС
sub ua_process {

    $st->log("begin working ua_process with pid $$");

    while ( 1 ) {

        if ( $st->cache->get_tasks_count == 0 ) {
            sleep( $wait_time );
            next;
        }

        for my $task_id ( $st->cache->get_tasks ) {

            next if ( $st->cache->get_task_data_count( $task_id ) == 0 );
            my @number_ids = $st->cache->get_task_data( $task_id );

            $st->ua->log("processing of previously sent messages for task $task_id");

            for my $number_id ( @number_ids ) {
                my $number_data = $st->cache->get_task_data( $task_id, $number_id );
                next unless ( $number_data->{push_id} );

                if ( $VERBOSE ) {
                    $st->ua->log("obtained number data: " . Dumper( $number_data ) );
                }

                my $res;

                eval {
                    $res = $st->ua->get_status(
                        push_id => $number_data->{push_id},
                        number  => $number_data->{number},
                    );
                };

                if ( $@ ) {
                    $st->ua->log("Can't get status: $@");
                    next;
                }

                # берём данные из ответа
                my $res_code = $res->response_field('sms')->{'-status'};
                my $res_descr = $res->response_field('sms')->{'-description'};

                $st->ua->log("send status is $res_code");
                $st->ua->log("description is $res_descr") if ( $res_descr && $VERBOSE );

                my $stat_hash = {
                    task_id => $task_id,
                    number  => $number_data->{number},
                    uid     => $number_data->{uid},
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
                    $st->cache->del_task_data( $task_id, $number_id );

                    $date = $res->date_delivery_sms;
                }
                elsif ( $res_code == 1 || $res_code == 2 ) {
                    next;
                }
                else {  # ошибка при доставке
                    $stat_hash->{status} = 'fail';
                    $db_method = 'set_number_fail';
                    $st->cache->del_task_data( $task_id, $number_id );
                }

                $date ||= SmsTasks::Utils::get_now;
                $stat_hash->{date} = $date;

                $st->db->$db_method( $number_id );
                $st->db->set_stat( 'numbers', $stat_hash );
            }
        }

        sleep( $wait_time );
    }
}

# помечаем задачу как выполненную
sub set_task_suc {
    my $task_id = shift;

    return unless ( $task_id );

    $st->db->set_task_suc( $task_id );

    my $date_start = $st->db->get_task_date_start( $task_id );
    my $stat_hash = {
        task_id     => $task_id,
        date_end    => SmsTasks::Utils::get_now,
        status      => 'success'
    };

    $stat_hash->{date_start} = $date_start if ( $date_start );

    $st->db->set_stat( 'tasks', $stat_hash );
    $st->cache->del_task_data( $task_id );

    return 1;
}

# проверяем, нет ли в кэше удалённых из БД задач
# %task_ids -- задачи, полученные на очередной итерации обращения к бд за задачами
sub _check_unknown_ids {
    my ( $task_ids ) = @_;

    return if ( ! $task_ids && scalar keys %{ $task_ids } == 0 );

    my @unknown_ids;
 
    for ( $st->cache->get_tasks ) {
        push @unknown_ids, $_ unless ( $task_ids->{$_} );
    }

    if ( scalar @unknown_ids > 0 ) {
        $st->log( "found unused tasks with id's: " . join( ', ', @unknown_ids ) );
        $st->log( "these tasks will be deleted" );

        $st->cache->del_task_data( $_ ) for ( @unknown_ids );
    }

    return 1;
}

# чекаем таски, что были запущены ранее
# и выбираем из них номера со статусом running
sub check_previous_run_tasks {
    my $tasks = $st->db->get_run_tasks;

    return 1 if ( scalar @{ $tasks } == 0 );

    # TODO: переработать механизм обработки номеров,
    # в текщем виде он может захватывать не все номера( сейчас берёт 100 номеров )
    for my $task_id ( @{ $tasks } ) {
        my $numbers = $st->db->get_run_numbers( $task_id, 1000 );
        next if ( scalar @{ $numbers } == 0 );

        for my $number_data ( @{ $numbers } ) {
            next unless ( $number_data->{push_id} );

            $st->cache->set_task_data( $task_id, {
                    number_id   => $number_data->{id},
                    push_id     => $number_data->{push_id},
                    number      => $number_data->{number},
                    uid         => $number_data->{uid},
                }
            );
        }
    }

    return 1;
}

sub do_wait {
    my $wait_time = DEFAULT_WAIT_TIME + 60;

    while ( 1 ) {
        sleep( $wait_time );
        next unless ( $st->check_run_time );
        return 1;
    }
}

sub me_running {
    my $cnt = `ps -ef | grep $0 | grep -v $$ | wc -l`;

    return $cnt >= 2;
}

sub do_exit {
    warn "Program alredy running!";
    exit 1;
}

sub print_version {
    print $VERSION . "\n";
    exit 0;
}

__END__

=head1 DESCRIPTION

Скрипт отправки СМС. Использует модули SmsTasks::*

=head1 AUTHOR

Alexander Ruzhnikov, C<< ruzhnikov85@gmail.com >>

=cut
