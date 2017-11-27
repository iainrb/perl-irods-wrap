package WTSI::NPG::iRODS::PublisherTest;

use strict;
use warnings;

use Carp;
use Data::Dump qw[pp];
use English qw[-no_match_vars];
use File::Copy::Recursive qw[dircopy];
use File::Spec::Functions;
use File::Temp;
use Log::Log4perl;
use Test::Exception;
use Test::More;
use URI;

use base qw[WTSI::NPG::iRODS::Test];

Log::Log4perl::init('./etc/log4perl_tests.conf');

use WTSI::NPG::iRODS::DataObject;
use WTSI::NPG::iRODS::Metadata;
use WTSI::NPG::iRODS::Publisher;

my $pid          = $PID;
my $test_counter = 0;
my $data_path    = './t/data/publisher';

my $tmp_data_path;
my $irods_tmp_coll;
my $cwc;

# RabbitMQ variables
my @header_keys = qw[timestamp
                     user
                     irods_user
                     type
                     method];
my $expected_headers = scalar @header_keys;
my $test_host = $ENV{'NPG_RMQ_HOST'} || 'localhost';
my $conf = $ENV{'NPG_RMQ_CONFIG'} || './etc/rmq_test_config.json';
my $queue = 'test_irods_data_create_messages';


sub setup_test : Test(setup) {
  my $irods = WTSI::NPG::iRODS->new(environment          => \%ENV,
                                    strict_baton_version => 0);
  $cwc = $irods->working_collection;

  # Prepare a copy of the test data because the tests will modify it
  $tmp_data_path = File::Temp->newdir;
  dircopy($data_path, $tmp_data_path) or
    croak "Failed to copy test data from $data_path to $tmp_data_path";

  $irods_tmp_coll = $irods->add_collection("PublisherTest.$pid.$test_counter");

  # Clear the message queue.
  my $args = _get_subscriber_args($test_counter);
  my $subscriber = WTSI::NPG::RabbitMQ::TestCommunicator->new($args);
  my @messages = $subscriber->read_all($queue);

  $test_counter++;
}

sub teardown_test : Test(teardown) {
  my $irods = WTSI::NPG::iRODS->new(environment          => \%ENV,
                                    strict_baton_version => 0);
  # Delete the copy of the test data
  undef $tmp_data_path;

  $irods->working_collection($cwc);
  $irods->remove_collection($irods_tmp_coll);
}

sub require : Test(1) {
  require_ok('WTSI::NPG::iRODS::Publisher');
}

sub message : Test(13) {
  # test RabbitMQ message capability

  my $irods = WTSI::NPG::iRODS->new(environment          => \%ENV,
                                    strict_baton_version => 0,
                                    routing_key_prefix   => 'test',
                                    hostname             => $test_host,
                                    rmq_config_path      => $conf,
                                    channel              => $test_counter,
                                );
  $irods->rmq_init();
  my $publisher = WTSI::NPG::iRODS::Publisher->new(irods => $irods);
  my $filename = 'a.txt';
  my $local_file_path  = "$tmp_data_path/publish/$filename";
  my $remote_file_path = "$irods_tmp_coll/$filename";
  my $file_pub = $publisher->publish($local_file_path, $remote_file_path);
  isa_ok($file_pub, 'WTSI::NPG::iRODS::DataObject',
         'publish, file -> returns a DataObject');

  my $args = _get_subscriber_args($test_counter);
  my $subscriber = WTSI::NPG::RabbitMQ::TestCommunicator->new($args);
  my @messages = $subscriber->read_all($queue);
  is(scalar @messages, 1, 'Got 1 message from queue');
  my $message = shift @messages;
  my @acl = $irods->get_object_permissions($remote_file_path);
  my $body =  {avus        => [],
               acl         => \@acl,
               collection  => $irods_tmp_coll,
               data_object => $filename,
           };
  _test_object_message($message, 'add_object', $body, $irods);
  $irods->rmq_disconnect();

}

