#!/usr/bin/perl -w
use strict;
package ModelSEED::ModelSEEDServers::ModelControls;

    use strict;
    use ModelSEED::FIGMODEL;
	use Tracer;
    use SeedUtils;
    use ServerThing;
    use DBMaster;
    use Data::Dumper;

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
    return [ 'autoComplete', 'add_reaction', 'remove_reaction'];
}

sub autocomplete {
    my ($self, $args) = @_;
    return $self->gapfill($args);
}

sub gapfill {
    my ($self, $args) = @_;
    $self->authenticate($args);
    my $id = $args->{model};
    my $media = $args->{media}; #TODO check media
    my $mediaObj = $self->figmodel()->database()->get_object('media', { 'id' => $media });
    unless(defined($mediaObj)) {
        return $self->error("Could not find that media.");
    }
    my $deletePrevious = $args->{deletePrevious};
    $deletePrevious = 1 unless(defined($deletePrevious));
    my $doNotClear;
    ($deletePrevious == 1) ? $doNotClear = 0 : $doNotClear = 1; 
    my $model = $self->figmodel()->get_model($id);
    unless(defined($model)) { 
        return $self->error("Could not find model " . $id);
    }
    my $createLPFileOnly = 0;
    my $pidHash = $self->figmodel()->add_job_to_queue({ 'queue' => 'cplex',
            'priority' => 5, 'exclusivekey' => $id, 
            'command' => "gapfillmodel?$id?$doNotClear?$createLPFileOnly?$media",
        });
    my $type;
    ($doNotClear) ? $type = 'gapfilling' : $type = 'reconstruction';
    if(defined($pidHash->{'jobid'})) {
        return { 'success' => 'true', 'error' => 'false',
            'msg' => "Added $type to queue"}; #<a href='seedviewer.cgi?page=QueueManager&model=".$id."'>queue</a>"};
    } else {
        return $self->error("Could not queue $type.");
    }
}

sub add_reaction {
    my ($self, $args) = @_;
    $self->authenticate($args);
    my $modelId = $args->{model};
    my $dir = $args->{directionality};
    if($dir eq 'forward') {
        $dir = "=>";
    } elsif($dir eq 'reverse') {
        $dir = "<=";
    } else {
        $dir = "<=>";
    }
    
    my $model = $self->figmodel()->get_model($modelId);
    unless(defined($model)) {
        return $self->error("Couldn't find model! Have you logged out?");
    }
    my $status = $model->add_reaction({'id' => $args->{reaction}, 'note' => $args->{note},
                                       'compartment' => $args->{compartment}, 'directionality' => $dir,
                                        'pegs' => $args->{pegs}});
    if($status eq $self->figmodel()->fail()) {
        return $self->error("Could not add reaction!");
    } else {
        return { 'success' => 'true', 'error' => 'false', 'msg' => "Added reaction ".
            $args->{reaction}." to the model!" };
    }
}

sub remove_reaction {
    my ($self, $args) = @_;
    $self->authenticate($args);
    my $modelId = $args->{model};
    my $reaction = $args->{reaction};
    my $model = $self->figmodel()->get_model($modelId);
    unless(defined($model)) {
        return $self->error("Couldn't find model! Have you logged out?");
    }
    my $status = $model->remove_reaction($args->{'reaction'}, $args->{'compartment'});
    if($status eq $self->figmodel()->fail()) {
        return $self->error("Could not remove reaction!");
    } else {
        return {'success' => 'true', 'error' => 'false', 'msg' => "Removed reaction $reaction from the model."};
    }
}
    
    

sub error {
    my ($self, $message) = @_;
    my $retObject = { 'success' => 'false', 'error' => 'true',
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
