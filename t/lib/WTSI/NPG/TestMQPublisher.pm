ackage WTSI::NPG::TestMQPublisher;

use Moose;

use WTSI::NPG::iRODS::Publisher;

extends 'WTSI::NPG::iRODS::Publisher';
with 'WTSI::NPG::iRODS::Reportable::PublisherMQ';

__PACKAGE__->meta->make_immutable;

no Moose;

1;
