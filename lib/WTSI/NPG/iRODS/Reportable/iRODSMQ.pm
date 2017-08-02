package WTSI::NPG::iRODS::Reportable::iRODSMQ;

use strict;
use warnings;
use Moose::Role;

our $VERSION = '';

with 'WTSI::NPG::iRODS::Reportable::Base';

requires qw[ensure_collection_path
            ensure_object_path];

before 'remove_collection' => sub {
    my ($self, @args) = @_;
    if (! $self->no_rmq) {
        my $collection = $self->ensure_collection_path($args[0]);
        my $now = $self->_timestamp();
        $self->_publish_message($collection, 'remove_collection', $now);
    }
};

before 'remove_object' => sub {
    my ($self, @args) = @_;
    if (! $self->no_rmq) {
        my $object = $self->ensure_object_path($args[0]);
        $self->debug('RabbitMQ reporting for method remove_object',
                     ' on data object ', $object);
        my $now = $self->_timestamp();
        $self->_publish_message($object, 'remove_object', $now);
    }
};


no Moose::Role;

1;


__END__

=head1 NAME

WTSI::NPG::iRODS::Reportable::iRODSMQ

=head1 DESCRIPTION

A Role to enable reporting of method calls on an iRODS object to a
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
