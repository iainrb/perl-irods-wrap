package WTSI::NPG::TestMQPublisher;

use Moose;

use WTSI::NPG::iRODS::Publisher;

extends 'WTSI::NPG::iRODS::Publisher';

with qw[WTSI::NPG::iRODS::Reportable::PublisherMQ];


### temporary subroutines to enable PublisherMQ role

sub get_irods_user {
    my ($self,) = @_;
    return $self->irods->get_irods_user;
}


sub list_path_details {
    my ($self, $path) = @_;
    return $self->irods->list_path_details($path);
}

__PACKAGE__->meta->make_immutable;

no Moose;

1;
