package Koha::Plugin::Com::Biblibre::BnfCovers;

use Modern::Perl;
use base       qw(Koha::Plugins::Base);
use Mojo::JSON qw(decode_json);
use C4::Context;

our $VERSION         = "1.0";
our $MINIMUM_VERSION = "23.05";

our $metadata = {
    name            => 'Plugin BnfCovers',
    author          => 'Thibaud Guillot',
    date_authored   => '2025-08-25',
    date_updated    => "2025-08-25",
    minimum_version => $MINIMUM_VERSION,
    maximum_version => undef,
    version         => $VERSION,
    description     => 'This plugin implements enhanced content from Bnf',
    namespace       => 'bnf',
};

sub new {
    my ( $class, $args ) = @_;

    $args->{'metadata'} = $metadata;
    $args->{'metadata'}->{'class'} = $class;
    my $self = $class->SUPER::new($args);

    return $self;
}

# Mandatory even if does nothing
sub install {
    my ( $self, $args ) = @_;
    return 1;
}

# Mandatory even if does nothing
sub upgrade {
    my ( $self, $args ) = @_;

    return 1;
}

# Mandatory even if does nothing
sub uninstall {
    my ( $self, $args ) = @_;

    return 1;
}

sub api_routes {
    my ( $self, $args ) = @_;

    my $spec_dir = $self->mbf_dir();

    my $schema = JSON::Validator::Schema::OpenAPIv2->new;
    my $spec   = $schema->resolve( $spec_dir . '/openapi.yaml' );

    return $self->_convert_refs_to_absolute( $spec->data->{'paths'},
        'file://' . $spec_dir . '/' );
}

sub api_namespace {
    my ($self) = @_;

    return 'bnf';
}

sub _convert_refs_to_absolute {
    my ( $self, $hashref, $path_prefix ) = @_;

    foreach my $key ( keys %{$hashref} ) {
        if ( $key eq '$ref' ) {
            if ( $hashref->{$key} =~ /^(\.\/)?openapi/ ) {
                $hashref->{$key} = $path_prefix . $hashref->{$key};
            }
        }
        elsif ( ref $hashref->{$key} eq 'HASH' ) {
            $hashref->{$key} =
              $self->_convert_refs_to_absolute( $hashref->{$key},
                $path_prefix );
        }
        elsif ( ref( $hashref->{$key} ) eq 'ARRAY' ) {
            $hashref->{$key} =
              $self->_convert_array_refs_to_absolute( $hashref->{$key},
                $path_prefix );
        }
    }
    return $hashref;
}

sub _convert_array_refs_to_absolute {
    my ( $self, $arrayref, $path_prefix ) = @_;

    my @res;
    foreach my $item ( @{$arrayref} ) {
        if ( ref($item) eq 'HASH' ) {
            $item = $self->_convert_refs_to_absolute( $item, $path_prefix );
        }
        elsif ( ref($item) eq 'ARRAY' ) {
            $item =
              $self->_convert_array_refs_to_absolute( $item, $path_prefix );
        }
        push @res, $item;
    }
    return \@res;
}

