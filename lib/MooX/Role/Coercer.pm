package MooX::Role::Coercer;

use Moo::Role;

use MooX::CaptainHook   qw/on_application/;
use MooX::AccessorMaker qw/apply_accessor_maker_roles/;

use Carp;
use Data::Dump      qw/pp/;
use Module::Runtime qw/use_package_optimistically/;
use Scalar::Util    qw/blessed/;

use namespace::clean;

BEGIN { $SIG{__DIE__} = \&Carp::confess }

my $Me = __PACKAGE__;

on_application {
    my ($to, $from) = @{$_[0]};
    apply_accessor_maker_roles $to, "$Me\::Accessor";
};

my $check_is = sub {
    my ($pkg, $for) = @_;

    Carp::cluck "CHECK_IS [$pkg] [$for]";
    use_package_optimistically $pkg;
    my $is = Role::Tiny->is_role($pkg) ? "DOES" : "isa";
    my $qto = qq{"\Q$pkg\E"};

    qq{ ( ref \$_[0] && Scalar::Util::blessed(\$_[0])
            && \$_[0]->$is($qto) ) 
    };
};

package MooX::Role::Coercer::Accessor;

use Sub::Quote  qw/quote_sub/;

use Moo::Role;

before generate_method => sub {
    my ($self, $into, $name, $spec) = @_;

    if ($$spec{coercer}) {
        $name =~ s/^\+//;
        $$spec{coercer} eq "1" 
            and $$spec{coercer} = "_coerce_$name";
        $$spec{coerce} = quote_sub qq{ die 
            "Panic: coerce called for \Q$into\E.\Q$name\E without setup" };
    }

    if ((my $to = $$spec{coerce_to}) && !$$spec{coercer}) {
        my $check = $check_is->($to, qq{"\Q$into\E"});
        $$spec{coerce} = quote_sub qq{ 
            # MooX::Role::Coercer
            do {
                warn sprintf "COERCE [%s] TO [%s] FOR [%s]",
                    Data::Dump::pp(\$_[0]), "\Q$to\E", "\Q$into\E";
                $check ? \$_[0] : "\Q$to\E"->new(\$_[0]);
            }
        };
        warn "SET COERCE FOR [$into][$name] TO [$$spec{coerce}]";
    }
};

# _generate_coerce doesn't get a $me argument, so we have to wrap all
# its callers.

my $do_coercer = sub {
    my ($orig, $me, $spec)  = @_;

    # can't quote this...
    my $cer     = $$spec{coercer} or return $orig->();

    my $check   = "0";
    my $qto     = q{""};
    if (my $to = $$spec{coerce_to}) {
        $check  = $check_is->($to, $me);
        $qto    = qq{"\Q$to\E"};
    }

    local $$spec{coerce} = quote_sub qq{
        # MooX::Role::Coercer
        do {
            warn sprintf "COERCE [%s] TO [%s] VIA [%s] FOR [%s]",
                Data::Dump::pp(\$_[0]), $qto, "$cer", $me;
            ($check ? \$_[0] : $me\->$cer(\$_[0], $qto));
        }
    };

    $orig->();
};

around _generate_use_default    => sub {
    my ($orig, $self, @args)    = @_;
    my ($me, undef, $spec)      = @args;
    $do_coercer->(
        sub { $self->$orig(@args) },
        $me, $spec,
    );
};
around _generate_populate_set   => sub {
    my ($orig, $self, @args)    = @_;
    my ($me, undef, $spec)      = @args;
    $do_coercer->(
        sub { $self->$orig(@args) },
        $me, $spec,
    );
};
around _generate_set => sub {
    my ($orig, $self, @args)    = @_;
    my (undef, $spec)           = @args;
    $do_coercer->(
        sub { $self->$orig(@args) },
        q{$self}, $spec,
    );
};

1;
