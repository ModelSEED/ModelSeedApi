package ModelSEED::API::Aliases;
use Mojo::Base 'Mojolicious::Controller';

sub list {
    my $self = shift;
    my $query = { type => $self->param("type") };
    $query->{owner} = $self->param("owner") if defined $self->param("owner");
    my $aliases = $self->Store->get_aliases($query);
    my $base = $self->req->url->base;
    foreach my $als (@$aliases) {
        my ($t, $o, $a) = ($als->{type}, $als->{owner}, $als->{alias});
        $als = "$base/$t/$o/$a";
    }
    return $self->render(json => $aliases);
}

sub get_config {

}

sub put_config {

}

1;
