package SmsTasks::UserAgent::Response;

use 5.008009;
use strict;
use warnings;

use XML::Fast;

sub new {
    my ( $class, $res ) = @_;

    my $success   = $res->is_success;
    my $xml       = $success ? $res->decoded_content : '';
    my $error     = $success ? '' : $res->decoded_content;
    my $status    = $res->status_line;

    my $parsed_response = $xml ? xml2hash( $xml ) : {};

    return bless(
        {
            success  => $success,
            xml      => $xml,
            error    => $error,
            response => $parsed_response->{xml_result},
            status   => $status,
        },
        $class
    );
}

sub xml {
    my $self = shift;

    return $self->{xml};
}

sub success {
    my $self = shift;

    return $self->{success};
}

sub response_error {
    my $self = shift;

    if ( $self->{response}->{errors} ) {
        return $self->{response}->{errors}->{error};
    }

    return;
}

sub response_error_text {
    my $self = shift;

    if ( $self->response_error ) {
        my $err_text = $self->response_error->{'#text'};
        utf8::encode( $err_text );
        return $err_text;
    }

    return;
}

sub response_error_code {
    my $self = shift;

    return $self->response_error->{'-code'} if ( $self->response_error );
    return;
}

sub response_field {
    my ( $self, $field ) = @_;

    return unless ( $field );
    return if ( $self->response_error );
    return $self->{response}->{$field};
}

sub date_delivery_sms {
    my ( $self ) = @_;

    return unless ( $self->{response}->{sms} );

    my $delivery_date = $self->{response}->{sms}->{'-delivery_date'};
    my $delivery_time = $self->{response}->{sms}->{'-delivery_time'};

    return unless ( $delivery_date && $delivery_time );

    my @delivery_date_array = split( /\./, $delivery_date );

    return if ( scalar @delivery_date_array != 3 );

    $delivery_date = join( '-', reverse @delivery_date_array );

    return $delivery_date . ' ' . $delivery_time;
}

1;