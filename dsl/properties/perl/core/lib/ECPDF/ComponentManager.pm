package ECPDF::ComponentManager;
use strict;
use warnings;
use Data::Dumper;
use Carp;

our $COMPONENTS = {};

sub new {
    my ($class) = @_;

    my $self = {
        components_local => {},
    };
    bless $self, $class;
    return $self;
}

sub load_component_local {
    my ($self, $component, $params) = @_;

    eval "require $component";
    $component->import();

    my $o = $component->init($params);
    $self->{components_local}->{$component} = $o;
    return $o;
}
sub load_component {
    my ($self, $component, $params) = @_;

    eval "require $component";
    $component->import();

    my $o = $component->init($params);
    $COMPONENTS->{$component} = $o;
    return $o;
}

sub get_component {
    my ($self, $component) = @_;

    if (!$COMPONENTS->{$component}) {
        croak "Component $component has not been loaded as local component. Please, load it before you can use it.";
    }
    return $COMPONENTS->{$component};
}

sub get_component_local {
    my ($self, $component) = @_;

    if (!$self->{components_local}->{$component}) {
        croak "Component $component has not been loaded. Please, load it before you can use it.";
    }
    return $self->{components_local}->{$component};
}
1;
