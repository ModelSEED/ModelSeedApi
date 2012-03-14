use Test::More tests => 2;
use strict;
use warnings;

# the order is important
use ModelSeedApi;
use Dancer::Test;

route_exists [GET => '/'], 'a route handler is defined for /';
response_status_is ['GET' => '/'], 404, 'response status is 404 for /';
