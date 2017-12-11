package WTSI::NPG::iRODS::PublisherFactoryTest;

use strict;
use warnings;
use Log::Log4perl;

use Test::More;
use Test::Exception;

use base qw[WTSI::NPG::iRODS::TestRabbitMQ];

Log::Log4perl::init('./etc/log4perl_tests.conf');

use WTSI::NPG::iRODS::PublisherFactory;

sub require : Test(1) {
    require_ok('WTSI::NPG::iRODS::PublisherFactory');
}

sub make_publishers : Test(3) {

    my $irods = WTSI::NPG::iRODS->new(environment          => \%ENV,
                                      strict_baton_version => 0);
    my %args = ( 'irods' =>  $irods );

    my $factory0 = WTSI::NPG::iRODS::PublisherFactory->new(enable_rmq => 0);
    my $publisher0 = $factory0->make_publisher(%args);
    isa_ok($publisher0, 'WTSI::NPG::iRODS::Publisher');
    # ensure we have an instance of the parent class, not the subclass
    ok(!($publisher0->isa('WTSI::NPG::iRODS::PublisherWithReporting')),
       'Factory does not return a PublisherWithReporting');

    my $factory1 = WTSI::NPG::iRODS::PublisherFactory->new(enable_rmq => 1);
    my $publisher1 = $factory1->make_publisher(%args);
    isa_ok($publisher1, 'WTSI::NPG::iRODS::PublisherWithReporting');

}
