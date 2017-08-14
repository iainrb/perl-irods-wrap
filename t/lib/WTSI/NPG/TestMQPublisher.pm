package WTSI::NPG::TestMQPublisher;

use Moose;

extends 'WTSI::NPG::iRODS::Publisher';

with qw[WTSI::NPG::iRODS::Reportable::PublisherMQ];

__PACKAGE__->meta->make_immutable;

no Moose;

1;
