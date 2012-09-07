use Test::More;
use Test::Mojo;
use FindBin;
require "$FindBin::Bin/../app.pl";
my $t = Test::Mojo->new('ModelSEED::API');
my $c = 0;

$t->get_ok("/")->status_is(200);
$t->get_ok("/0/")->status_is(200);

$c += 4;
done_testing($c);
