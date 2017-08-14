package WTSI::NPG::TestMQiRODS;

use Moose;

our $VERSION = '';

extends 'WTSI::NPG::iRODS';

with 'WTSI::NPG::iRODS::Reportable::iRODSMQ';

has 'universal_answer' =>
  (is        => 'ro',
   isa       => Int,
   default   => 42,
   documentation => 'Dummy attribute for testing');

__PACKAGE__->meta->make_immutable;

no Moose;

1;
