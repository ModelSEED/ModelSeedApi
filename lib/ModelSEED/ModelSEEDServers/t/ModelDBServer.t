use strict;
use warnings;

use Test::More qw(no_plan);
use ModelSEED::ModelSEEDServers::ModelDBServer;
use ModelSEED::FIGMODEL;
my $TEST_COUNT = 0;

my $fm = ModelSEED::FIGMODEL->new();
my $fmdb = $fm->database();

my $svr = ModelSEED::ModelSEEDServers::ModelDBServer->new();
ok ( $svr->{_figmodel} eq $svr->figmodel(), "figmodel getter"); 

# TESTING _objToData function
{
    # 5 tests
    my $cpd_objt = $fmdb->get_object('compound', {'id' => 'cpd00001'});
    my $cpd_data = $svr->_objToData($cpd_objt);
    ok $cpd_objt->id() eq $cpd_data->{id}, "_objToData attribute id exists";
    ok $cpd_objt->_id() eq $cpd_data->{_id}, "_objToData attribute _id exists";
    ok $cpd_objt->name() eq $cpd_data->{name}, "_objToData attribute name exists";
    ok $cpd_objt->formula() eq $cpd_data->{formula}, "_objToData attribute formula exists";
    ok $cpd_objt->mass() eq $cpd_data->{mass}, "_objToData attribute mass exists";
}

# TESTING get_object on valid request
{
    # 10 tests
    my $type = 'compound';
    my $query = { 'id' => 'cpd00001' };
    my $cpd_obj = $fmdb->get_object($type, $query);
    my $cpd_req = $svr->get_object({'type' => $type, 'query' => $query });
    ok exists $cpd_req->{success}, "testing response object";
    ok 'true'  eq $cpd_req->{success}, "testing response object";
    ok 'false' eq $cpd_req->{failure}, "testing response object";
    ok exists $cpd_req->{response}, "testing response object";

    my $cpd_data = $cpd_req->{response};
    # Note that we have to +1 to attributes() because it does not report _id)
    ok scalar(keys %$cpd_data) eq (1 + scalar(keys %{$cpd_obj->attributes()})), "same number of attributes";
    ok $cpd_data->{'name'} eq $cpd_obj->name(), "testing name the same";
    ok $cpd_data->{'id'} eq $cpd_obj->id(), "testing id the same";
    ok $cpd_data->{'_id'} eq $cpd_obj->_id(), "testing _id the same";
    ok $cpd_data->{'formula'} eq $cpd_obj->formula(), "testing formula the same";
    ok $cpd_data->{'mass'} eq $cpd_obj->mass(), "testing mass the same";

}

# testing get_object on invalid request, bad type
{ 
    # 4 tests
    my $cpd_req = $svr->get_object({'type' => 'compounds', 'query' => {'id' => 'cpd00001'}});
    ok exists $cpd_req->{success}, "testing response object on invalid request foobaz";
    ok exists $cpd_req->{failure}, "testing response object on invalid request foobaz";
    ok 'false'  eq $cpd_req->{success}, "testing response object on invalid request foobaz";
    ok 'true' eq $cpd_req->{failure}, "testing response object on invalid request foobaz";
}
    
# TESTING get_object on invalid request, bad query
{
    # 4 tests
    my $cpd_req = $svr->get_object({'type' => 'compound', 'query' => { 'id' => 'foobaz'}});
    ok exists $cpd_req->{success}, "testing response object on invalid request foobaz";
    ok exists $cpd_req->{failure}, "testing response object on invalid request foobaz";
    ok 'false'  eq $cpd_req->{success}, "testing response object on invalid request foobaz";
    ok 'true' eq $cpd_req->{failure}, "testing response object on invalid request foobaz";
}

# TESTING set_attribute
#{
#    my $cpdSave = $svr->get_object({'type' => 'compound', 'query' => {'id' => 'cpd00001'}});
#    my $cpdEdit = $svr->get_object({'type' => 'compound', 'query' => {'id' => 'cpd00001'}});
#    $cpdEdit = $svr->set_attribute({object => $cpdEdit->{response}, key => 'name', value => 'foobar', type => 'compound'});
#    ok 'foobar' eq $cpdEdit->{response}->{name}, "function set_attribute not working correctly!";
#    $cpdEdit = $svr->set_attribute({object => $cpdSave->{response}, key => 'name', value => $cpdSave->{response}->{name}, type => 'compound'});
#    ok $cpdSave->{response}->{name} eq $cpdEdit->{response}->{name}, "function set_attribute not working correctly!, change cpd00001 name back to H2O!";
#}
     

# Need to test set_attribute, create_object and get_objects

