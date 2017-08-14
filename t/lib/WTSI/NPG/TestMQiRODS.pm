package WTSI::NPG::TestMQiRODS;

use Moose;

use WTSI::NPG::iRODS;

extends 'WTSI::NPG::iRODS';

has 'universal_answer' =>
  (is        => 'ro',
   isa       => Int,
   default   => 42,
   documentation => 'Dummy attribute for testing');

with 'WTSI::NPG::iRODS::Reportable::iRODSMQ';

__PACKAGE__->meta->make_immutable;

no Moose;

1;
