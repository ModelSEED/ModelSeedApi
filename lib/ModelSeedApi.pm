package ModelSeedApi;
use Dancer ':syntax';
use ModelSEED::FIGMODEL;
use ModelSEED::CoreApi;
use ServerThing;
use Data::Dumper;
use Try::Tiny;
use Time::HiRes qw(time);
use StatHat;

our $VERSION = '0';
our $STAT_EMAIL = $ENV{STATHAT_EMAIL};
set serializer => 'JSON';

my $fbamodel = ServerThing->new("ModelSEED::FBAMODEL");
my $om       = ModelSEED::CoreApi->new({
    database => "/Users/devoid/test.db",
    driver   => "sqlite",
});
my $StatHat = StatHat->new();

# handle version numbers
any [qw(get post put delete head)] => qr{^/(\d+)} => sub { 
    my ($version) = splat;
    var version => $version;
    if($version ne $VERSION) {
        # try to look for version supplied
        send_error("Unknown api version $version", 404);
    } else {
        pass();
    }
};

prefix "/$VERSION";

get "/FBAMODEL.cgi" => sub {
    my %params = params;
    return $fbamodel->call(\%params);
};

get '/docs' => sub {
    content_type 'text/html';
    return template 'index';
};

get '/biochemistry/:uuid/full' => sub {
    my $uuid = params->{uuid};
    my $data;
    my $time = time;
    try {
        $data = $om->getBiochemistry({ uuid => $uuid, with_all => 1 });
    } catch {
        send_error("Not Found", 404);
    };
    if($data) {
        $StatHat->value('biochemistry/full/read', (time() - $time));       
        $StatHat->count('count-biochemistry/full/read', 1);       
        return $data;
    } else {
        send_error("Not Found", 404);
    }
};

put '/biochemistry/:uuid/full' => sub {
    my $uuid = params->{uuid};
    my $data = params;
    try {
        my $bio = ModelSEED::MS::Biochemistry->new($data);
        $bio->om($om);
        $bio->save();
    } catch {
        send_error("Server Error", 500);
    };
    return { ok => 200 };
};


1;
