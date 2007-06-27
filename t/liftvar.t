use strict;
use warnings;
use Test::More 'no_plan';

sub foo { $_[0] = $_[1]; (); }

sub bar { is($_[0], 'yay', 'Var set ok'); (); }

use Devel::BeginLift qw(foo bar);

foo(my $meep, 'yay');

bar($meep);
