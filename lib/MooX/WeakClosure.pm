package MooX::WeakClosure;

use Moo::Role;
use Scalar::Util    ();

sub weak_closure {
    my ($self, $sub) = @_;
    Scalar::Util::weaken($self);
    sub { $sub->($self, @_) };
}

sub weak_method {
    my ($self, $method, $default) = @_;
    Scalar::Util::weaken($self);
    sub { $self ? $self->$method(@_) : $default };
}

1;
