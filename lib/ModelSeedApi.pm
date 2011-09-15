package ModelSeedApi;
use Dancer ':syntax';
use ModelSEED::FIGMODEL;
use ServerThing;
use JSON::Any;
our $VERSION = '0';

my $fbamodel = ServerThing->new("ModelSEED::FBAMODEL");

#any [qw(get post put delete head)] => qr{^/(\D*.?)} => sub {
#    my ($part) = splat;
#    warning "redirecting " . request->uri . " to /$VERSION/$part";
#    redirect "/$VERSION/$part"
#};


any [qw(get post put delete head)] => qr{^/(\d+)/(.*)} => sub { 
    my ($version) = splat;
    if($version ne $VERSION) {
        # try to look for version supplied
        send_error("Unknown version $version", 404);
    } else {
        prefix "/$VERSION";
        return pass();
    }
};

prefix "/$VERSION" => sub {

    get '/FBAMODEL.cgi' => sub {
        my %params = params;
        return $fbamodel->call(\%params);
    };

    get '/' => sub {
        redirect '/doc';
    };
    get '/doc' => sub {
        return template 'index';
    };
};

true;
