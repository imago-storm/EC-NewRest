package ECPDF::ComponentManager;
use strict;
use warnings;

use Data::Dumper;
use Carp;

use ECPDF::Log;

our $COMPONENTS = {};

sub new {
    my ($class) = @_;

    my $self = {
        components_local => {},
    };
    bless $self, $class;
    return $self;
}

sub loadComponentLocal {
    my ($self, $component, $params) = @_;

    eval "require $component";
    $component->import();

    my $o = $component->init($params);
    $self->{components_local}->{$component} = $o;
    return $o;
}
sub loadComponent {
    my ($self, $component, $params) = @_;

    logTrace("Loading component $component using params" . Dumper $params);
    eval "require $component";
    logTrace("Importing component $component...");
    $component->import();
    logTrace("Imported Ok");

    logTrace("Initializing $component...");
    my $o = $component->init($params);
    logTrace("Initialized Ok");
    $COMPONENTS->{$component} = $o;
    return $o;
}

sub getComponent {
    my ($self, $component) = @_;

    if (!$COMPONENTS->{$component}) {
        croak "Component $component has not been loaded as local component. Please, load it before you can use it.";
    }
    return $COMPONENTS->{$component};
}

sub getComponentLocal {
    my ($self, $component) = @_;

    if (!$self->{components_local}->{$component}) {
        croak "Component $component has not been loaded. Please, load it before you can use it.";
    }
    return $self->{components_local}->{$component};
}


1;
