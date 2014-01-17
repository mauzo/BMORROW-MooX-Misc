package MooX::MethodAttributes;

use 5.010;
use warnings;
use strict;

use Carp;
use Hash::Util::FieldHash   qw/fieldhash/;
use Module::Runtime         qw/require_module $module_name_rx/;
use Scalar::Util            qw/reftype/;
use Role::Tiny ();

my $Me = "MooX::MethodAttributes";

fieldhash my %MAttrs;
my %CAttrs;

sub import {
    my ($self, %args) = @_;
    my $class = caller;

    Role::Tiny->apply_roles_to_package($class, "$Me\::Use");

    $args{use} || $args{provide} and $args{strict} //= 1;
    $self->export_strict($args{strict});
    
    if (my $reg = $args{provide}) {
        $self->register_class_attrs($class, @$reg);
        push @{$args{use}}, $class;
    }

    $self->export_mapped_attrs(%args);
}

sub _scope {
    my ($scope, $off) = @_;
    defined $scope ?
        ref $scope ? $scope
        : (caller $scope + $off)[10]
    : \%^H;
}

sub export_strict {
    my ($self, $strict) = @_;
    defined $strict and $^H{"$Me/strict"} = $strict;
}

sub scope_is_strict {
    my ($self, $scope) = @_;
    my $hints = _scope $scope;
    $$hints{"$Me/strict"};
}

sub register_class_attrs {
    my ($self, $class, @attrs) = @_;
    @{$CAttrs{$class}}{@attrs} = ();
}

sub attrs_for_class {
    my ($self, $class) = @_;
    keys %{$CAttrs{$class}};
}

sub class_has_attr {
    my ($self, $class, $att) = @_;
    exists $CAttrs{$class}{$att};
}

sub require_attrs_for_class {
    my ($self, $class) = @_;

    my @atts = $self->attrs_for_class($class);

    unless (@atts) {
        require_module $class;
        @atts = $self->attrs_for_class($class)
            or croak "$class doesn't define any method attributes";
    }

    return @atts;
}

sub export_mapped_attrs {
    my ($self, %args) = @_;

    my $map     = $args{map} // {};
    my @long    = values %$map;

    if ($self->scope_is_strict) {
        for (@long) {
            my ($class, $att) = m!^($module_name_rx)/(\w+)!
                or croak "Invalid long attribute name '$_'";
            $self->class_has_attr($class, $att)
                or croak "$class doesn't provide attribute '$att'";
        }
    }

    my %apply = %$map;
    my %long; @long{@long} = 1 x @long;

    for my $use (@{$args{use}}) {
        for my $short ($self->require_attrs_for_class($use)) {
            my $long = "$use/$short";
            $$map{$short} || $long{$long} and next;
            $apply{$short} and croak "Method attribute " .
                "'$long' conflicts with '$apply{$short}'";
            $apply{$short} = $long;
        }
    }

    $^H{"$Me/map/$_"} = $apply{$_} for keys %apply;
}

sub map_attrs_for_scope {
    my ($self, $scope, @attrs) = @_;
    my $hints   = _scope $scope;
    my $lax     = !$self->scope_is_strict($hints);
    map {
        my $att = ref $_ ? $$_[0] : $_;
        my $key = "$Me/map/$att";
        my $map =
            exists $$hints{$key}    ? $$hints{$key}
            : $lax                  ? $att
            : croak "Invalid CODE attribute: $att";
        ref $_ ? [$map, $$_[1]] : $map;
    } @attrs;
}

sub register_method_attrs {
    my ($self, $method, @attrs) = @_;
    ref $method or croak "Not a reference";
    push @{$MAttrs{$method}},
        map +(ref $_ ? $_ : [$_]),
        @attrs;
}

sub _unwrap_modifiers {
    my ($class, $stash, $method) = @_;

    # XXX This is evil, but I don't see any way around it unless CMM is
    # willing to provide an API for this.
    my $wrapped =
        $Class::Method::Modifiers::MODIFIER_CACHE
        {$class}{$method}{orig};
    $wrapped and return $wrapped;

    my $glob    = \$$stash{$method};
    # Stubs (sub foo;) create (-1) entries in the stash, but not if
    # they have custom attributes. In that case (because a coderef
    # has to be passed to M_C_ATTRS) we always get a full glob.
    reftype $glob eq "GLOB" or return;

    return *$glob{CODE};
}

sub local_method_attrs {
    my ($self, $class) = @_;
    my $stash = do { no strict "refs"; \%{"$class\::"} };
    return {
        map @$_,
        grep $$_[1],
        map [$$_[0], $MAttrs{$$_[1]}],
        grep $$_[1],
        map [$_, _unwrap_modifiers $class, $stash, $_],
        keys %$stash
    };
}

sub attrs_for_method {
    my $method = @_ > 2 ? $_[1]->can($_[2]) : $_[1];
    return $MAttrs{$method};
}

sub methods_with_attr {
    my ($self, $class, $attr, $nsp) = @_;
    $nsp //= caller;

    my $match = qr!^(?:\Q$attr\E|\Q$nsp/$attr\E)$!;

    my $all = $self->local_method_attrs($class);
    my %rv;
    for my $method (keys %$all) {
        my @attrs = grep $$_[0] =~ $match, @{$$all{$method}};
        @attrs and push @{$rv{$method}}, map $$_[1], @attrs;
    }
    return \%rv;
}

1;
