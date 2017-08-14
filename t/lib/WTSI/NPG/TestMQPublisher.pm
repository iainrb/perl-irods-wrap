package WTSI::NPG::TestMQPublisher;

use Moose;

our $VERSION = '';

extends 'WTSI::NPG::iRODS::Publisher';

with qw[WTSI::NPG::iRODS::Reportable::PublisherMQ];

__PACKAGE__->meta->make_immutable;

no Moose;

1;
