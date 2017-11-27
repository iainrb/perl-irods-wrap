package WTSI::NPG::iRODS::Test;

use strict;
use warnings;

use base qw(Test::Class);
use Test::More;

# Run full tests (requiring a test iRODS server) only if TEST_AUTHOR
# is true. If full tests are run, require that both irodsEnvFile
# IRODS_ENVIRONMENT_FILE and be set. This is for safety because we do
# not know which of 3.x or 4.x clients will be first on the PATH. The
# unused variable may be set to a dummy value.

sub runtests {
  my ($self) = @_;

  my %env_copy = %ENV;

  # iRODS 3.* and iRODS 4.* have different env vars for configuration
  foreach my $file (qw(irodsEnvFile IRODS_ENVIRONMENT_FILE)) {
    my $env_file = $ENV{"WTSI_NPG_iRODS_Test_$file"} || q[];

    # Ensure that the iRODS connection details are a nonsense value if
    # they are not set explicitly via WTSI_NPG_iRODS_Test_*
    $env_copy{$file} = $env_file || 'DUMMY_VALUE';

    if (not $env_file) {
      if ($ENV{TEST_AUTHOR}) {
        die "Environment variable WTSI_NPG_iRODS_Test_$file was not set";
      }
      else {
        $self->SKIP_CLASS('TEST_AUTHOR environment variable is false');
      }
    }
  }
  my $run_tests;
  my $skip_msg; # message to print if skipping tests
  if (! defined $ENV{TEST_RABBITMQ}) {
      $run_tests = $ENV{TEST_AUTHOR};
      $skip_msg = 'TEST_RABBITMQ environment variable not set; '.
          'TEST_AUTHOR false or not set'
      } else {
          $run_tests = $ENV{TEST_RABBITMQ};
          $skip_msg = 'TEST_RABBITMQ environment variable is false';
      }
  if (! $run_tests) {
      diag('Omitting RabbitMQ tests: Either TEST_RABBITMQ is set to ',
           'false; or TEST_RABBITMQ is not set, and TEST_AUTHOR ',
           'is false or not set');
      $self->SKIP_CLASS($skip_msg);
  } else {
      # optional modules, needed for RabbitMQ tests
      require WTSI::NPG::iRODSMQTest;
      require WTSI::NPG::PublisherMQTest;
      require WTSI::NPG::RabbitMQ::TestCommunicator;
  }

  {
    local %ENV = %env_copy;
    return $self->SUPER::runtests;
  }
}

# If any test methods fail to complete, count all their remaining
# tests as failures.
sub fail_if_returned_early {
  return 1;
}

sub have_admin_rights {
  my ($self, $have_rights) = @_;

  if (defined $have_rights) {
    $self->{_have_admin_rights} = $have_rights;
  }

  return $self->{_have_admin_rights};
}

sub add_irods_groups {
  my ($self, $irods, @groups) = @_;

  my @groups_added;
  foreach my $group (@groups) {
    if ($self->have_admin_rights and not $irods->group_exists($group)) {
      push @groups_added, $irods->add_group($group);
    }
  }

  return @groups_added;
}

sub remove_irods_groups {
  my ($self, $irods, @groups) = @_;

  my @groups_removed;
  foreach my $group (@groups) {
    if ($self->have_admin_rights and $irods->group_exists($group)) {
      push @groups_removed, $irods->remove_group($group);
    }
  }

  return @groups_removed;
}

1;
