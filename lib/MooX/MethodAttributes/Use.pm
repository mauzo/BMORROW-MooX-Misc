package MooX::MethodAttributes::Use;

use warnings;
use strict;

use Moo::Role;

sub MODIFY_CODE_ATTRIBUTES {
    my ($class, $method, @attrs) = @_;
    my $hints = (caller 1)[10];
    MooX::MethodAttributes->parse_method_attrs_for(
        $class, $hints, $method, @attrs);
    return;
}

1;
