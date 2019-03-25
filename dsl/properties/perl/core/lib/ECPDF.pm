package ECPDF;
use base qw/ECPDF::BaseClass/;
use strict;
use warnings;
use Carp;
use ECPDF::ContextFactory;
use Data::Dumper;

our $VERSION = '0.0.1';

sub classDefinition {
    return {
        pluginName      => 'str',
        pluginVersion   => 'str',
        configFields    => '*',
        configLocations => '*',
        contextFactory  => '*'
    };
}

sub newContext {
    my ($pluginObject) = @_;

    return $pluginObject->getContextFactory()->newContext($pluginObject);
}
sub util {}
sub pluginInfo {}

sub runStep {
    my ($class, $procedureName, $stepName, $function) = @_;

    if (!$class->can($function)) {
        croak "Class $class does not define function $function\n";
    }
    if (!$class->can('pluginInfo')) {
        croak "Class $class does not have a pluginInfo function defined\n";
    }
    my $pluginInfo = $class->pluginInfo();

    # TODO: add validation for pluginInfo fields.
    my $ecpdf = $class->new({
        pluginName      => $pluginInfo->{pluginName},
        pluginVersion   => $pluginInfo->{pluginVersion},
        configFields    => $pluginInfo->{configFields},
        configLocations => $pluginInfo->{configLocations},
        contextFactory  => ECPDF::ContextFactory->new({
            procedureName => $procedureName,
            stepName      => $stepName
        })
    });

    return $ecpdf->$function();
}
1;