sub publish : Test(8) {
  my $irods = WTSI::NPG::iRODS->new(environment          => \%ENV,
                                    strict_baton_version => 0);

  my $publisher = WTSI::NPG::iRODS::Publisher->new(irods => $irods);

  my $local_file_path  = "$tmp_data_path/publish/a.txt";
  my $remote_file_path = "$irods_tmp_coll/a.txt";
  my $file_pub = $publisher->publish($local_file_path, $remote_file_path);
  isa_ok($file_pub, 'WTSI::NPG::iRODS::DataObject',
         'publish, file -> returns a DataObject');
  is($file_pub->str(), $remote_file_path, 'publish, file -> has remote path');
  ok($irods->is_object($remote_file_path),
     'publish, file -> remote path exists on iRODS');

  my $local_dir_path  = "$tmp_data_path/publish";
  my $remote_dir_path = $irods_tmp_coll;
  my $dir_pub = $publisher->publish($local_dir_path, $remote_dir_path);
  isa_ok($dir_pub, 'WTSI::NPG::iRODS::Collection',
         'publish, directory -> returns a Collection');
  is($dir_pub->str(), "$remote_dir_path/publish",
     'publish, directory -> has remote path');
  ok($irods->is_collection("$remote_dir_path/"),
     'publish, directory -> remote path exists on iRODS');

  dies_ok {
    $publisher->publish("$tmp_data_path/publish/c.bam",
                        "$irods_tmp_coll/c.bam")
  } 'publish, bam no MD5 fails';

  dies_ok {
    $publisher->publish("$tmp_data_path/publish/c.cram",
                        "$irods_tmp_coll/c.cram")
  } 'publish, cram no MD5 fails';
}

sub publish_file : Test(41) {
  my $irods = WTSI::NPG::iRODS->new(environment          => \%ENV,
                                    strict_baton_version => 0);

  # publish_file with new full path, no metadata, no timestamp
  pf_new_full_path_no_meta_no_stamp($irods, $data_path, $irods_tmp_coll);
  # publish_file with new full path, some metadata, no timestamp
  pf_new_full_path_meta_no_stamp($irods, $data_path, $irods_tmp_coll);
  # publish_file with new full path, no metadata, with timestamp
  pf_new_full_path_no_meta_stamp($irods, $data_path, $irods_tmp_coll);

  # publish_file with existing full path, no metadata, no timestamp,
  # matching MD5
  pf_exist_full_path_no_meta_no_stamp_match($irods, $data_path,
                                            $irods_tmp_coll);
  # publish_file with existing full path, some metadata, no timestamp,
  # matching MD5
  pf_exist_full_path_meta_no_stamp_match($irods, $data_path,
                                         $irods_tmp_coll);

  # publish_file with existing full path, no metadata, no timestamp,
  # non-matching MD5
  pf_exist_full_path_no_meta_no_stamp_no_match($irods, $data_path,
                                               $irods_tmp_coll);
  # publish_file with existing full path, some metadata, no timestamp,
  # non-matching MD5
  pf_exist_full_path_meta_no_stamp_no_match($irods, $data_path,
                                            $irods_tmp_coll);

  # publish file where the cached md5 file is stale and must be
  # regenerated
  pf_stale_md5_cache($irods, $data_path, $irods_tmp_coll);
}

sub publish_directory : Test(11) {
  my $irods = WTSI::NPG::iRODS->new(environment          => \%ENV,
                                    strict_baton_version => 0);

  # publish_directory with new full path, no metadata, no timestamp
  pd_new_full_path_no_meta_no_stamp($irods, $data_path, $irods_tmp_coll);

  # publish_file with new full path, some metadata, no timestamp
  pd_new_full_path_meta_no_stamp($irods, $data_path, $irods_tmp_coll);
}

