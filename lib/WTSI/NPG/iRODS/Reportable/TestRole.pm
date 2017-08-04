package WTSI::NPG::iRODS::Reportable::TestRole;

use strict;
use warnings;
use Moose::Role;

our $VERSION = '';


has 'runcible' =>
    (is       => 'ro',
     isa      => 'Str',
     default  => 'spoon',
     documentation => 'Dummy attribute for testing',
);


no Moose::Role;

1;


__END__

=head1 NAME

WTSI::NPG::iRODS::Reportable::TestRole

=head1 DESCRIPTION

Troubleshooting

=head1 AUTHOR

Iain Bancarz <ib5@sanger.ac.uk>

=head1 COPYRIGHT AND DISCLAIMER

Copyright (C) 2017 Genome Research Limited. All Rights Reserved.

This program is free software: you can redistribute it and/or modify
it under the terms of the Perl Artistic License or the GNU General
Public License as published by the Free Software Foundation, either
version 3 of the License, or (at your option) any later version.

This program is distributed in the hope that it will be useful,
but WITHOUT ANY WARRANTY; without even the implied warranty of
MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
GNU General Public License for more details.

=cut
