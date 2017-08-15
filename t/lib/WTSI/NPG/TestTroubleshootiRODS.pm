package WTSI::NPG::TestTroubleshootiRODS;

use Moose;

extends 'WTSI::NPG::iRODS';

has 'identifier' =>
  (is        => 'ro',
   isa       => Int,
   default   => 1138,
   documentation => 'Dummy attribute for testing');

#with 'WTSI::NPG::iRODS::Reportable::iRODSMQ';

__PACKAGE__->meta->make_immutable;

no Moose;

1;
