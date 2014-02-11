package MooX::Role::Copiable;

use Moo::Role;

use MooX::CaptainHook   qw/on_application/;
use MooX::AccessorMaker qw/apply_accessor_maker_roles/;

use Carp;
use Data::Dump      qw/pp/;
use Scalar::Util    qw/blessed/;

use namespace::clean;

my $Me = __PACKAGE__;
my %COPIABLE_ATTS;

on_application {
    my ($to, $from) = @{$_[0]};
    apply_accessor_maker_roles $to, "$Me\::Accessor";
};

# $for is the class we are copying *to* ($self in copy_from).
sub _find_copiable_atts_for {
    my ($self, $for, @roles) = @_;

    @roles or @roles = blessed $self // $self;

    map @$_,
    map $COPIABLE_ATTS{$_} || (),
    grep $for->DOES($_),
    map keys %{$Role::Tiny::APPLIED_TO{$_}},
    grep $self->DOES($_),
    @roles;
}

my $filter = sub {
    my ($item, $list) = @_;
    my @list = $list ? ref $list ? @$list : $list : ()
        or return;
    my $rv = scalar grep $_ eq $item, @list;
    $rv;
};

sub copy_from {
    my ($self, $from, @args) = @_;

    $from->DOES($Me) or croak "$from is not $Me";

    my $opts = (@args == 1 && ref $args[0])
        ? $args[0] : { roles => \@args };

    my @atts =
        grep !($filter->($$_[0], $$opts{exclude})),
        grep $filter->($$_[0], $$opts{only}) // 1,
        $from->_find_copiable_atts_for($self, @{$$opts{roles}});

    for (@atts) {
        my ($n, $r, $w) = @$_;
        $self->$w($from->$r);
    }
}

package MooX::Role::Copiable::Accessor;

use Moo::Role;

after generate_method => sub {
    my ($self, $into, $name, $spec) = @_;

    $$spec{copiable} or return;

    # This is something of a hack. We have to make the attribute
    # unrequired, since we may be filling that requirement from a copy.
    # In principle we can't affect the behaviour of the base object,
    # since we're in an after modifier; in practice, changes to the spec
    # hashref here will be picked up by the constructor code later.
    my $reqd = delete $$spec{required};
    $name =~ s/^\+//;

    my $r = $$spec{reader} // $$spec{accessor};
    my $w = $$spec{writer} // $$spec{accessor};

    push @{$COPIABLE_ATTS{$into}}, [$name, $r, $w];
    $$spec{_copiable_spec} = [$r, $into, $reqd];
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

    my $check_reqd  = $reqd ? qq{
        $test or die "Missing required argument: \Q$init_arg\E";
    } : "";
        
    qq{
        { # BEGIN MooX::Role::Copiable [$name]
            my \$from = \$args->{copy_from};
            if (!$test
                && \$from
                && \$from->DOES("\Q$role\E")
            ) {
                \$args->{"\Q$init_arg\E"} = \$from->$r;
            }
        }
        $check_reqd;
        # END MooX::Role::Copiable [$name]
        $default;
    };
};

1;
