package WTSI::NPG::iRODS::Reportable::iRODSMQ;

use strict;
use warnings;
use Moose::Role;

use File::Basename qw[basename];
use JSON;

our $VERSION = '';

with 'WTSI::NPG::iRODS::Reportable::Base';

requires qw[ensure_collection_path
            ensure_object_path
            get_collection_meta
            get_object_meta
            list_path_details
];

our @REPORTABLE_COLLECTION_METHODS =
    qw[
          add_collection
          put_collection
          move_collection
          set_collection_permissions
          add_collection_avu
          remove_collection_avu
  ];

our @REPORTABLE_OBJECT_METHODS =
    qw[
          add_object
          replace_object
          copy_object
          move_object
          set_object_permissions
          add_object_avu
          remove_object_avu
  ];


foreach my $name (@REPORTABLE_COLLECTION_METHODS) {

    around $name => sub {
        my ($orig, $self, @args) = @_;
	my $now = $self->rmq_timestamp();
        my $path = $self->$orig(@args);
        if (! $self->no_rmq) {
            $self->debug('RabbitMQ reporting for method ', $name,
                         ' on collection ', $path);
            my $body = $self->_get_collection_message_body($path);
            $self->publish_rmq_message($body, $name, $now);
        }
        return $collection;
    };

}

foreach my $name (@REPORTABLE_OBJECT_METHODS) {

    around $name => sub {
        my ($orig, $self, @args) = @_;
	my $now = $self->rmq_timestamp();
        my $path = $self->$orig(@args);
        if (! $self->no_rmq) {
            $self->debug('RabbitMQ reporting for method ', $name,
                         ' on data object ', $path);
            my $body = $self->_get_object_message_body($path);
            $self->publish_rmq_message($body, $name, $now);
        }
        return $object;
    };

}

before 'remove_collection' => sub {
    my ($self, @args) = @_;
    if (! $self->no_rmq) {
        $self->debug('RabbitMQ reporting for method remove_collection',
                     ' on input path ', $args[0]);
        my $now = $self->rmq_timestamp();
        my $body = $self->_get_collection_message_body($args[0]);
        $self->publish_rmq_message($body, 'remove_collection', $now);
    }
};

before 'remove_object' => sub {
    my ($self, @args) = @_;
    if (! $self->no_rmq) {
        $self->debug('RabbitMQ reporting for method remove_object',
                     ' on input path ', $args[0]);
        my $now = $self->rmq_timestamp();
        my $body = $self->_get_object_message_body($args[0]);
        $self->publish_rmq_message($body, 'remove_object', $now);
    }
};

sub _get_collection_message_body {
    my ($self, $path) = @_;
    # similar to method for object
    $path = $self->ensure_collection_path($path);
    my $avus = $self->get_collection_meta($path); # does not use cache
    # $spec has same data structure as json() method of Collection
    # TODO also record permissions?
    my $spec = { collection  => $collection,
                 avus        => $avus
             };
    my $body = encode_json($spec);
    return $body;
}

sub _get_object_message_body {
    my ($self, $path) = @_;
    $path = $self->ensure_object_path($path); # uses path cache
    my ($obj, $collection, $suffix) = fileparse($path);
    my $avus = $self->get_object_meta($path); # uses metadata cache
    # $spec has same data structure as json() method of DataObject
    # TODO also record permissions?
    my $spec = { collection  => $collection,
                 data_object => $obj,
                 avus        => $avus
             };
    my $body = encode_json($spec);
    return $body;
}

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
