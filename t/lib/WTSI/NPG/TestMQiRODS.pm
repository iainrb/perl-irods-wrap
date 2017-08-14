package WTSI::NPG::TestMQiRODS;

use Moose;

our $VERSION = '';

extends 'WTSI::NPG::iRODS';

#with qw[WTSI::NPG::iRODS::Reportable::iRODSMQ];

__PACKAGE__->meta->make_immutable;

no Moose;

1;
