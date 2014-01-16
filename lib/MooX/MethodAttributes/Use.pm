package MooX::MethodAttributes::Use;

use warnings;
use strict;

use Moo::Role;
use Sub::Identify ();

my $Me = "MooX::MethodAttributes";

sub MODIFY_CODE_ATTRIBUTES {
    my ($class, $ref, @attrs) = @_;
    my $method  = Sub::Identify::sub_name($ref);
    my $hints   = (caller 1)[10];

    my @fail;
    for (@attrs) {
        my ($att, $arg) = /^(\w+)(?:\(([^)]*)\))?$/ or next;

        if (my $map = $$hints{"$Me/map/$att"}) {
            $att = $map;
        }
        elsif ($$hints{"$Me/strict"}) {
            push @fail, $att;
            next;
        }

        $Me->register_method_attribute($class, $method, $att, $arg);
    }

    return @fail;
}

1;
