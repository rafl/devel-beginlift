use strict;
use warnings;
use Test::More;

BEGIN {
    plan skip_all => "B::Generate required" unless eval { require B::Generate };
    plan 'no_plan';
}

sub foo { 
    B::SVOP->new("const", 0, 42);
}

use Devel::BeginLift qw(foo);

sub bar { 7 + foo() }

is( bar(), 49, "optree injected" );

