#!/usr/bin/perl

use strict;
use warnings;

use Test::More;

use_ok "BMORROW::MooX::Misc";

Test::More->builder->is_passing
    or BAIL_OUT "Module will not load!";

done_testing;
