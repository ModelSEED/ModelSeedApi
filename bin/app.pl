#!/usr/bin/env perl
use Dancer;
use lib $ENV{MODEL_SEED_CORE}."/config";
use local::lib '../local/lib/perl5';
use ModelSEEDbootstrap;
use ModelSeedApi;
dance;
