package Koha::Plugin::Com::Biblibre::BnfCovers::Controller::Index;

# This file is part of Koha.
#
# Koha is free software; you can redistribute it and/or modify it under the
# terms of the GNU General Public License as published by the Free Software
# Foundation; either version 3 of the License, or (at your option) any later
# version.
#
# Koha is distributed in the hope that it will be useful, but WITHOUT ANY
# WARRANTY; without even the implied warranty of MERCHANTABILITY or FITNESS FOR
# A PARTICULAR PURPOSE.  See the GNU General Public License for more details.
#
# You should have received a copy of the GNU General Public License along
# with Koha; if not, write to the Free Software Foundation, Inc.,
# 51 Franklin Street, Fifth Floor, Boston, MA 02110-1301 USA.

use Modern::Perl;
use Mojo::Base 'Mojolicious::Controller';
use C4::Context;

=head1 API

=head2 Methods

Controller function that handles getting Bnf covers

=cut

sub get_bnf_ark {
    my $c = shift->openapi->valid_input or return;

    my $biblionumber = $c->param('biblionumber');

    my $biblio = Koha::Biblios->find($biblionumber);
    if ($biblio) {
        my $marc_record = $biblio->metadata->record;

        if ( my $field_003 = $marc_record->field('003') ) {
            if ( $field_003->data() =~ m{http://catalogue\.bnf\.fr/(.*)} ) {
                my $ark = $1;
                return $c->render(json => { data => $ark });
            }
        }
        return $c->render(json => { error => 'ARK compatible with BNF not found in the record.' }, status => 404);
    }
    return $c->render(json => { error => 'Biblionumber not found.' }, status => 404);
}

1;