sub pf_new_full_path_no_meta_no_stamp {
  my ($irods, $data_path, $coll_path) = @_;

  my $publisher = WTSI::NPG::iRODS::Publisher->new(irods => $irods);

  # publish_file with new full path, no metadata, no timestamp
  my $timestamp_regex = '\d{4}-\d{2}-\d{2}T\d{2}:\d{2}:\d{2}';
  my $local_path_a = "$tmp_data_path/publish_file/a.txt";
  my $remote_path = "$coll_path/pf_new_full_path_no_meta_no_stamp.txt";
  is($publisher->publish_file($local_path_a, $remote_path)->str(),
     $remote_path,
     'publish_file, full path, no extra metadata, default timestamp');

  my $obj = WTSI::NPG::iRODS::DataObject->new($irods, $remote_path);
  like($obj->get_avu($DCTERMS_CREATED)->{value}, qr{^$timestamp_regex$},
       'New object default creation timestamp') or diag explain $obj->metadata;

  is($obj->get_avu($DCTERMS_CREATOR)->{value}, 'http://www.sanger.ac.uk',
     'New object creator URI') or diag explain $obj->metadata;

  ok(URI->new($obj->get_avu($DCTERMS_PUBLISHER)->{value}), 'Publisher URI') or
    diag explain $obj->metadata;

  is($obj->get_avu($FILE_MD5)->{value}, 'a9fdbcfbce13a3d8dee559f58122a31c',
     'New object MD5') or diag explain $obj->metadata;
}

sub pf_new_full_path_meta_no_stamp {
  my ($irods, $data_path, $coll_path) = @_;

  my $publisher = WTSI::NPG::iRODS::Publisher->new(irods => $irods);

  # publish_file with new full path, some metadata, no timestamp
  my $local_path_a = "$tmp_data_path/publish_file/a.txt";
  my $remote_path = "$coll_path/pf_new_full_path_meta_no_stamp.txt";
  my $extra_avu1 = $irods->make_avu($RT_TICKET, '1234567890');
  my $extra_avu2 = $irods->make_avu($ANALYSIS_UUID,
                                    'abcdefg-01234567890-wxyz');
  # Should support AVUs with multiple values
  my $extra_multival_avu1 = $irods->make_avu('x', '777');
  my $extra_multival_avu2 = $irods->make_avu('x', '999');

  is($publisher->publish_file($local_path_a, $remote_path,
                              [$extra_avu1, $extra_avu2,
                               $extra_multival_avu1, $extra_multival_avu2]
                          )->str(),
     $remote_path,
     'publish_file, full path, extra metadata, default timestamp');

  my $obj = WTSI::NPG::iRODS::DataObject->new($irods, $remote_path);

  is($obj->get_avu($DCTERMS_CREATOR)->{value}, 'http://www.sanger.ac.uk',
     'New object creator URI') or diag explain $obj->metadata;

  ok(URI->new($obj->get_avu($DCTERMS_PUBLISHER)->{value}), 'Publisher URI') or
    diag explain $obj->metadata;

  is($obj->get_avu($FILE_MD5)->{value}, 'a9fdbcfbce13a3d8dee559f58122a31c',
     'New object MD5') or diag explain $obj->metadata;

  is($obj->get_avu($RT_TICKET)->{value}, $extra_avu1->{value},
     'New extra AVU 1') or diag explain $obj->metadata;

  is($obj->get_avu($ANALYSIS_UUID)->{value}, $extra_avu2->{value},
     'New extra AVU 2') or diag explain $obj->metadata;

  my @observed_values = map { $_->{value} } $obj->find_in_metadata('x');
  my @expected_values = (777, 999);
  is_deeply(\@observed_values, \@expected_values, 'New multival AVU') or
    diag explain $obj->metadata;
}

