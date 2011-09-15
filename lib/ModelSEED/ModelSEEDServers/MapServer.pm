#!/usr/bin/perl -w
use strict;
use ModelSEED::FIGMODEL;
use SeedUtils;
use ServerThing;

package ModelSEED::ModelSEEDServers::MapServer;
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

sub _map_meta_table {
    my ($self) = @_;
    if (defined($self->{_map_meta_table})) {

sub methods {
    return [ 'get', 'put' ];
}

sub put {
    my ($self, $args) = @_;
    $self->authenticate($args); 
    my $id = $args->{id};
    if (not defined($id)) {
        # add details to table
        # generate id
        # save file
        return $self->success($id, "");
    } else {
        my $data = $args->{xgmml};
        # save data
        return $self->success($id, "");
    }
}

sub get {
    my ($self, $args) = @_;
    if (not defined($id)) {
        return $self->failure("Must supply id parameter to args");
    }
    # get the map data
    my $data = {};
    return $self->success($data, ""); 
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
    my ($username, $password) = undef;
    if (defined($password = $args->{'password'}) &&  
        defined($username = $args->{'username'})) {
        $self->figmodel()->authenticate({'username' => $username,
                                 'password' => $password,
                                });
    } elsif(defined($self->{cgi})) {
        $self->figmodel()->authenticate({'cgi' => $self->{cgi} });
    }
}

1;
