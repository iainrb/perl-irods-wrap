package WTSI::NPG::TestMQPublisher;

use Moose;

use WTSI::NPG::iRODS::Publisher;

extends 'WTSI::NPG::iRODS::Publisher';

with qw[WTSI::NPG::iRODS::Reportable::PublisherMQ
        WTSI::NPG::iRODS::Reportable::TestRole
   ];

has 'answer' =>
    (is       => 'ro',
     isa      => 'Int',
     default  => 42,
     documentation => 'Dummy attribute for testing',
);

__PACKAGE__->meta->make_immutable;

no Moose;

1;
