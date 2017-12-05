package WTSI::NPG::iRODS::PublisherFactoryTest;

use strict;
use warnings;
use Log::Log4perl;

use base qw(WTSI::NPG::iRODS::Test);
use Test::More;
use Test::Exception;

use base qw[WTSI::NPG::iRODS::TestRabbitMQ];

Log::Log4perl::init('./etc/log4perl_tests.conf');

use WTSI::NPG::iRODS::PublisherFactory;

sub require : Test(1) {
    require_ok('WTSI::NPG::iRODS::DataObject');
}

sub make_publishers : Test(4) {

    my $factory = WTSI::NPG::iRODS::PublisherFactory->new();

    my $publisher;
    local %ENV = %ENV;
    my $config = $ENV{NPG_RMQ_CONFIG};
    $ENV{NPG_RMQ_ENABLE} = 1;
    $ENV{NPG_RMQ_CONFIG} = 0;
    $publisher = $factory->make_publisher();
    is_ok($publisher, 'WTSI::NPG::iRODS::PublisherWithReporting');
    $ENV{NPG_RMQ_ENABLE} = 0;
    $ENV{NPG_RMQ_CONFIG} = $config || './etc/rmq_test_config.json';
    $publisher = $factory->make_publisher();
    is_ok($publisher, 'WTSI::NPG::iRODS::PublisherWithReporting');
    $ENV{NPG_RMQ_ENABLE} = 0;
    $ENV{NPG_RMQ_CONFIG} = 0;
    $publisher = $factory->make_publisher();
    is_ok($publisher, 'WTSI::NPG::iRODS::Publisher');
    ok(!($publisher->isa('WTSI::NPG::iRODS::PublisherWithReporting')));

}
