package WTSI::NPG::TestMQiRODS;

use Moose;

use WTSI::NPG::iRODS;

extends 'WTSI::NPG::iRODS';

with qw[WTSI::NPG::iRODS::Reportable::iRODSMQ];

__PACKAGE__->meta->make_immutable;

no Moose;

1;
