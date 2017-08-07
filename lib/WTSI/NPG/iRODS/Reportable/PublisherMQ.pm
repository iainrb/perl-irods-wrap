package WTSI::NPG::iRODS::Reportable::PublisherMQ;

use strict;
use warnings;
use Moose::Role;

our $VERSION = '';

with 'WTSI::NPG::iRODS::Reportable::Base';

our @REPORTABLE_METHODS = qw[publish];

foreach my $name (@REPORTABLE_METHODS) {

    around $name => sub {
        my ($orig, $self, @args) = @_;
 	my $now = $self->rmq_timestamp();
        my $path = $self->$orig(@args);
        if (! $self->no_rmq) {
            $self->debug('RabbitMQ reporting for method ', $name,
                         ' on path ', $path);
            $self->publish_rmq_message($path, $name, $now);
        }
        return $path;
    };

}

sub BUILD {
    # BUILD method is required for compatibility with the Base role
    my ($self) = @_;
    $self->debug('Initializing Publisher with RabbitMQ reporting');
    return $self;
}

sub DEMOLISH {
    # DEMOLISH method is required for compatibility with the Base role
    my ($self) = @_;
    $self->debug('Demolishing Publisher with RabbitMQ reporting');
    return $self;
}


### subroutines to enable PublisherMQ role

sub get_irods_user {
    my ($self,) = @_;
    return $self->irods->get_irods_user;
}

sub get_message_body {
    my ($self, $path) = @_;
    return $self->list_path_details($path);
}

sub list_path_details {
    my ($self, $path) = @_;
    return $self->irods->list_path_details($path);
}

no Moose::Role;

1;


__END__

=head1 NAME

WTSI::NPG::iRODS::Reportable::PublisherMQ

=head1 DESCRIPTION

A Role to enable reporting of iRODS Publisher method calls to a
RabbitMQ message server.

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
