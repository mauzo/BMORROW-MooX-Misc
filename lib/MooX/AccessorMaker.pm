package MooX::AccessorMaker;

use warnings;
use strict;

use Exporter ();
our @EXPORT = qw/find_accessor_maker apply_accessor_maker_roles/;

sub find_accessor_maker {
    my ($target) = @_;

    if ($Moo::Role::INFO{$target} && 
        $Moo::Role::INFO{$target}{is_role}
    ) {
        return 
            $Moo::Role::INFO{$target}{accessor_maker} ||= do {
                require Method::Generate::Accessor;
                Method::Generate::Accessor->new;
            };
    }
    elsif ($Moo::MAKERS{$target} && 
        $Moo::MAKERS{$target}{is_class}
    ) {
        return Moo->_accessor_maker_for($target);
    }
}

sub apply_accessor_maker_roles {
    my ($target, @roles) = @_;

    my $maker = find_accessor_maker($target);
    my @need = grep !$maker->DOES($_), @roles
        or return;

    require Moo::Role;
    Moo::Role->apply_roles_to_object($maker, @need);
}

sub import {
    my ($self, @args) = @_;
    my $to = caller;

    my (@export, $apply);
    while (my $arg = shift @args) {
        if ($arg eq "apply") { $apply = shift @args }
        else { push @export, $arg }
    }
    
    $self->Exporter::export($to, @export);
    $apply and apply_accessor_maker_roles $to, @$apply;
}

1;
