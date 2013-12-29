package SmsTasks::UserAgent::Requests;

use 5.008009;
use strict;
use warnings;

use constant DEFAULT_TTL => '600';  # время "жизни" СМС

sub send_sms {
    my ( $self, %data ) = @_;

    return unless ( %data && $data{number} && $data{message} );

    return $self->abstracrt_request(
        action  => 'post_sms',
        number  => $data{number},
        message => $data{message},
        period  => $self->{period} || DEFAULT_TTL,
    );
}

sub get_status {
    my ( $self, %data ) = @_;

    return unless ( %data && $data{sms_id} );

    return $self->abstracrt_request(
        action  => 'status',
        sms_id  => $data{sms_id},
        date_from => $data{date_from},
        date_to   => $data{date_to},
    );
}

sub get_balance {
    my ( $self ) = @_;

    my $res = $self->abstracrt_request( action => 'balance' );
    return $res->response_field('balance');
}

1;