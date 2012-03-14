package StatHat;
use HTTP::Request::Common qw(POST);
use LWP::UserAgent;
use Time::HiRes qw(time);
use Exporter;
@ISA = qw(Exporter);
@EXPORT_OK = qw(count value);

sub stathat_post {
        my ($path, $params) = @_;
        my $t = time();
        my $ua = LWP::UserAgent->new;
        my $req = POST 'http://api.stathat.com/' . $path, $params;
        my $res = $ua->request($req)->as_string;
        $t = time() - $t;
        {
            # Return the time it took to make this post.
            my $testParams = [
                email => $params->[1],
                stat  => 'stathat/latency',
                value => $t,
            ];
            my $tReq = POST 'http://api.stathat.com/ez', $testParams;
            $ua->request($tReq)->as_string;
        }
        return $res;
};

sub Scount {
        my ($stat_key, $user_key, $count) = @_;
        return stathat_post('c', [ key => $stat_key, ukey => $user_key, count => $count ]);
};

sub Svalue {
        my ($stat_key, $user_key, $value) = @_;
        return stathat_post('v', [ key => $stat_key, ukey => $user_key, value => $value ]);
};

sub count {
        my ($email, $stat_name, $count) = @_;
        return stathat_post('ez', [ email => $email, stat => $stat_name, count => $count ]);
};

sub value {
        my ($email, $stat_name, $value) = @_;
        return stathat_post('ez', [ email => $email, stat => $stat_name, value => $value ]);
};

1;