sub pf_new_full_path_no_meta_stamp {
  my ($irods, $data_path, $coll_path) = @_;

  my $publisher = WTSI::NPG::iRODS::Publisher->new(irods => $irods);

  # publish_file with new full path, no metadata, no timestamp
  my $timestamp = DateTime->now;
  my $local_path_a = "$tmp_data_path/publish_file/a.txt";
  my $remote_path = "$coll_path/pf_new_full_path_no_meta_stamp.txt";

  is($publisher->publish_file($local_path_a,
                              $remote_path,
                              [],
                              $timestamp)->str(),
     $remote_path,
     'publish_file, full path, no extra metadata, supplied timestamp');

  my $obj = WTSI::NPG::iRODS::DataObject->new($irods, $remote_path);
  is($obj->get_avu($DCTERMS_CREATED)->{value}, $timestamp->iso8601,
     'New object supplied creation timestamp') or diag explain $obj->metadata;

  is($obj->get_avu($DCTERMS_CREATOR)->{value}, 'http://www.sanger.ac.uk',
     'New object creator URI') or diag explain $obj->metadata;

  ok(URI->new($obj->get_avu($DCTERMS_PUBLISHER)->{value}), 'Publisher URI') or
    diag explain $obj->metadata;

  is($obj->get_avu($FILE_MD5)->{value}, 'a9fdbcfbce13a3d8dee559f58122a31c',
     'New object MD5') or diag explain $obj->metadata;
}

sub pf_exist_full_path_no_meta_no_stamp_match {
  my ($irods, $data_path, $coll_path) = @_;

  my $publisher = WTSI::NPG::iRODS::Publisher->new(irods => $irods);

  # publish_file with existing full path, no metadata, no timestamp,
  # matching MD5
  my $local_path_a = "$tmp_data_path/publish_file/a.txt";
  my $remote_path = "$coll_path/pf_exist_full_path_no_meta_no_stamp_match.txt";
  $publisher->publish_file($local_path_a, $remote_path) or fail;

  my $obj = WTSI::NPG::iRODS::DataObject->new($irods, $remote_path);
  ok(!$obj->get_avu($DCTERMS_MODIFIED), 'No modification timestamp before');

  is($publisher->publish_file($local_path_a, $remote_path)->str(),
     $remote_path,
     'publish_file, existing full path, MD5 match');

  $obj->clear_metadata;
  ok(!$obj->get_avu($DCTERMS_MODIFIED), 'No modification AVU after') or
    diag explain $obj->metadata;
}

sub pf_exist_full_path_meta_no_stamp_match {
  my ($irods, $data_path, $coll_path) = @_;

  my $publisher = WTSI::NPG::iRODS::Publisher->new(irods => $irods);

  # publish_file with existing full path, some metadata, no timestamp,
  # matching MD5
  my $local_path_a = "$tmp_data_path/publish_file/a.txt";
  my $remote_path = "$coll_path/pf_exist_full_path_meta_no_stamp_match.txt";
  my $extra_avu1 = $irods->make_avu($RT_TICKET, '1234567890');
  my $extra_avu2 = $irods->make_avu($ANALYSIS_UUID,
                                    'abcdefg-01234567890-wxyz');
  # Should support AVUs with multiple values
  my $extra_multival_avu1 = $irods->make_avu('x', '777');
  my $extra_multival_avu2 = $irods->make_avu('x', '999');

  $publisher->publish_file($local_path_a, $remote_path) or fail;

  my $obj = WTSI::NPG::iRODS::DataObject->new($irods, $remote_path);
  ok(!$obj->get_avu($DCTERMS_MODIFIED), 'No modification timestamp before');
  ok(!$obj->get_avu($RT_TICKET), 'No extra AVU 1 before');
  ok(!$obj->get_avu($ANALYSIS_UUID), 'No extra AVU 2 before');
  ok(!$obj->get_avu('x'), 'No extra multival AVU before');

  is($publisher->publish_file($local_path_a, $remote_path,
                              [$extra_avu1, $extra_avu2,
                               $extra_multival_avu1, $extra_multival_avu2]
                          )->str(),
     $remote_path,
     'publish_file, existing full path, MD5 match');

  $obj->clear_metadata;
  ok(!$obj->get_avu($DCTERMS_MODIFIED), 'No modification AVU after') or
    diag explain $obj->metadata;

  is($obj->get_avu($RT_TICKET)->{value}, $extra_avu1->{value},
     'New extra AVU 1') or diag explain $obj->metadata;

  is($obj->get_avu($ANALYSIS_UUID)->{value}, $extra_avu2->{value},
     'New extra AVU 2') or diag explain $obj->metadata;

  my @observed_values = map { $_->{value} } $obj->find_in_metadata('x');
  my @expected_values = (777, 999);
  is_deeply(\@observed_values, \@expected_values, 'New multival AVU') or
    diag explain $obj->metadata;
}

