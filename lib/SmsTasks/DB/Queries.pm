package SmsTasks::DB::Queries;

=head1 NAME

SmsTasks::DB::Queries

=cut

use strict;
use warnings;
use 5.008009;

use POSIX   qw/ strftime /;

use constant DEFAULT_LIMIT  => 10;  # лимит выборки данных из БД

our $VERSION = '0.01';

=head1 METHODS

=over

=item B<get_tasks_query>( $self, %param )

Базовый запрос для получения списка задач по условию

%param:
    status -- массив статусов для условия OR
    id     -- массив идентификаторов
    fields -- список полей, которые необходимо вернуть

=cut

sub get_tasks_query {
    my ( $self, %param ) = @_;

    my @bind_params = ();
    my @wherecond = ();
    my $fields;
    my $wherecond;

    if ( $param{status} ) {
        for my $status ( @{ $param{status} } ) {
            push @wherecond, 'status = ?';
            push @bind_params, ( $status );
        }
    }

    if ( $param{fields} ) {
        $fields = join( ', ', @{ $param{fields} } );
    }

    $wherecond = join( ' OR ', @wherecond ) if ( scalar @wherecond );

    if ( $param{id} ) {
        $wherecond .= ' AND ' if ( $wherecond );
        $wherecond .= 'id IN ( ' . join( ', ', @{ $param{id} } ) . ' )';
    }

    my $query = qq/ SELECT / .
                ( $fields ? $fields : 'id' ) .
                qq/ FROM sms_tasks / .
                ( $wherecond ? "WHERE $wherecond " : '' ) .
                qq/ LIMIT 0,/ . DEFAULT_LIMIT;

    return $self->dbh->selectall_arrayref( $query, { Slice => {} }, @bind_params );
}

=item B<get_tasks>( $self )

Возвращает задачи со статусами new и running

=cut

sub get_tasks {
    my ( $self ) = @_;

    return $self->get_tasks_query(
        status => [ qw/ new running / ],
        fields => [ qw/ id status / ],
    );
}

sub get_new_tasks {
    my ( $self ) = @_;

    return $self->get_tasks_query(
        status => [ qw/ new / ],
        fields => [ qw/ id status / ],
    );
}

sub get_run_tasks {
    my ( $self ) = @_;

    return $self->get_tasks_query(
        status => [ qw/ running / ],
        fields => [ qw/ id status / ],
    );
}

sub get_suc_tasks {
    my ( $self ) = @_;

    return $self->get_tasks_query(
        status => [ qw/ success / ],
        fields => [ qw/ id status / ],
    );
}

sub get_fail_tasks {
    my ( $self ) = @_;

    return $self->get_tasks_query(
        status => [ qw/ fail / ],
        fields => [ qw/ id status / ],
    );
}

sub get_task_date_start {
    my ( $self, $task_id ) = @_;

    return unless ( $task_id );

    my $query = qq/SELECT date_start FROM sms_tasks WHERE id = ?/;

    return $self->dbh->selectrow_array( $query, { Slice => {} }, $task_id );
}

=item B<set_task_query>( $self, $task_id, %param )

Обновление данных в таблице sms_tasks

%param -- список полей со значениями, которые надо обновить

=cut

sub set_task_query {
    my ( $self, $task_id, $param ) = @_;

    return unless ( $task_id && $param );

    my $query = qq/ UPDATE sms_tasks SET /;
    
    while ( my ($key, $value) = each( %{ $param } ) ) {
        $query .= "$key = \'$value\',";
    }
    chop($query);

    $query .= qq/ WHERE id = ? /;

    return $self->dbh->do( $query, undef, $task_id );
}

sub set_task_date_start {
    my ( $self, $task_id, $date_start ) = @_;

    return unless ( $task_id );
    return $self->set_task_query( $task_id, { date_start => $self->get_now } );
}

sub set_task_date_end {
    my ( $self, $task_id, $date_end ) = @_;

    return unless ( $task_id );
    return $self->set_task_query( $task_id, { date_end => $self->get_now } );
}

sub set_task_run {
    my ( $self, $task_id ) = @_;

    return unless ( $task_id );
    return $self->set_task_query( $task_id,
        {
            status => 'running',
            date_start => $self->get_now,
        }
    );
}

sub set_task_suc {
    my ( $self, $task_id ) = @_;

    return unless ( $task_id );
    return $self->set_task_query( $task_id,
        {
            status => 'success',
            date_end => $self->get_now,
        }
    );
}

sub set_task_fail {
    my ( $self, $task_id ) = @_;

    return unless ( $task_id );
    return $self->set_task_query( $task_id,
        {
            status => 'fail',
            date_end => $self->get_now,
        }
    );
}

sub set_task_log {
    my ( $self, $task_id, $message ) = @_;

    return unless ( $task_id && $message );
    return $self->set_task_query( $task_id, { log => $message } );
}

=item B<set_task_new>( $self, $task_id )

Обнуляем задачу, устанавливаем как новую

=cut

sub set_task_new {
    my ( $self, $task_id ) = @_;

    my $query = qq/ UPDATE sms_tasks
            INNER JOIN sms_task_numbers
            ON (sms_tasks.id = sms_task_numbers.task_id)
            SET sms_tasks.date_start = NULL, sms_tasks.date_end = NULL, sms_tasks.log = NULL,
            sms_task_numbers.status = 'new', sms_task_numbers.repeat_count = 0
            WHERE sms_tasks.id = ? /;

    return $self->dbh->do( $query, undef, $task_id );
}

