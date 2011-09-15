#
# ServerThing.pm
# A lightweight implementation of
# ServerThing to work within dancer.
#
package ServerThing;
use Dancer;
use Dancer ':syntax';

sub new {
    my ($class, $module) = @_;
    my $path = $module;
    $path =~ s/::/\//g;
    eval {
        require "$path.pm";
    };
    my $instance = eval("$module"."->new()");
    my $methods  = $instance->methods();
    my $self = {_methods => $methods,
                _instance => $instance
    };
    bless $self, $class;
    return $self;
}
    
sub call {
    my ($self, $params) = @_;
    my $function = $params->{function};
    my $args     = $params->{args};
    my $encoding = $params->{encoding} || "yaml"; 
    my $callback = $params->{callback};
    if($encoding eq "json") {
        content_type 'application/json';
        $args = from_json($args || "[]");
    } elsif($encoding eq "yaml") {
        content_type "text/x-yaml";
        $args = from_yaml($args);
    }
    $args = [] unless(defined($args));
    my $data = [];
    if(defined($function) && ($function ~~ @{$self->{_methods}} ||
       $function eq "methods")) {
       $data = $self->{_instance}->$function(@$args); 
    } else {
        send_error("Invalid function name.", 400);
        return;
    }
    if($encoding eq "json") {
        $data = to_json($data);
    } elsif($encoding eq "yaml") {
        $data = to_yaml($data);
    }
    if(defined($callback)) {
        $data = $callback . "(" . $data . ");";
    }
    return $data;
}

1;