sub pf_exist_full_path_no_meta_no_stamp_no_match {
  my ($irods, $data_path, $coll_path) = @_;

  my $publisher = WTSI::NPG::iRODS::Publisher->new(irods => $irods);

  # publish_file with existing full path, no metadata, no timestamp,
  # non-matching MD5
  my $timestamp_regex = '\d{4}-\d{2}-\d{2}T\d{2}:\d{2}:\d{2}';
  my $local_path_a = "$tmp_data_path/publish_file/a.txt";
  my $remote_path =
    "$irods_tmp_coll/pf_exist_full_path_no_meta_no_stamp_no_match";
  $publisher->publish_file($local_path_a, $remote_path) or fail;
  my $obj = WTSI::NPG::iRODS::DataObject->new($irods, $remote_path);
  ok(!$obj->get_avu($DCTERMS_MODIFIED), 'No modification timestamp before');

  my $local_path_b = "$data_path/publish_file/b.txt";
  is($publisher->publish_file($local_path_b, $remote_path)->str(),
     $remote_path,
     'publish_file, existing full path, MD5 non-match');

  $obj->clear_metadata;
  like($obj->get_avu($DCTERMS_MODIFIED)->{value},qr{^$timestamp_regex$},
       'Modification AVU present after') or diag explain $obj->metadata;
}

sub pf_exist_full_path_meta_no_stamp_no_match {
  my ($irods, $data_path, $coll_path) = @_;

  my $publisher = WTSI::NPG::iRODS::Publisher->new(irods => $irods);

  # publish_file with existing full path, some metadata, no timestamp,
  # non-matching MD5
  my $timestamp_regex = '\d{4}-\d{2}-\d{2}T\d{2}:\d{2}:\d{2}';
  my $local_path_a = "$tmp_data_path/publish_file/a.txt";
  my $remote_path =
    "$irods_tmp_coll/pf_exist_full_path_meta_no_stamp_no_match.txt";
  my $extra_avu1 = $irods->make_avu($RT_TICKET, '1234567890');
  my $extra_avu2 = $irods->make_avu($ANALYSIS_UUID,
                                    'abcdefg-01234567890-wxyz');
  $publisher->publish_file($local_path_a, $remote_path) or fail;
  my $obj = WTSI::NPG::iRODS::DataObject->new($irods, $remote_path);
  ok(!$obj->get_avu($DCTERMS_MODIFIED), 'No modification timestamp before');
  ok(!$obj->get_avu($RT_TICKET), 'No extra AVU 1 before');
  ok(!$obj->get_avu($ANALYSIS_UUID), 'No extra AVU 2 before');

  my $local_path_b = "$data_path/publish_file/b.txt";
  is($publisher->publish_file($local_path_b, $remote_path,
                              [$extra_avu1, $extra_avu2])->str(),
     $remote_path,
     'publish_file, existing full path, MD5 non-match');

  $obj->clear_metadata;
  like($obj->get_avu($DCTERMS_MODIFIED)->{value}, qr{^$timestamp_regex$},
       'Modification AVU present after') or diag explain $obj->metadata;

  is($obj->get_avu($RT_TICKET)->{value}, $extra_avu1->{value},
     'New extra AVU 1') or diag explain $obj->metadata;

  is($obj->get_avu($ANALYSIS_UUID)->{value}, $extra_avu2->{value},
     'New extra AVU 2') or diag explain $obj->metadata;
}

