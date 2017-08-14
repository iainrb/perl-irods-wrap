package WTSI::NPG::TestMQiRODS;

use Moose;

extends 'WTSI::NPG::iRODS';

with 'WTSI::NPG::iRODS::Reportable::iRODSMQ';

__PACKAGE__->meta->make_immutable;

no Moose;

1;
