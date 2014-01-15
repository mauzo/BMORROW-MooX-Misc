package MooX::NoGlobalDestruction;

use Moo::Role;

sub DESTROY {}

before DESTROY => sub {
    ${^GLOBAL_PHASE} eq "DESTRUCT"
        and warn "$_[0] destroyed in global destruction\n";
};

1;
