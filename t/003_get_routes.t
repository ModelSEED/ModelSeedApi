use Test::More;
use strict;
use warnings;
use ModelSeedApi;
use Dancer::Test;
my $testCount = 0;

{
    # Test basic biochemistry GET routes
    route_exists [GET => '/0/biochemistry'], "biochemistry collection exists";
    route_exists [GET => 
        '/0/biochemistry/C1877FB6-63DA-11E1-9E9E-D2534BC191FA'],
        "basic biochemistry object route exists (specific uuid)";
    route_exists [GET => '/0/biochemistry/master/default'],
        "basic biochemistry object route exists (alias)";
    route_exists [GET =>
        '/0/biochemistry/C1877FB6-63DA-11E1-9E9E-D2534BC191FA/full'],
        "full biochemistry object route exists (specific uuid)";
    route_exists [GET => '/0/biochemistry/master/default/full'],
        "full biochemistry object route exists (alias)";
    $testCount += 5;
}

done_testing($testCount);


