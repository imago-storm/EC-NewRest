package ECPDF::ContextFactory;
use base qw/ECPDF::BaseClass/;
use strict;
use warnings;
use Data::Dumper;
use ECPDF::Context;
use ElectricCommander;

sub classDefinition {
    return {
        procedureName => 'str',
        stepName      => 'str'
    };
}

sub newContext {
    my ($self, $ecpdf) = @_;

    my $context = ECPDF::Context->new({
        procedureName => $self->getProcedureName(),
        stepName      => $self->getStepName(),
        pluginObject  => $ecpdf,
        ec            => ElectricCommander->new()
    });
    return $context;
}


1;
