package SmsTasks::UserAgent;

use 5.008009;
use strict;
use warnings;

use LWP::UserAgent;
use Carp    qw/ confess /;

use SmsTasks::UserAgent::Response;

use base qw/ SmsTasks::UserAgent::Requests /;

our $VERSION = '0.01';

sub new {
    my ( $class, $param ) = @_;
    $class = ref $class || $class;

    grep { confess "Field '" . $_ . "' required!" unless $param->{ $_ } } qw/ username password url /;

    my $self = {
        username => $param->{username},
        password => $param->{password},
        url      => $param->{url},
        period   => $param->{period} || '',
        timeout  => 30,
    };

    return bless $self, $class;
}

sub abstracrt_request {
    my ( $self, %post_data ) = @_;

    my $url = $self->{url};

    return if ( scalar keys %post_data == 0 );

    my $ua = LWP::UserAgent->new();

    $post_data{user} = $self->{username};
    $post_data{pass} = $self->{password};

    $ua->ssl_opts( verify_hostname => 0 );
    $ua->timeout( $self->{timeout} );

    my $res = $ua->post( $url, \%post_data );

    return SmsTasks::UserAgent::Response->new( $res );
}

sub log {
    my ( $self, $message ) = @_;

    my $prefix = 'UA';
    $message = $prefix . ': ' . $message;

    if ( $self->{logger} ) {
        $self->{logger}->log( $message );
    }
    else {
        warn $message;
    }

    return 1;
}

1;