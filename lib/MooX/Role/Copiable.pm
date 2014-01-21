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

sub _copy_init_args_for {
    my ($self, $for, @roles) = @_;

    map { my $r = $$_[1]; ($$_[3] => $self->$r) }
    $self->_find_copiable_atts_for($for, @roles);
}

sub copy_from {
    my ($self, $from, @args) = @_;

    $from->DOES($Me) or croak "$from is not $Me";

    my $opts = (@args == 1 && ref $args[0])
        ? $args[0] : { only => \@args };

    my %exclude; @exclude{@{$$opts{exclude} || []}} = ();
    my @atts =
        grep !exists $exclude{$$_[0]},
        $from->_find_copiable_atts_for($self, @{$$opts{only}});

    warn "COPY FROM [$from] TO [$self]: " . pp [map $$_[0], @atts];

    for (@atts) {
        my ($n, $r, $w) = @$_;
        $self->$w($from->$r);
    }
}

# We have to supply the default BUILDARGS, since Moo::Object doesn't
# have one.
sub BUILDARGS {
    my ($self, @args) = @_;
    @args == 1 && ref $args[0] and return $args[0];
    return { @args };
}

around BUILDARGS => sub {
    my ($orig, $self, @args) = @_;

    my $args = $self->$orig(@args);
    #Carp::cluck "COPY BUILDARGS [$self]: " . pp $args;

    my $from = delete $$args{copy_from} 
        or return $args;
    $from->DOES($Me) or croak "$from is not $Me";

    my %copy = $from->_copy_init_args_for($self);
    carp "COPY BUILDARGS [$self] FROM [$from]: " . pp [keys %copy];

    +{
        %copy,
        %$args,
    };
};

package MooX::Role::Copiable::Accessor;

use Moo::Role;

after generate_method => sub {
    my ($self, $into, $name, $spec) = @_;

    $$spec{copiable} or return;

    push @{$COPIABLE_ATTS{$into}}, [
        $name,
        $$spec{reader} // $$spec{accessor},
        $$spec{writer} // $$spec{accessor},
        $$spec{init_arg} // $name,
    ];
};

1;
