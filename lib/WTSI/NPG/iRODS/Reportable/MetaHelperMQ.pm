package WTSI::NPG::iRODS::Reportable::MetaHelperMQ;

use strict;
use warnings;
use Moose::Role;

our $VERSION = '';

with 'WTSI::NPG::iRODS::Reportable::Base';

requires qw[irods];

our @REPORTABLE_METHODS = qw[update_object_secondary_metadata];

foreach my $name (@REPORTABLE_METHODS) {

    around $name => sub {
        my ($orig, $self, @args) = @_;
        my $now = $self->rmq_timestamp();
        my $obj = $self->$orig(@args);
        if ($self->enable_rmq) {
            $self->debug('RabbitMQ reporting for method ', $name,
                         ' on path ', $obj->str() );
            my $body;
            if ($self->irods->is_object($obj->str())) {
                $body = $self->object_message_body($obj->str(),
                                                   $self->irods);
            } elsif ($self->irods->is_collection($obj->str())) {
                $body = $self->collection_message_body($obj->str(),
                                                       $self->irods);
            } else {
		$self->logcroak('Value returned to method modifier is not an',
				'iRODS data object or collection');
	    }
            my $user = $self->irods->get_irods_user;
            my $headers = $self->message_headers($body, $name, $now, $user);
            $self->publish_rmq_message($body, $headers);
        }
        return $obj;
    };
}

no Moose::Role;

1;


__END__

=head1 NAME

WTSI::NPG::iRODS::Reportable::MetaHelperMQ

=head1 DESCRIPTION

A Role to enable reporting of method calls to a RabbitMQ message server.
To be consumed by a subclass of WTSI::NPG::HTS::MetaHelper in npg_irods.

=head1 AUTHOR

Iain Bancarz <ib5@sanger.ac.uk>

=head1 COPYRIGHT AND DISCLAIMER

Copyright (C) 2018 Genome Research Limited. All Rights Reserved.

This program is free software: you can redistribute it and/or modify
it under the terms of the Perl Artistic License or the GNU General
Public License as published by the Free Software Foundation, either
version 3 of the License, or (at your option) any later version.

This program is distributed in the hope that it will be useful,
but WITHOUT ANY WARRANTY; without even the implied warranty of
MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
GNU General Public License for more details.

=cut
