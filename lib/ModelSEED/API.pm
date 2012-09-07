package ModelSEED::API;
use Mojo::Base 'Mojolicious';
our $VERSION = 0;
use ModelSEED::Auth::Factory;
use ModelSEED::Store;
use IO::String;
use Pod::Text;


sub startup {
    my $self = shift;
    $self->plugin(PODRenderer => { no_perldoc => 1 });
    my $Auth  = ModelSEED::Auth::Factory->new->from_config;
    my $Store = ModelSEED::Store->new(auth => $Auth);
    $self->helper( Store => sub { $Store } );
    my $UuidRegex = qr/[a-f0-9]{8}-[a-f0-9]{4}-[a-f0-9]{4}-[a-f0-9]{4}-[a-f0-9]{12}/;
    my $TopLevelTypes = [qw(
        biochemistry
        mapping
        model
        fbaformulation
        gapfillingformulation
        annotation
    )];
    my $r = $self->routes;
    # Root path returns POD for this file,
    # format pod and send it as html
    $r->get('/' => sub {
        my $self = shift;
        my $buffer; 
        my $p = Pod::Simple::HTML->new;
        $p->output_string($buffer);
        $p->parse_file(__FILE__);
        $self->render(text => $buffer, format => 'html');
    });

    $r->add_shortcut(resource => sub {
        my ($r, $name, $methods) = @_;
        my $resource = $r->route("/")->to("$name#");
        $methods = { map { $_ => 1 } @$methods };
        if ($methods->{post}) { 
            $resource->post->to('#create')->name("create_$name");
        }
        if ($methods->{get}) {
            $resource->get->to('#show')->name("remove_$name");
        }
        if ($methods->{put}) {
            $resource->put->to("#update")->name("remove_$name");
        }
        return $resource;
    }); 

    # All remaining routes are under $VERSION
    $r = $r->under("/$VERSION");
    
    # Type listing route
    $r->get("/" => sub {
        my $self = shift;
        my $base = $self->req->url->base;
        my $data = {
            map { $_ => $base . "/$VERSION/" . $_ }
            @$TopLevelTypes
        };
        return $self->render(json => $data);
    });

    # Typed routes
    my $typed = $r->under("/:type" => [ type => $TopLevelTypes ]);
    $typed->get("/")->to("Aliases#list"); 

    # Typed with :uuid
    $typed->get("/:uuid" => [ uuid => $UuidRegex ])
          ->resource("object", [qw(get put)]);

    # Typed with :owner :alias
    $typed->under("/#owner/#alias")
          ->resource("object", [qw(get put)]);
    
    # Incomplete :owner , no alias
    $typed->get("/:owner")->to("Aliases#list");
}
1;
__DATA__

=head1 ModelSEED::API

REST API for the ModelSEED

=head2 Routes

    /0/
    /0/:type
    /0/:type/:uuid
    /0/:type/:uname
    /0/:type/:uname/:alias

Each route begins with the API version number,
which is currently C<0>. 

=over 4

=item C</0/>

=over 4

=item GET

Return a JSON hash where keys are the types and each value is the
URL of the collection resource for that type.

=back

=item C</0/:type/>

=over 4

=item GET

Return a JSON list of URLs that are resources available of that type.

=back

=item C</0/:type/:uuid>

=over 4

=item GET

Return an object of type C<:type> matched by its UUID C<:uuid>. 

=item PUT

If this object does not exist in the database, inserts the object
and returns 201. Otherwise fails, 403 Forbidden.

=back

=item C</0/:type/:uname>

=over 4

=item GET

Return a JSON list of URLs that are resources of the available type
C<:type> that are owned by the user with username C<:uname>.

=back

=item C</0/:type/:uname/:alias>

=over 4

=item GET

Get an object of type C<:type> owned by user with username
C<:uname> with alias C<:alias>.

=item PUT

Inserts the object and returns 201. Otherwise fails, 403 Forbidden.

=back

=back

=cut

