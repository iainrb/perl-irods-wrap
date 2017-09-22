package WTSI::NPG::iRODS::Reportable::PublisherMQ;

use strict;
use warnings;
use Moose::Role;

use File::Basename qw[fileparse];
use JSON;

our $VERSION = '';

with 'WTSI::NPG::iRODS::Reportable::Base';

requires qw[irods];

our @REPORTABLE_METHODS = qw[publish];

foreach my $name (@REPORTABLE_METHODS) {

    around $name => sub {
        my ($orig, $self, @args) = @_;
	my $now = $self->rmq_timestamp();
        my $obj = $self->$orig(@args);
        if ($self->enable_rmq) {
            $self->debug('RabbitMQ reporting for method ', $name,
                         ' on path ', $obj->str() );
	    my $body;
	    if ($obj->meta->has_attribute('data_object')) {
                $body = $self->_get_object_message_body($obj->str());
	    } else {
                $body = $self->_get_collection_message_body($obj->str());
	    }
	    if (not defined $body) {
                $self->error("Cannot generate RabbitMQ message body for ",
			     $obj->str());
	    }
            $self->publish_rmq_message($body, $name, $now);
        }
        return $obj;
    };

}

# TODO add _get_*_body methods similar to iRODSMQ.pm, to record permissions

sub get_irods_user {
    # required by WTSI::NPG::iRODS::Reportable::Base
    my ($self,) = @_;
    return $self->irods->get_irods_user;
}

sub _get_collection_message_body {
    my ($self, $path) = @_;
    $path = $self->irods->ensure_collection_path($path);
    my @avus = $self->irods->get_collection_meta($path);
    # $spec based on json() method of DataObject; also records permissions

    my @permissions = $self->irods->get_collection_permissions($path);
    #print STDERR "PERMISSIONS: ";
    #print STDERR Dumper \@permissions;
    my $spec = { collection  => $path,
                 avus        => \@avus,
		 acl         => \@permissions,
             };
    my $body = encode_json($spec);
    return $body;
}

sub _get_object_message_body {
    my ($self, $path) = @_;
    $path = $self->irods->ensure_object_path($path); # uses path cache
    my ($obj, $collection, $suffix) = fileparse($path);
    $collection =~ s/\/$//msx; # remove trailing /
    my @avus = $self->irods->get_object_meta($path); # uses metadata cache
    # $spec based on json() method of DataObject; also records permissions

    my @permissions = $self->irods->get_object_permissions($path);
    #print STDERR "PERMISSIONS: ";
    #print STDERR Dumper \@permissions;
    my $spec = { collection  => $collection,
                 data_object => $obj,
                 avus        => \@avus,
		 acl         => \@permissions,
             };
    my $body = encode_json($spec);
    return $body;
}

no Moose::Role;

1;


__END__

=head1 NAME

WTSI::NPG::iRODS::Reportable::PublisherMQ

=head1 DESCRIPTION

A Role to enable reporting of WTSI::NPG::iRODS::Publisher method calls
to a RabbitMQ message server.

This Role could also be consumed by other classes which have a
WTSI::NPG::iRODS object as an attribute.

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
