package SmsTasks::UserAgent;

use strict;
use warnings;
use 5.008009;

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
        sender   => $param->{sender} || '',
        timeout  => 30,
    };

    return bless $self, $class;
}

sub abstracrt_request {
    my ( $self, %data ) = @_;

    my $url = $self->{url};

    return if ( scalar keys %data == 0 );

    my $ua = LWP::UserAgent->new();

    $ua->ssl_opts( verify_hostname => 0 );
    $ua->timeout( $self->{timeout} );

    my $xml;

    if ( $data{action} eq 'sms_send' ) {
        $xml = $self->_generate_send_xml( %data );
    }
    elsif ( $data{action} eq 'sms_status2' ) {
        $xml = $self->_generate_status_xml( %data );
    }

    my $res = $ua->post( $url,
        Content_Type => 'text/xml',
        Content      => $xml
    );

    return SmsTasks::UserAgent::Response->new( $res );
}

# создаём xml для отправки СМС
sub _generate_send_xml {
    my ( $self, %data ) = @_;

    my $xml = qq/<?xml version="1.0" encoding="UTF-8" ?>/ . "\n";

    $xml .= qq/<xml_request name="/ . $data{action} . qq/">/ . "\n";

    $xml .= "\t" . qq/<xml_user lgn="/ . $self->{username} . qq/" /;
    $xml .= qq/pwd="/ . $self->{password} . qq/"\/>/ . "\n";

    $xml .= "\t" . qq/<sms sms_id="/ . $data{sms_id} . qq/" number="/;
    $xml .= $data{number} . qq/" source_number="/ . $data{sender} . qq/"/;
    $xml .= qq/ ttl="/ . $data{period} . qq/">/ . $data{message};
    $xml .= qq/<\/sms>/ . "\n" . qq/<\/xml_request>/;

    return $xml;
}

# создаём xml для получения статуса СМС
sub _generate_status_xml {
    my ( $self, %data ) = @_;

    my $xml = qq/<?xml version="1.0" encoding="UTF-8" ?>/ . "\n";

    $xml .= qq/<xml_result name="/ . $data{action} . qq/">/ . "\n";

    $xml .= "\t" . qq/<xml_user lgn="/ . $self->{username} . qq/" /;
    $xml .= qq/pwd="/ . $self->{password} . qq/"\/>/ . "\n";

    $xml .= "\t" . qq/<sms push_id="/ . $data{push_id} . qq/" number="/;
    $xml .= $data{number} . qq/" delivery_date="" delivery_time="" /;
    $xml .= qq/description="" \/>/ . "\n" . qq/<\/xml_result>/;

    return $xml;
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