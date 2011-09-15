package ModelSeedApi;
use Dancer ':syntax';
use ModelSEED::FIGMODEL;
use ModelSEED::FBAMODEL;
use JSON::Any;
our $VERSION = '0';

my $fbamodel = ModelSEED::FBAMODEL->new();
my $j = JSON::Any->new;



any [qw(get post put delete head)] => qr{^/(\D*.?)} => sub {
    my ($part) = splat;
    warning "redirecting " . request->uri . " to /$VERSION/$part";
    redirect "/$VERSION/$part"
};


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
        my $functions = $fbamodel->methods();
        my $function = param "function";
        my $args     = (param "args") ? param "args" : "[]";
        my $encoding = (param "encoding") ? param "encoding" : "yaml"; 
        my $callback = param "callback";
        if($encoding eq "json") {
            content_type 'application/json';
            $args = $j->jsonToObj($args);
        }
        warning Dumper($args);
        my $data = [];
        if(defined($function) && ($function ~~ @$functions ||
           $function eq "methods")) {
           $data = $fbamodel->$function(@$args); 
        } else {
            send_error("Invalid function name.", 400);
            return;
        }
        if($encoding eq "json") {
            $data = $j->objToJson($data); 
        }
        if(defined($callback)) {
            $data = $callback . "(" . $data . ");";
        }
        return $data;
    };
        
    get '/' => sub {
        redirect "/docs"; 
    };
    get '/docs' => sub {
        template 'index';
    };
    
    get qr{.*} => sub {
        send_error("Unknown resource ".request->uri, 404);
    };
};

true;
