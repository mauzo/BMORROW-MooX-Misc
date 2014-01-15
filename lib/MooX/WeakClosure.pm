package MooX::WeakClosure;

use Moo::Role;
use Scalar::Util    ();

sub weak_closure {
    my ($self, $sub) = @_;
    Scalar::Util::weaken($self);
    sub { $sub->($self, @_) };
}

sub weak_method {
    my ($self, $method, $default, $args) = @_;
    Scalar::Util::weaken($self);
    $default ||= [];
    sub { 
        $self ? $self->$method($args ? @$args : @_) : 
            wantarray ? @$default : $default[-1]
    };
}

1;