=item B<delete_task>( $self, $task_id )

Удаление данных из БД. Данные удаляются из таблиц sms_tasks и sms_task_numbers

=cut

sub delete_task {
    my ( $self, $task_id ) = @_;

    return unless ( $task_id );

    my $query = qq/ DELETE sms_tasks, sms_task_numbers
            FROM sms_tasks, sms_task_numbers
            WHERE sms_task_numbers.task_id = sms_tasks.id
            AND sms_tasks.id = ?/;

    return $self->dbh->do( $query, undef, $task_id );
}

=item B<delete_unused_messages>( $self )

Удаление сообщений, на которые не ссылается ни один номер

=cut

sub delete_unused_messages {
    my ( $self ) = @_;

    my $query = qq/ DELETE FROM sms_task_messages
            WHERE id NOT IN
            ( SELECT DISTINCT(message_id) FROM sms_task_numbers ) /;

    return $self->dbh->do( $query, undef );
}

=item B<get_numbers_query>( $self, $task_id, %param )

Базовый запрос для получения списка номеров задачи по заданным условиям

%param:
    status -- массив статусов для условия OR
    check_repeat -- не выбирать номера с большим количеством повторов

=cut

sub get_numbers_query {
    my ( $self, $task_id, $param ) = @_;

    return unless ( $task_id );

    my @bind_params = ( $task_id );
    my @wherecond = ();
    my $wherecond;

    my $limit = $param->{limit} ? $param->{limit} : DEFAULT_LIMIT;

    if ( $param->{status} ) {
        for my $status ( @{ $param->{status} } ) {
            push @wherecond, 'status = ?';
            push @bind_params, ( $status );
        }
    }

    if ( scalar @wherecond ) {
        $wherecond = ' AND ' . '(' . join ( ' OR ', @wherecond ) . ') ';
    }

    if ( $param->{check_repeat} ) {
        my $repeat_count = $self->config->{general}->{repeat_count};
        $wherecond .= ' AND num.repeat_count <= ' . $repeat_count;
    }

    my $query = qq/ SELECT num.id id, num.number number, num.uid uid, mes.message message
        FROM sms_task_numbers num
        LEFT JOIN sms_task_messages mes
        ON (num.message_id = mes.id)
        WHERE num.task_id = ? / . ( $wherecond ? "$wherecond " : ' ' ) .
        qq/ ORDER BY num.status ASC LIMIT 0,/ . $limit;

    return $self->dbh->selectall_arrayref( $query, { Slice => {} }, @bind_params );
}

sub get_numbers {
    my ( $self, $task_id, $limit ) = @_;

    return unless ( $task_id );

    $limit ||= DEFAULT_LIMIT;
    return $self->get_numbers_query( $task_id,
        {
            status  => [ qw/ new fail / ],
            check_repeat => 1,
            limit   => $limit,
        }
    );
}

sub set_number_query {
    my ( $self, $number_id, $param ) = @_;

    return unless ( $number_id && $param );

    my $query = qq/ UPDATE sms_task_numbers SET /;
                
    while ( my ( $key, $value ) = each( %{ $param } ) ) {
        $query .= "$key = \'$value\',";
    }
    chop( $query ); # убираем последнюю запятую

    $query .= qq/ WHERE id = ? /;

    return $self->dbh->do( $query, undef, $number_id );
}

sub set_number_run {
    my ( $self, $number_id, $push_id ) = @_;

    $push_id ||= 0;

    return unless ( $number_id );
    return $self->set_number_query( $number_id,
        {
            status  => 'running',
            push_id => $push_id,
        }
    );
}

sub set_number_suc {
    my ( $self, $number_id) = @_;

    return unless ( $number_id );
    return $self->set_number_query( $number_id, { status => 'success' } );
}

sub set_number_fail {
    my ( $self, $number_id ) = @_;

    return unless ( $number_id );

    my $query = qq/ UPDATE sms_task_numbers SET /;
    $query .= "status = \'fail\', repeat_count = repeat_count + 1";
    $query .= qq/ WHERE id = ? /;

    return $self->dbh->do( $query, undef, $number_id );
}

sub get_now {
    my ( $self ) = @_;

    return strftime "%Y:%m:%d %H:%M:%S", localtime(time);
}

sub set_stat {
    my ( $self, $name, $param ) = @_;

    return unless ( $name );
    return if ( scalar keys %{ $param } == 0 );

    my ( $keys, @values, $bind_values, $table );

    if ( $name eq 'tasks' ) {
        $table = 'sms_tasks_stat';
    }
    elsif ( $name eq 'numbers' ) {
        $table = 'sms_numbers_stat';
    }

    return unless ( $table );

    for my $key ( keys %{ $param } ) {
        $keys .= $key . ',';
        push @values, $param->{$key};
        $bind_values .= '?,';
    }

    # отрезаем последние запятые
    chop( $bind_values );
    chop( $keys );

    my $query = qq/INSERT INTO / . $table . qq/ (/ . $keys . qq/)/ .
                qq/ VALUES (/ . $bind_values . qq/)/;

    return $self->dbh->do( $query, undef, @values );
}

1;

=back

=head1 DESCRIPTION

Запросы к БД

=head1 AUTHOR

Alexander Ruzhnikov, C<< ruzhnikov85@gmail.com >>

=cut