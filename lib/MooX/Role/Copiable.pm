package MooX::Role::Copiable;

use Moo::Role;

use MooX::CaptainHook   qw/on_application/;
use MooX::AccessorMaker qw/apply_accessor_maker_roles/;

use Carp;
use Data::Dump      qw/pp/;
use Scalar::Util    qw/blessed/;

use namespace::clean;

require mro;

my $Me = __PACKAGE__;
my %COPIABLE_ATTS;

on_application {
    my ($to, $from) = @{$_[0]};
    apply_accessor_maker_roles $to, "$Me\::Accessor";
};

# $for is the class we are copying *to* ($self in copy_from).
sub _find_copiable_atts_for {
    my ($self, $for, @roles) = @_;

    # Although this is called @roles, in the normal case it will be our
    # own class name (which is a role at least to the extent of
    # answering to ->DOES).
    @roles or @roles = blessed $self // $self;

        # check the predicates
    grep { my $p = $$_[3]; $self->$p }
        # find the copiable atts for these roles
    map @$_,
    map $COPIABLE_ATTS{$_} || (),
        # include only the roles we have in common with $for
    grep $for->DOES($_),
        # find all roles applied to these classes
    map keys %{$Role::Tiny::APPLIED_TO{$_}},
        # also include the superclasses of any classes
    map @{mro::get_linear_isa $_},
        # ignore any passed-in roles we don't implement
    grep $self->DOES($_),
    @roles;
}

sub copy_from {
    my ($self, $from, @roles) = @_;

    blessed $from && $from->DOES($Me) 
        or croak "$from is not $Me";

    my @atts = $from->_find_copiable_atts_for($self, @roles);

    for (@atts) {
        my ($n, $r, $w, $p, $c, undef, $deep) = @$_;
        my $f = $from->$r;
        warn "COPY [$f] TO [$self][$n] ($p)";
        if (!$deep) {
            warn "SETTING VIA [$w]";
            $self->$w($f);
        }
        elsif (!$f) {
            warn "CLEARING VIA [$c]";
            $self->$c;
        }
        elsif ($self->$p) {
            warn "COPYING VIA [$r]";
            $self->$r->copy_from($f);
        }
        else {
            warn "BUILDING COPY VIA [$w]";
            $self->$w({copy_from => $f});
        }
    }
}

package MooX::Role::Copiable::Accessor;

use Moo::Role;
use Carp;
use namespace::clean;

after generate_method => sub {
    my ($self, $into, $name, $spec) = @_;

    $$spec{deep_copy}   and $$spec{copiable} = 1;
    $$spec{copiable}    or return;

    # This is something of a hack. We have to make the attribute
    # unrequired, since we may be filling that requirement from a copy.
    # In principle we can't affect the behaviour of the base object,
    # since we're in an after modifier; in practice, changes to the spec
    # hashref here will be picked up by the constructor code later.
    my $reqd = delete $$spec{required};

    my $role = $into;
    if ($name =~ s/^\+//) {
        my $n = ($role) = 
            grep {
                grep $$_[0] eq $name,
                @{$COPIABLE_ATTS{$_}}
            }
            map keys %{$Role::Tiny::APPLIED_TO{$_}},
            @{mro::get_linear_isa $into};
        warn "ADJUST [$name] FROM [$role] FOR [$into]";
        $n != 1 and croak 
            "Attribute '$name' on '$into' does not have a unique source";
    }

    my $r = $$spec{reader} // $$spec{accessor};
    my $w = $$spec{writer} // $$spec{accessor};
    my $p = $$spec{predicate} // sub { 
        my $rv = exists($_[0]{$name});
        carp "PREDICATE FOR [$_[0]][$name] [$rv]";
        return $rv;
    };
    my $c = $$spec{clearer} // sub {
        carp "CLEAR FOR [$_[0]][$name]";
        delete $_[0]{$name};
    };

    push @{$COPIABLE_ATTS{$into}}, [
        $name, $r, $w, $p, $c,
        $$spec{init_arg},
        $$spec{deep_copy},
    ];
    $$spec{_copiable_spec} = [$r, $role, $reqd];
};

# This is the method called to generate the code that copies values from
# the BUILDARGS hash into the new object. This is the last point at
# which we have access to copy_from, unless we make it a real attribute.
around _generate_populate_set => sub {
    my ($orig, $self, @args) = @_;
    my ($me, $name, $spec, undef, $test, $init_arg) = @args;

    my $default     = $self->$orig(@args);
    my $copiable    = $$spec{_copiable_spec} or return $default;
    my ($r, $role, $reqd) = @$copiable;

    my $predicate   = $$spec{predicate}
        ? qq{ \$from->$$spec{predicate} }
        : qq{ exists(\$from->{"\Q$name\E"}) };
    my $source      = $$spec{deep_copy}
        ? qq{ +{ copy_from => \$from->$r } }
        : qq{ \$from->$r };
    my $check_reqd  = $reqd ? qq{
        $test or die "Missing required argument: \Q$init_arg\E";
    } : "";
        
    qq{
        { # BEGIN MooX::Role::Copiable [$name]
            my \$from = \$args->{copy_from};
            if (!$test
                && \$from
                && \$from->DOES("\Q$role\E")
                && $predicate
            ) {
                \$args->{"\Q$init_arg\E"} = $source;
            }
        }
        $check_reqd;
        # END MooX::Role::Copiable [$name]
        $default;
    };
};

1;