sub pd_new_full_path_no_meta_no_stamp {
  my ($irods, $data_path, $coll_path) = @_;

  my $publisher = WTSI::NPG::iRODS::Publisher->new(irods => $irods);

  # publish_directory with new full path, no metadata, no timestamp
  my $timestamp_regex = '\d{4}-\d{2}-\d{2}T\d{2}:\d{2}:\d{2}';
  my $local_path = "$tmp_data_path/publish_directory";

  my $remote_path = "$coll_path/pd_new_full_path_no_meta_no_stamp";
  my $sub_coll = "$remote_path/publish_directory";
  is($publisher->publish_directory($local_path, $remote_path)->str(),
     $sub_coll,
     'publish_directory, full path, no extra metadata, default timestamp');

  my $coll = WTSI::NPG::iRODS::Collection->new($irods, $sub_coll);
  like($coll->get_avu($DCTERMS_CREATED)->{value}, qr{^$timestamp_regex$},
       'New object default creation timestamp') or diag explain $coll->metadata;

  is($coll->get_avu($DCTERMS_CREATOR)->{value}, 'http://www.sanger.ac.uk',
     'New object creator URI') or diag explain $coll->metadata;

  ok(URI->new($coll->get_avu($DCTERMS_PUBLISHER)->{value}), 'Publisher URI') or
    diag explain $coll->metadata;
}

sub pd_new_full_path_meta_no_stamp {
  my ($irods, $data_path, $coll_path) = @_;

  my $publisher = WTSI::NPG::iRODS::Publisher->new(irods => $irods);

  # publish_directory with new full path, no metadata, no timestamp
  my $timestamp_regex = '\d{4}-\d{2}-\d{2}T\d{2}:\d{2}:\d{2}';
  my $local_path = "$tmp_data_path/publish_directory";
  my $extra_avu1 = $irods->make_avu($RT_TICKET, '1234567890');
  my $extra_avu2 = $irods->make_avu($ANALYSIS_UUID,
                                    'abcdefg-01234567890-wxyz');

  my $remote_path = "$coll_path/pd_new_full_path_meta_no_stamp";
  my $sub_coll = "$remote_path/publish_directory";
  is($publisher->publish_directory($local_path, $remote_path,
                                   [$extra_avu1, $extra_avu2])->str(),
     $sub_coll,
     'publish_directory, full path, no extra metadata, default timestamp');

  my $coll = WTSI::NPG::iRODS::Collection->new($irods, $sub_coll);
  like($coll->get_avu($DCTERMS_CREATED)->{value}, qr{^$timestamp_regex$},
       'New object default creation timestamp') or diag explain $coll->metadata;

  like($coll->get_avu($DCTERMS_CREATED)->{value}, qr{^$timestamp_regex$},
       'New object default creation timestamp') or diag explain $coll->metadata;

  is($coll->get_avu($DCTERMS_CREATOR)->{value}, 'http://www.sanger.ac.uk',
     'New object creator URI') or diag explain $coll->metadata;

  ok(URI->new($coll->get_avu($DCTERMS_PUBLISHER)->{value}), 'Publisher URI') or
    diag explain $coll->metadata;

  is($coll->get_avu($RT_TICKET)->{value}, $extra_avu1->{value},
     'New extra AVU 1') or diag explain $coll->metadata;

  is($coll->get_avu($ANALYSIS_UUID)->{value}, $extra_avu2->{value},
     'New extra AVU 2') or diag explain $coll->metadata;
}

sub pf_stale_md5_cache {
  my ($irods, $data_path, $coll_path) = @_;

  my $cache_timeout = 10;
  my $publisher = WTSI::NPG::iRODS::Publisher->new
    (irods                     => $irods,
     checksum_cache_time_delta => $cache_timeout);

  my $local_path_c = "$tmp_data_path/publish_file/c.txt";
  my $remote_path = "$coll_path/pf_stale_md5_cache.txt";

  open my $md5_out, '>>', "$local_path_c.md5"
    or die "Failed to open $local_path_c.md5 for writing";
  print $md5_out "fake_md5_string\n";
  close $md5_out or warn "Failed to close $local_path_c.md5";

  sleep $cache_timeout + 5;

  open my $data_out, '>>', $local_path_c
    or die "Failed to open $local_path_c for writing";
  print $data_out "extra data\n";
  close $data_out or warn "Failed to close $local_path_c";

  is($publisher->publish_file($local_path_c, $remote_path)->str(),
     $remote_path,
     'publish_file, stale MD5 cache');

  my $obj = WTSI::NPG::iRODS::DataObject->new($irods, $remote_path);
  is($obj->get_avu($FILE_MD5)->{value}, 'c8a3fa18c7c1402c953415a6b4f8ef7d',
     'Stale MD5 was regenerated') or diag explain $obj->metadata;
}

