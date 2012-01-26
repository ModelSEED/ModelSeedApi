package ModelSeedApi;
use Dancer ':syntax';
use ModelSEED::FIGMODEL;
use ModelSEED::ObjectManager;
use ModelSEED::Api;
use ServerThing;
use JSON::Any;
use Data::Dumper;
our $VERSION = '0';

my $fbamodel = ServerThing->new("ModelSEED::FBAMODEL");
my $om       = ModelSEED::ObjectManager->new({
    database => "/Users/devoid/Desktop/Core/test.db",
    driver   => "sqlite",
});
my $api;

# redirect any /path to /$VERSION/path for versioning
any [qw(get post put delete head)] => qr{^/(\D*.?)} => sub {
    my ($part) = splat;
    redirect "/$VERSION/$part"
};

# handle version numbers
any [qw(get post put delete head)] => qr{^/(\d+)/(.*)} => sub { 
    my ($version) = splat;
    if($version ne $VERSION) {
        # try to look for version supplied
        send_error("Unknown version $version", 404);
    } else {
        prefix "/$VERSION";
        unless(defined($api)) { # create the api object now (need root path) 
            $api = ModelSEED::Api->new({ om => $om, url_root => uri_for("/$VERSION/")->as_string});
        }
        return pass();
    }
};

prefix "/$VERSION" => sub {
    content_type 'application/json';
    get '/FBAMODEL.cgi' => sub {
        my %params = params;
        return $fbamodel->call(\%params);
    };
    get '/' => sub {
        redirect "/$VERSION/docs";
    };
    get '/docs' => sub {
        content_type 'text/html';
        return template 'index';
    };

    get qr{/.*} => sub {
        content_type 'application/json';
        my $path = request->path;
        $path =~ s/\/$VERSION\///;
        my $params = params;
        return to_json( $api->serialize($path, $params), { utf8 => 1, pretty => 1 });
    };
=head
    # want routes for
    # biochem, mapping, then model, annotation, roleset
    get '/biochem' => sub {
        my $params = params;
        $params->{limit} = $params->{limit} || 30;
        $params->{offset} = $params->{offset} || 0;
        my $objs = $om->get_objects('biochemistry', query => [],
            limit => $params->{limit}, offeset => $params->{offset});
        return to_json([ map { ModelSEED::Api::Serialize::prepareForWeb($_->serialize($params), uri_for('/')) } @$objs ], { utf8 => 1, pretty => 1 });
    };

    get '/biochem/:uuid' => sub {
        my $obj = $om->get_object('biochemistry', { uuid => param('uuid') });
        my $params = params;
        foreach my $key (keys %$params) {
            $params->{$key} = from_json($params->{$key});
        }
        if(defined($obj)) {
            return to_json(ModelSEED::Api::Serialize::prepareForWeb($obj->serialize($params), uri_for('/')), { utf8 => 1, pretty => 1 });
        } else {
            send_error("Object not found", 404);
        }
    };


    get '/biochem/:uuid/reactions' => sub {
        my $params = params;
        my $bio = $om->get_object('biochemistry', { uuid => param('uuid') });
        unless(defined($bio)) {
            send_error("Object not found", 404);
        }
        $params->{limit} = (defined $params->{limit}) ? $params->{limit} : 30;
        $params->{offset} = (defined $params->{offset}) ? $params->{offset} : 0;
        my $end = $params->{offset} + $params->{limit} - 1;
        my @arr = $bio->reactions;
        @arr = @arr[$params->{offset}..$end];
        return to_json([map { ModelSEED::Api::Serialize::prepareForWeb($_, uri_for('/')) } map { $_->serialize({}) } @arr], { utf8 => 1, pretty => 1 });
    };
=cut

};

true;
