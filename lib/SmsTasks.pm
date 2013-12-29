package SmsTasks;

=head1 NAME

SmsTasks

=cut

use strict;
use warnings;
use 5.008009;

use Carp;
use Config::Tiny;

use SmsTasks::DB;
use SmsTasks::UserAgent;
use SmsTasks::Log;

# задаём константы
use constant {
    GLOBAL_CONF => 'smstasks.conf',
    CONF_PATH   => '/etc/smstasks',
    DEFAULT_REPEAT_ON_FAIL  => 'no',
    DEFAULT_REPEAT_COUNT    => 1,
    DEFAULT_LOGFILE         => '/var/log/smstasks/smstasks.log',
};

# обязательные параметры из yml-файла
use constant REQUIRED_SETTINGS => qw/ general database useragent /;

our $VERSION = '0.01';

=head1 METHODS

=over

=item B<new>

Конструктор

=cut

sub new {
    my $class = shift;

    $class = ref $class || $class;

    my $self = bless {}, $class;
    $self->_init();

    return $self;
}

=item B<_init>( $self )

Инициализация модулей

=cut

sub _init {
    my ( $self ) = @_;

    $self->init_logger();

    $self->db->connect();
    confess "cannot connect to database!" if ( ref $self->db->{dbh} ne 'DBI::db' );

    $self->ua;
}

sub config {
    my ( $self ) = @_;

    unless ( $self->{config} ) {
        $self->{config} = get_config();
    }

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

    unless ( $self->{db} ) {
        $self->{db} = SmsTasks::DB->new( $self->config->{database} );
    }

    return $self->{db};
}

sub ua {
    my ( $self ) = @_;

    unless ( $self->{ua} ) {
        $self->{ua} = SmsTasks::UserAgent->new( $self->config->{useragent} );
    }

    return $self->{ua};
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

sub init_logger {
    my ( $self ) = @_;

    $self->{logger} = $self->_get_logger();
    $self->db->{logger} = $self->_get_logger();
    $self->ua->{logger} = $self->_get_logger();

    return 1;
}

sub log {
    my ( $self, $message ) = @_;

    my $prefix = 'GENERAL';
    $message = $prefix . ': ' . $message;

    $self->_get_logger->log( $message );

    return 1;
}

1;

=back

=head1 DESCRIPTION

Головной модуль. Подключает все остальные модули

=head1 AUTHOR

Alexander Ruzhnikov, C<< ruzhnikov85@gmail.com >>

=cut