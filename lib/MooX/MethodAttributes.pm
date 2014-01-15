package MooX::MethodAttributes;

use warnings;
use strict;

use Role::Tiny  ();

my %Attrs;

sub import {
    my ($class, %map) = @_;

    Role::Tiny->apply_roles_to_package(scalar caller,
        "MooX::MethodAttributes::Role");
    for (keys %map) {
        $^H{"MooX::MethodAttributes/remap/$_"} = $map{$_};
    }
}

sub register_attribute {
    my ($self, $class, $method, $att, $arg) = @_;
    push @{$Attrs{$class}{$method}}, [$att, $arg];
}

sub all_method_attrs {
    my ($self, $class) = @_;
    return $Attrs{$class};
}

sub attrs_for_method {
    my ($self, $class, $method) = @_;
    return $Attrs{$class}{$method};
}

sub methods_with_attr {
    my ($self, $class, $attr, $nsp) = @_;

    my $match = "\Q$attr";
    defined $nsp and $match .= "|\Q$nsp/$attr";

    my $all = $Attrs{$class};
    my %rv;
    for my $method (keys %$all) {
        my @attrs = grep $$_[0] =~ /^$match$/, @{$$all{$method}};
        @attrs and push @{$rv{$method}}, map $$_[1], @attrs;
    }
    return \%rv;
}

1;
