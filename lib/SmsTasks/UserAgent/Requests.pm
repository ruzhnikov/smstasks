package SmsTasks::UserAgent::Requests;

use 5.008009;
use strict;
use warnings;

use constant DEFAULT_TTL => '10';  # время "жизни" СМС

our $VERSION = '0.12';

sub send_sms {
    my ( $self, %data ) = @_;

    return unless ( %data && $data{number} && $data{message} );

    return $self->abstracrt_request(
        action  => 'sms_send',
        number  => $data{number},
        message => $data{message},
        period  => $self->{period} || DEFAULT_TTL,
        sender  => $self->{sender},
    );
}

sub get_status {
    my ( $self, %data ) = @_;

    return if ( scalar keys %data == 0 );
    return unless ( $data{push_id} && $data{number} );

    return $self->abstracrt_request(
        action  => 'sms_status2',
        push_id => $data{push_id},
        number  => $data{number},
    );
}

1;