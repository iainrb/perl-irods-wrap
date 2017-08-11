package WTSI::NPG::iRODS::Reportable::Base;

use strict;
use warnings;
use Moose::Role;

use DateTime;
use JSON;
use Time::HiRes qw[gettimeofday];

our $VERSION = '';

with 'WTSI::NPG::RabbitMQ::Connectable';

# consuming class must have these methods
# BUILD and DEMOLISH must be explicitly declared to enable method modifiers
requires qw[BUILD
            DEMOLISH
            get_irods_user
            get_message_body
       ];

has 'channel' =>
    (is       => 'ro',
     isa      => 'Int',
     default  => 1,
     documentation => 'A RabbitMQ channel',
);

has 'exchange' =>
    (is       => 'ro',
     isa      => 'Str',
     default  => 'npg.gateway',
     documentation => 'A RabbitMQ exchange name',
);

has 'routing_key_prefix' =>
    (is       => 'ro',
     isa      => 'Str',
     default  => 'prod',
     documentation => 'Prefix for the RabbitMQ routing key. May be '.
         'used to distinguish test from production messages.',
);

has 'no_rmq' =>
    (is       => 'ro',
     isa      => 'Bool',
     lazy     => 1,
     builder  => '_build_no_rmq',
     documentation => 'If true, do not connect to the RabbitMQ server. '.
         'True by default unless the rmq_config_path attribute in the '.
         'WTSI::NPG::RabbitMQ::Connectable role is defined.',
 );

after 'BUILD' => sub {
    my ($self, @args) = @_;
    if (! $self->no_rmq) {
        $self->rmq_connect();
        $self->rmq->channel_open($self->channel);
        $self->debug('Server properties: ',
                     encode_json($self->rmq->get_server_properties));
    }
};

after 'DEMOLISH' => sub {
    my ($self, @args) = @_;
    if (! $self->no_rmq) {
        $self->rmq_disconnect();
    }
};


sub publish_rmq_message {
    my ($self, $path, $name, $now) = @_;
    my $response = $self->get_message_body($path);
    my $response_string = encode_json($response);
    $self->debug('Got response from baton: ', $response_string);
    my $key = $self->routing_key_prefix.'.irods.report';
    my $headers = $self->_get_headers($response, $name, $now);
    $self->rmq->publish($self->channel,
                        $key,
                        $response_string,
                        { exchange => $self->exchange },
                        { headers => $headers },
                    );
    # Net::AMQP::RabbitMQ documentation specifies 'header' as key in
    # props argument to 'publish', but this is incorrect (2017-07-31)
    return 1;
}


sub rmq_timestamp {
    my ($self, ) = @_;
    my ($seconds, $microseconds) = gettimeofday();
    my $time = DateTime->from_epoch(epoch => $seconds);
    my $decimal_string = sprintf "%06d", $microseconds;
    return $time->iso8601().q{.}.$decimal_string;
}


sub _build_no_rmq {
    my ($self, ) = @_;
    my $no_rmq = 1;
    if (defined $self->rmq_config_path) {
        $no_rmq = 0;
    }
    return $no_rmq;
}

sub _get_headers {
    my ($self, $response, $name, $time) = @_;
    my $irods_user = $self->get_irods_user();
    my $headers = {
        method     => $name,       # name of Moose method called
        timestamp  => $time,       # time immediately before method call
        user       => $ENV{USER},  # OS username (may differ from irods_user)
	irods_user => $irods_user, # iRODS username
        type       => q{},         # file type from metadata, if any
    };
    foreach my $avu (@{$response->{'avus'}}) {
        if ($avu->{attribute} eq 'type') {
            $headers->{type} = $avu->{value};
        }
    }
    return $headers;
}

no Moose::Role;

1;


__END__

=head1 NAME

WTSI::NPG::iRODS::Reportable::Base

=head1 DESCRIPTION

A Role to enable reporting of method calls to a RabbitMQ message server.

=head2 Required methods

The consuming class must have the following methods:

=over

=item

BUILD

=item

DEMOLISH

=item

ensure_collection_path

=item

ensure_object_path

=item

get_irods_user

=back

See the WTSI::NPG::iRODS class for examples. The BUILD and DEMOLISH
methods must be explicitly declared, to enable the method modifiers in
this Role.


=head2 Test requirements

Tests for this Role require a working RabbitMQ server. The hostname and
configuration may be set using the environment variables NPG_RMQ_HOST
and NPG_RMQ_CONFIG, otherwise will be given default values.

The RabbitMQ server must have a user with password matching the given
configuration. The user must have read, write, and configure permissions
on the given RabbitMQ virtual host. If SSL is enabled for tests, the user
must also have a valid SSL certificate for connection to the host.

=head1 AUTHOR

Iain Bancarz <ib5@sanger.ac.uk>

=head1 COPYRIGHT AND DISCLAIMER

Copyright (C) 2017 Genome Research Limited. All Rights Reserved.

This program is free software: you can redistribute it and/or modify
it under the terms of the Perl Artistic License or the GNU General
Public License as published by the Free Software Foundation, either
version 3 of the License, or (at your option) any later version.

This program is distributed in the hope that it will be useful,
but WITHOUT ANY WARRANTY; without even the implied warranty of
MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
GNU General Public License for more details.

=cut
