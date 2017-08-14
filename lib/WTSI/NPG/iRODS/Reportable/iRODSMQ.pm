package WTSI::NPG::iRODS::Reportable::iRODSMQ;

use strict;
use warnings;
use Moose::Role;

our $VERSION = '';

with 'WTSI::NPG::iRODS::Reportable::Base';

requires qw[ensure_collection_path
            ensure_object_path];

# BUILD and DEMOLISH methods required by Reportable::Base are implemented by iRODS.pm. Should be OK, but tests appear to be failing; try copy-pasting methods here.


sub BUILD {
  my ($self) = @_;

  my $installed_baton_version = $self->installed_baton_version;

  if (not $self->match_baton_version($installed_baton_version)) {
    my $required_range = join q{ - }, $MIN_BATON_VERSION, $MAX_BATON_VERSION;
    my $msg = sprintf "The installed baton release version %s is " .
      "not supported by this wrapper (requires version %s)",
      $installed_baton_version, $required_range;

    if ($self->strict_baton_version) {
      $self->logdie($msg);
    }
    else {
      $self->warn($msg);
    }
  }

  return $self;
}



sub DEMOLISH {
  my ($self, $in_global_destruction) = @_;

  # Only do try to stop cleanly if the object is not already being
  # destroyed by Perl (as indicated by the flag passed in by Moose).
  if (not $in_global_destruction) {

    # Stop any active client and log any errors that it encountered
    # while running. This preempts the client being stopped within its
    # own destructor and allows our logger to be resonsible for
    # reporting any errors.
    #
    # If stopping were left to the client destructor, Moose would
    # handle any errors by warning to STDERR instead of using the log.
    if ($self->has_baton_client) {
      try {
        $self->debug("Stopping baton client");
        my $startable = $self->baton_client;

        my $muffled = Log::Log4perl->get_logger('log4perl.logger.Muffled');
        $muffled->level($OFF);
        $startable->logger($muffled);
        $startable->stop;
      } catch {
        $self->error("Failed to stop baton client cleanly: ", $_);
      };
    }
  }

  return;
}


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
        my $collection = $self->$orig(@args);
        if (! $self->no_rmq) {
            $self->debug('RabbitMQ reporting for method ', $name,
                         ' on collection ', $collection);
            $self->publish_rmq_message($collection, $name, $now);
        }
        return $collection;
    };

}

foreach my $name (@REPORTABLE_OBJECT_METHODS) {

    around $name => sub {
        my ($orig, $self, @args) = @_;
	my $now = $self->rmq_timestamp();
        my $object = $self->$orig(@args);
        if (! $self->no_rmq) {
            $self->debug('RabbitMQ reporting for method ', $name,
                         ' on data object ', $object);
            $self->publish_rmq_message($object, $name, $now);
        }
        return $object;
    };

}

before 'remove_collection' => sub {
    my ($self, @args) = @_;
    if (! $self->no_rmq) {
        my $collection = $self->ensure_collection_path($args[0]);
        my $now = $self->rmq_timestamp();
        $self->publish_rmq_message($collection, 'remove_collection', $now);
    }
};

before 'remove_object' => sub {
    my ($self, @args) = @_;
    if (! $self->no_rmq) {
        my $object = $self->ensure_object_path($args[0]);
        $self->debug('RabbitMQ reporting for method remove_object',
                     ' on data object ', $object);
        my $now = $self->rmq_timestamp();
        $self->publish_rmq_message($object, 'remove_object', $now);
    }
};

sub get_message_body {
    my ($self, $path) = @_;
    return encode_json($self->list_path_details($path));
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
