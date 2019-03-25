package ECPDF::Parameter;
use base qw/ECPDF::BaseClass/;
use strict;
use warnings;


sub classDefinition {
    return {
        name => 'str',
        value => 'str'
    };
}


sub set {
    my ($self, $name, $value) = @_;

    $self->setName($name);
    $self->setValue($value);

    return 1;
}

1;
