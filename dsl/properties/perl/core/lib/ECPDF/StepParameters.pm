package ECPDF::StepParameters;
use base qw/ECPDF::BaseClass/;
use strict;
use warnings;

sub classDefinition {
    return {
        parametersList => '*',
        parameters => '*'
    };
}

# sub isParameterExists {};
# sub getParameter {};
sub setParameter {};
sub setCredential {};
sub getCredential {};


sub isParameterExists {
    my ($self, $parameterName) = @_;

    my $p = $self->getParameters();
    if ($p->{$parameterName}) {
        return 1;
    }
    return 0;
}

sub getParameter {
    my ($self, $parameterName) = @_;

    if (!$self->isParameterExists($parameterName)) {
        return undef;
    }

    return $self->getParameters()->{$parameterName};
}
# sub newStepParameters {

# }
1;