####################################################################
# private methods for repeated tests

sub _get_subscriber_args {
    my ($channel, ) = @_;
    my $args = {
        hostname             => $test_host, # global variable
        rmq_config_path      => $conf,      # global variable
        channel              => $channel,
    };
    return $args;
}

sub _test_object_message {
    my ($message, $method, $expected_body, $irods) = @_;
    # 11 tests in total
    return _test_message($message, $method, $expected_body, $irods, 1);
}

sub _test_message {
  # General-purpose method to test RabbitMQ messages.
  #
  # TODO remove duplication with method in ReporterTest.pm
  #
  # Arguments:
  # - [ArrayRef] RabbitMQ message, consisting of body and headers
  # - [Str] Method name
  # - [HashRef] Expected body of message.
  # - [WTSI::NPG::iRODS] iRODS object, used for sorting AVUs
  # - [Bool] Flag to indicate a data object (as opposed to a collection)
  #
  # Tests performed:
  # - Exact values of method, user, and irods_user headers
  # - Format of timestamp header
  # - Presence of file type header (value may be an empty string)
  # - Exact values of collection, data object and AVUs (if any) in body

  my ($message, $method, $expected_body, $irods, $is_data_object) = @_;
  my $expected_headers = 5; # timestamp, user, irods_user, type, method
  my $expected_body_keys_total = scalar keys(%{$expected_body});

  my $total_tests = 10;
  if ($is_data_object) { $total_tests++; }

  my $skip = not defined($message);
  if ($skip) {
    $log->logwarn('Unexpectedly got an undefined message from RabbitMQ; ',
          'skipping subsequent tests on content of the message');
  }
 SKIP: {
   # If message undefined, skip tests on content to improve readability
   # Distinct from option to skip all RabbitMQ tests; see TestRabbitMQ.pm
    skip "RabbitMQ message not defined", $total_tests if $skip;
    my ($body, $headers) = @{$message};

    # expected number of header/body fields
    ok(scalar keys(%{$headers}) == $expected_headers,
       'Found '.$expected_headers.' header key/value pairs.');
    ok(scalar keys(%{$body}) == $expected_body_keys_total,
       'Found '.$expected_body_keys_total.' body key/value pairs.');

    # check content of headers
    ok($headers->{'method'} eq $method, "Header method name is $method");
    my $time = $headers->{'timestamp'};
    ok($time =~ /\d{4}-\d{2}-\d{2}T\d{2}:\d{2}:\d{2}\.\d{6}/msx,
       "Header timestamp '$time' is in correct format");
    my $user = $ENV{'USER'};
    ok($headers->{'user'} eq $user, "Header user name is $user");
    ok($headers->{'irods_user'} eq $user, "Header iRODS user name is $user");
    ok(defined $headers->{'type'},
       "Header file type is defined (may be an empty string)");

    # check content of body
    ok($body->{'collection'} eq $expected_body->{'collection'},
       'Collection matches expected value');
    if ($is_data_object) {
      ok($body->{'data_object'} eq $expected_body->{'data_object'},
     'Data object matches expected value');
    }
    # sort AVUs to ensure consistent order for comparison
    my @avus = $irods->sort_avus(@{$body->{'avus'}});
    my @expected_avus = $irods->sort_avus(@{$expected_body->{'avus'}});
    is_deeply(\@avus, \@expected_avus, 'AVUs match expected values');
    # sort ACL to ensure consistent order for comparison
    my @acl = $irods->sort_acl(@{$body->{'acl'}});
    my @expected_acl = $irods->sort_acl(@{$expected_body->{'acl'}});
    is_deeply(\@acl, \@expected_acl, 'ACL matches expected value');


  }
}


1;
