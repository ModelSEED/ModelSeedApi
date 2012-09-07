package ModelSEED::API::Object;
use Mojo::Base 'Mojolicious::Controller';

# GET
sub show {
    my $self = shift;
    Mojo::IOLoop->stream($self->tx->connection)->timeout(60);
    my $ref = $self->_getBaseObjectRef();
    return $self->render(json => { 'e' => 'Not Found' }, 404) unless defined $ref;
    my $url = $self->req->url->to_string;
    my $path = $url; 
    $path =~ s/.*${ref}\/*//;
    my $data = $self->Store->get_data($ref);
    if ( $path ne "" && defined $data) {
        return $self->render(json => { ref => $ref , path => $path, url => $url });
    } elsif(defined $data) {
        return $self->render(json => $data);
    } else {
        return $self->render(json => { 'M' => "Not Found" }, 404);
    }
}

# POST
sub create {
    my $self = shift;
    return $self->render(text => "Too large file", 500)
        if $self->req->is_limit_exceeded;
    my $type = $self->param("type");
    my $ref = $self->_getBaseObjectRef();
    my $data = $self->req->json;
    my $obj  = $self->Store->create($type, $data);
    my $rtv  = $self->Store->save_object($ref, $obj);
    if ($rtv) {
        $self->render(json => { M => "Created", S => 201}, status => 201);
    } else {
        $self->render(json => { M => "Forbidden"}, status => 403);
    }
}

# PUT - update or create new
sub update {
    my $self = shift;
    return $self->render(text => "Too large file", 500)
        if $self->req->is_limit_exceeded;
    my $type = $self->param("type");
    my $ref = $self->_getBaseObjectRef();
    my $data = $self->req->json;
    my $obj  = $self->Store->create($type, $data);
    my $rtv  = $self->Store->save_object($ref, $obj);
    if ($rtv) {
        $self->render(json => { M => "Created", S => 201}, status => 201);
    } else {
        $self->render(json => { M => "Forbidden"}, status => 403);
    }
}

sub _getBaseObjectRef {
    my $self = shift;
    my $type = $self->param("type");
    my $uuid = $self->param("uuid");
    my $owner = $self->param("owner");
    my $alias = $self->param("alias");
    return "$type/$uuid" if defined $uuid;
    return "$type/$owner/$alias" if defined $owner && defined $alias;
    return;
}

1;
