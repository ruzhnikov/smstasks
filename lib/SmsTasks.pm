package SmsTasks;

=encoding utf8

=head1 NAME

SmsTasks

=cut

use 5.008009;
use strict;
use warnings;

use Carp;
use Config::Tiny;

use SmsTasks::DB;
use SmsTasks::UserAgent;
use SmsTasks::Log;
use SmsTasks::Utils;
use SmsTasks::Cache;

# задаём константы
use constant {
    GLOBAL_CONF => 'smstasks.conf',
    CONF_PATH   => '/etc/smstasks',
    DEFAULT_REPEAT_ON_FAIL  => 'no',
    DEFAULT_REPEAT_COUNT    => 1,
    DEFAULT_LOGFILE         => '/var/log/smstasks/smstasks.log',
    DEFAULT_TIME_START      => '11:00',
    DEFAULT_TIME_END        => '20:00',
};

# обязательные параметры из yml-файла
use constant REQUIRED_SETTINGS => qw/ general database useragent /;

our $VERSION = '0.12';

=head1 METHODS

=over

=item B<new>

Конструктор

=cut

sub new {
    my $class = shift;

    $class = ref $class || $class;

    my $self = bless {}, $class;
    $self->_init;

    return $self;
}

=item B<_init>( $self )

Инициализация модулей

=cut

sub _init {
    my ( $self ) = @_;

    $self->{logger} = $self->_get_logger;
    $self->_init_db;
    $self->_init_ua;
    $self->_init_cache;
    confess "cannot connect to database!" if ( ref $self->{db}->{dbh} ne 'DBI::db' );
}

sub _init_db {
    my ( $self ) = @_;

    $self->{db} = SmsTasks::DB->new( $self->config->{database} );
    $self->{db}->{logger} = $self->_get_logger;
    $self->{db}->connect;
}

sub _init_ua {
    my ( $self ) = @_;

    $self->{ua} = SmsTasks::UserAgent->new( $self->config->{useragent} );
    $self->{ua}->{logger} = $self->_get_logger;
}

sub _init_cache {
    my ( $self ) = @_;

    $self->{cache} = SmsTasks::Cache->new;
}

sub config {
    my ( $self ) = @_;

    $self->{config} ||= get_config();

    return $self->{config};
}

=item B<get_config>

Читаем конфиг-файл

=cut

sub get_config {
    my $file = CONF_PATH . '/' . GLOBAL_CONF;
    my $settings = Config::Tiny->read( $file );

    grep { confess "Field '" . $_ . "' not found in conf-file!" unless $settings->{ $_ } } REQUIRED_SETTINGS;

    $settings->{general}->{repeat_on_fail} ||= DEFAULT_REPEAT_ON_FAIL;
    $settings->{general}->{repeat_count}   ||= DEFAULT_REPEAT_COUNT;

    return $settings;
}

sub db {
    my ( $self ) = @_;

    $self->{db} ||= SmsTasks::DB->new( $self->config->{database} );
    $self->{db}->check_db;

    return $self->{db};
}

sub ua {
    my ( $self ) = @_;

    $self->{ua} ||= SmsTasks::UserAgent->new( $self->config->{useragent} );

    return $self->{ua};
}

sub cache {
    my ( $self ) = @_;

    $self->{cache} ||= SmsTasks::Cache->new;

    return $self->{cache};
}

sub _get_logger {
    my ( $self ) = @_;

    unless ( $self->{logger} ) {
        my $logfile = $self->config->{general}->{logfile};
        $logfile ||= DEFAULT_LOGFILE;
        $self->{logger} = SmsTasks::Log->new( logfile => $logfile );
    }

    return $self->{logger};
}

sub log {
    my ( $self, $message ) = @_;

    my $prefix = 'GENERAL';
    $message = $prefix . ': ' . $message;

    $self->_get_logger->log( $message );

    return 1;
}

sub check_run_time {
    my ( $self ) = @_;

    my $time_start = $self->config->{general}->{time_start};
    my $time_end   = $self->config->{general}->{time_end};

    $time_start ||= DEFAULT_TIME_START;
    $time_end   ||= DEFAULT_TIME_END;

    return SmsTasks::Utils::check_run_time( $time_start, $time_end );
}

1;

=back

=head1 DESCRIPTION

Головной модуль. Подключает все остальные модули

=head1 AUTHOR

Alexander Ruzhnikov, C<< ruzhnikov85@gmail.com >>

=cut