sub intranet_cover_images {
    my ($self) = @_;
    my $cgi = $self->{'cgi'};

    my $js = <<"JS";
<script>
    function addBnfCover(e) {
        const search_results_images = document.querySelectorAll('.cover-slides, .cover-slider');
        const divDetail = document.querySelector('#catalogue_detail_biblio');
        const onResultPage = divDetail ? false : true;
        const getUrlParameter = (name) => new URLSearchParams(window.location.search).get(name);

        if (search_results_images.length) {
            const biblionumbers = [];
            document.addEventListener('DOMContentLoaded', function() {
                search_results_images.forEach((div) => {
                    let biblionumber;
                    if (onResultPage) {
                        biblionumber = div.dataset.biblionumber;
                    } else {
                        biblionumber = getUrlParameter('biblionumber');
                        const emptyCover = `
                            <div id="bnf-bookcoverimg" class="cover-image bnf-bookcoverimg">
                                <a href="#">
                                    <img class="bnf-cover" style="max-width:100px;max-height:160px;" alt="Bnf cover image" />
                                </a>
                                <div class="hint">Image from Bnf</div>
                            </div>
                        `;
                        div.insertAdjacentHTML('beforeend', emptyCover);
                    }

                    \$.get('/api/v1/contrib/bnf/bnf-ark', { biblionumber: biblionumber })
                        .done((response) => {
                            if (response && response.success && response.data && response.data.trim() !== '') {
                                const ark = response.data;
                                const coverSrc = "https://catalogue.bnf.fr/couverture?appName=NE&idArk=" + ark + "&couverture=1";
                                const coverStyle = "max-width:100px;max-height:160px;";
                                const link = div.dataset.processedbiblio ? div.dataset.processedbiblio : coverSrc;
                                let bnfCover;
                                if(onResultPage){
                                    bnfCover = `
                                        <div id="bnf-bookcoverimg-\${biblionumber}" class="cover-image bnf-bookcoverimg">
                                            <a href="\${link}">
                                                <img class="bnf-cover" src="\${coverSrc}" style="\${coverStyle}" alt="Bnf cover image" />
                                            </a>
                                            <div class="hint">Bnf cover image</div>
                                        </div>
                                    `;

                                    div.insertAdjacentHTML('beforeend', bnfCover);
                                } else {
                                    bnfCover = \$("#bnf-bookcoverimg");
                                    bnfCover.find('img').attr('src', coverSrc);
                                    bnfCover.find('a').attr('href', coverSrc);
                                }
                            }
                            if (onResultPage) {
                                const length = document.querySelectorAll('.bnf-cover').length;
                                let i = 0;
                                document.querySelectorAll('.bnf-cover').forEach((img) => {
                                    img.onload = () => {
                                        i++;
                                        if (i === length) {
                                            verify_cover_images();
                                        }
                                    };
                                });
                                const noImageDiv = div.querySelector('div.no-image');
                                if (noImageDiv) {
                                    noImageDiv.remove();
                                }
                            } else {
                                bnfCover = \$("#bnf-bookcoverimg");
                                if(!bnfCover.find('img').attr('src')){
                                    bnfCover.remove();
                                    verify_cover_images();
                               }
                            }
                        });
                });
            });
        }
    }
    document.addEventListener('DOMContentLoaded', addBnfCover, true);
</script>
JS

    return $js;
}

sub opac_cover_images {
    my ($self) = @_;
    my $cgi = $self->{'cgi'};

    my $js = <<"JS";
    <script>
        function addBnfCover(e) {
            const search_results_images = document.querySelectorAll('.cover-slides, .cover-slider');
            const divDetail = \$('#catalogue_detail_biblio');
            const onResultPage = divDetail.length ? false : true;
            const getUrlParameter = (name) => new URLSearchParams(window.location.search).get(name);
            const existingCovers = document.querySelectorAll('.cover-image');
            let coverClasses = "bnf-bookcoverimg";
            if(existingCovers.length == 0){
                coverClasses += " cover-image";
            }

            if (search_results_images.length) {
                const biblionumbers = [];
                document.addEventListener('DOMContentLoaded', function() {
                    search_results_images.forEach((div) => {
                        let biblionumber;
                        let divId;
                        if (onResultPage) {
                            biblionumber = div.dataset.biblionumber;
                            divId = "bnf-bookcoverimg" + biblionumber;
                        } else {
                            biblionumber = getUrlParameter('biblionumber');
                            divId = "bnf-bookcoverimg";
                        }
                        const emptyCover = `
                            <div id="\${divId}" class="\${coverClasses}">
                                <a href="#" title="Bnf cover image">
                                    <img class="bnf-cover" style="max-width:100px;max-height:160px;" alt="Bnf cover image" />
                                </a>
                                <div class="hint">Image from Bnf</div>
                            </div>
                        `;

                        div.insertAdjacentHTML('beforeend', emptyCover);

                        \$.get('/api/v1/contrib/bnf/bnf-ark', { biblionumber: biblionumber })
                            .done((response) => {
                                const bnfCover = onResultPage ? \$("#bnf-bookcoverimg" + biblionumber) : \$("#bnf-bookcoverimg");
                                if (response && response.success && response.data && response.data.trim() !== '') {
                                    const ark = response.data;
                                    const coverSrc = "https://catalogue.bnf.fr/couverture?appName=NE&idArk=" + ark + "&couverture=1";
                                    const coverStyle = "max-width:100px;max-height:160px;";
                                    bnfCover.addClass('cover-image');
                                    if (onResultPage) {
                                        bnfCover.find('img').attr('src', coverSrc);
                                        bnfCover.find('a').attr('href', coverSrc);
                                    } else {
                                        bnfCover.find('img').attr('src', coverSrc);
                                        bnfCover.find('a').attr('href', coverSrc);
                                    }
                                    
                                } else {
                                    bnfCover.remove();
                                    if(!onResultPage) {
                                        verify_cover_images();
                                    }
                                }
                            });
                    });
                    if(onResultPage) {
                        setTimeout(() => {
                            verify_cover_images();
                        }, 1000);
                    }
                });
            }
        }

        document.addEventListener('DOMContentLoaded', addBnfCover, true);
    </script>
JS

    return "$js";
}

1;
