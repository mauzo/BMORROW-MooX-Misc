package MooX::AccessorMaker;

use warnings;
use strict;

use Exporter "import";
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
    Moo::Role->apply_roles_to_object($maker, @need);
}

1;
