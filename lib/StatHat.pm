package StatHat;
use Moose;
use namespace::autoclean;
use HTTP::Async;
use HTTP::Request::Common qw(POST);
use Time::HiRes qw(time);

has key => (
    'is'    => 'ro',
    isa     => 'Maybe[Str]',
    lazy    => 1,
    builder => '_buildKey'
);
has calls => (
    is      => 'rw',
    isa     => 'Int',
    default => 0,
    traits  => ['Counter'],
    handles => {increment_calls => 'inc'}
);
has async => (
    is      => 'ro',
    isa     => 'HTTP::Async',
    builder => '_buildAsync',
    lazy    => 1,
);

sub _buildAsync { return HTTP::Async->new(); }
sub _buildKey {
    my ($self) = @_;
    if (defined($ENV{STATHAT_API_KEY})) {
        return $ENV{STATHAT_API_KEY};
    } else {
        return undef;
    }
}

sub _stathat_post {
    my ($self, $path, $params) = @_;
    my $t = time;
    my $req = POST 'http://api.stathat.com/' . $path, $params;
    $self->async->add($req);
    $t = time - $t;
    {
        # Return the time it took to make this post.
        my $testParams = [
            email => $params->[1],
            stat  => 'stathat/latency',
            value => $t,
        ];
        my $tReq = POST 'http://api.stathat.com/ez', $testParams;
        $self->async->add($tReq);
    }
    $self->increment_calls();
}

sub count {
    my ($self, $stat_name, $count) = @_;
    return unless (defined($self->key));
    $self->_stathat_post(
        'ez',
        [   email => $self->key,
            stat  => $stat_name,
            count => $count
        ]
    );
}

sub value {
    my ($self, $stat_name, $value) = @_;
    return unless (defined($self->key));
    $self->_stathat_post(
        'ez',
        [   email => $self->key,
            stat  => $stat_name,
            value => $value
        ]
    );
}

sub DEMOLISH {
    my ($self) = @_;

    # Wait for all asynchronous calls to exit
    while ($self->async->not_empty) { sleep 1; }
}

1;
__PACKAGE__->meta->make_immutable;
