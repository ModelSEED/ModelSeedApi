#!/usr/bin/perl -w
use strict;
package ModelSEED::ModelSEEDServers::ModelDBServer;

    use strict;
    use ModelSEED::FIGMODEL;
    use SeedUtils;
    use ServerThing;
    use Data::Dumper;

# Types that may not be queried from the server
# interface for security reasons.
my $RESTRICTED_TYPES = {
    user => 1,
};

sub new {
    my ($class) = @_;
    my $self;
	$self->{_figmodel} = ModelSEED::FIGMODEL->new();
	bless $self, $class;
    return $self;
}

sub figmodel {
    my ($self) = @_;
	return $self->{_figmodel};
}

sub methods {
    return [ 'get_object', 'get_objects', 'create_object', 'set_attribute'];
}

sub get_object {
    my ($self, $args) = @_;
    $self->authenticate($args);
    my $query = $args->{query};
    my $type = $args->{type};
    my $object = $self->figmodel()->database()->get_object($type, $query);
    if(defined($object)) {
        return $self->success($self->_objToData($object));
    } else {
        return $self->failure('Object not found');
    }
}

sub get_objects {
    my ($self, $args) = @_;
    $self->authenticate($args);
    my $query = $args->{query};
    my $type = $args->{type};
    return [] if(defined($RESTRICTED_TYPES->{$type}));
    unless(defined($query) && defined($type)) {
        return $self->failure('You must include "query and "type" in your arguments');
    }
    my $objects = $self->figmodel()->database()->get_objects($type, $query);
    if(!defined($objects)) {
        return $self->failure('Error in "type" argument to function');
    } else {
        my @data = map { $_ = $self->_objToData($_) } @$objects;
        return $self->success(\@data);
    }
}

sub create_object {
    my ($self, $args) = @_;
    $self->authenticate($args);
    my $object = $args->{object};
    my $type = $args->{type};
    unless(defined($object) && defined($type)) {
        return $self->failure("You must include 'type' and 'object' in your arguments");
    }
    my $obj = $self->database()->create_object($type, $object);
    if(defined($obj)) {
        return $self->success($self->_objToData($obj));
    } else {
        return $self->failure('Could not create object!');
    }
}

sub set_attribute {
    my ($self, $args) = @_;
    return $self->error("This function has been disabled for security reasons");
    $self->authenticate($args);
    my $object = $args->{object};
    my $key = $args->{key};
    my $value = $args->{value};
    my $type = $args->{type};
    unless(defined($object) && defined($type)) {
        return $self->failure("You must include 'type 'and 'object' in your arguments");
    }
    unless(defined($value) && defined($key)) {
        return $self->failure("You must include 'key 'and 'value' in your arguments");
    }
    unless(ref($object) eq 'HASH' && defined($object->{_id})) {
        return $self->failure("Invalid object passed!");
    }
    my $obj = $self->figmodel()->database()->get_object($type, {_id => $object->{_id}} );
    unless(defined($obj)) {
        return $self->failure("Cound not find object!");
    }
    my $attrs = $obj->attributes();
    unless(defined($attrs->{$key})) {
        return $self->failure("Object has no attribute $key!");
    }
    my $ret = $obj->$key($value);
    if($ret ne $value) {
        return $self->failure("Failed to update. Do you have permissions on the object?"); 
    }
    return $self->success($self->_objToData($obj));
}

sub _objToData {
    my ($self, $obj) = @_;
    my $attrs = $obj->attributes();
    my $data = { '_id' => $obj->_id() };
    foreach my $key (keys %$attrs) {
       $data->{$key} = $obj->$key();
    }
    return $data;
} 
    

sub success {
    my ($self, $response, $msg) = @_;
    my $retObject = { 'success' => 'true', 'failure' => 'false',
        'msg' => $msg, 'response' => $response};
    return $retObject;
}

sub failure {
    my ($self, $message) = @_;
    my $retObject = { 'success' => 'false', 'failure' => 'true',
        'msg' => $message };
    return $retObject;
}
       
sub authenticate {
    my ($self, $args) = @_;
    if (defined($args->{'password'}) && defined($args->{'username'})) {
        $self->figmodel()->authenticate({ 'username' => $args->{'username'},
                                          'password' => $args->{'password'},
                                       });
    } elsif(defined($self->{cgi})) {
        $self->figmodel()->authenticate({'cgi' => $self->{cgi} });
    }
}

1;
