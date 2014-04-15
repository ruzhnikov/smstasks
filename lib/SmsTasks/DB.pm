package SmsTasks::DB;

use 5.008009;
use strict;
use warnings;
use DBI;
use Carp;

use constant DEFAULT_WAIT_TIME   => 7;

use base qw/ SmsTasks::DB::Queries /;

our $VERSION = $SmsTasks::DB::Queries::VERSION;

sub new {
    my $class = shift;
    $class = ref $class || $class;

    my $self = $_[0];
    grep { confess "Field '" . $_ . "' required!" unless $self->{ $_ } } qw/ name host user password /;

    return bless $self, $class;
}

sub connect {
    my ( $self ) = @_;

    my $string = 'DBI:mysql:database=' . $self->{name} . ';host=' . $self->{host};
    my $user = $self->{user};
    my $password = $self->{password};

    my $attr = {
        RaiseError => 1,
        mysql_enable_utf8 => 1
    };

    $self->log( "connecting to database " . $self->{name} . "..." );
    $self->{dbh} = undef;
    eval {
        $self->{dbh} = DBI->connect( $string, $user, $password, $attr );
    };
    if ( $@ ) {
        $self->log( $@ );
    }
    else {
        $self->log("connecting ok");
    }
    
    return 1;
}

sub ping {
    my ( $self ) = @_;

    return $self->dbh->ping;
}

sub log {
    my ( $self, $message ) = @_;

    my $prefix = 'DB';
    $message = $prefix . ': ' . $message;

    if ( $self->{logger} ) {
        $self->{logger}->log( $message );
    }
    else {
        warn $message;
    }

    return 1;
}

sub config {
    my ( $self ) = @_;

    unless ( $self->{config} ) {
        $self->{config} = SmsTasks::get_config();
    }

    return $self->{config};
}

sub dbh {
    my ( $self ) = @_;

    unless ( $self->{dbh} ) {
        $self->connect( $self->config->{database} );
    }

    return $self->{dbh};
}

sub check_db {
    my ( $self ) = @_;

    my $wait_time = DEFAULT_WAIT_TIME;

    while( 1 ) {
        last if ( $self->{dbh} && $self->ping );
        $self->log("Cannot get DB connect, wait to connect...");
        $self->connect;
        sleep( $wait_time );
    }

    return 1;
}

1;