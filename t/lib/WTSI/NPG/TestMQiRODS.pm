package WTSI::NPG::TestMQiRODS;

use Moose;

use WTSI::NPG::iRODS;

extends 'WTSI::NPG::iRODS';
with 'WTSI::NPG::iRODS::Reportable::iRODSMQ';


has 'answer' =>
    (is       => 'ro',
     isa      => 'Int',
     default  => 1138,
     documentation => 'Dummy attribute for testing',
);

__PACKAGE__->meta->make_immutable;

no Moose;

1;
