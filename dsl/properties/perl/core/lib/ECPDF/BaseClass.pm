# this class is designed to be a base class for different classes.
# to reduce amount of code, this class should be used as parent class.
# child class should define a classDefinition method,
# which should return hashref with parameters and their values type.
package ECPDF::BaseClass;

use strict;
use warnings;
use Data::Dumper;
use Carp;

our $AUTOLOAD;

sub AUTOLOAD {
    my ($class, @args) = @_;

    if (!$class->can('classDefinition')) {
        croak "classDefinition method should be set to make this working\n";
    }
    my $method = $AUTOLOAD;
    $method =~ s/.*:://;
    my $definition = $class->classDefinition();
    # print Dumper $definition;
    if ($method eq 'new') {
        my $object = __checkParams($class, $definition, @args);

        bless $object, $class;
        return $object;
    }

    if ($method =~ m/^get(.*?)$/s) {
        my $field = $1;

        $field = __returnFieldName($class, $field, $definition);
        return __get($class, $definition, $field, @args);
    }
    if ($method =~ m/^set(.*?)$/s) {
        my $field = $1;

        $field = __returnFieldName($class, $field, $definition);
        return __set($class, $definition, $field, @args);
    }
    croak "Unknown method $AUTOLOAD\n";
}

sub __get {
    my ($object, $definition, $field, $opts) = @_;

    if (!$field) {
        croak "Field $field is mandatory";
    }
    my $rv = undef;
    if (defined $object->{$field}) {
        $rv = $object->{$field};
        return $rv;
    }

    # if ($opts->{nonFatal}) {
    croak "Field $field does not exist";
    #}
    return undef;
}

sub __set {
    my ($object, $definition, $field, $value, $opts) = @_;

    if (!$field) {
        croak "Field is mandatory";
    }
    if (!$definition->{$field}) {
        croak "Field $field is not allowed in " . ref $object . "\n";
    }

    if ($definition->{$field} =~ m/^[A-Z]/s && (!ref $value || ref $value ne $definition->{$field})) {
        croak "Value for $field is expected to be a $definition->{field}, but not a " . ref $value;
    }
    $object->{$field} = $value;
    return $object;
}

sub __checkParams {
    my ($class, $definition, $params) = @_;
    for my $k (keys %$params) {
        if (!$definition->{$k}) {
            croak "Key $k is not defined for $class\n";
        }
        my $value = $params->{$k};
        if ($definition->{$k} =~ m/^[A-Z]/s && (!ref $value || ref $value ne $definition->{$k})) {
            my $ref = ref $value || 'unblessed reference';
            # print "REF: $ref\n";
            # print "Value: '$value'\n";
            croak "Value for $k is expected to be a type of $definition->{$k}, but not a " . $ref;
        }
    }
    return $params;
}

sub __returnFieldName {
    my ($class, $field, $definition) = @_;

    $field = lcfirst $field;
    if (!$definition->{$field}) {
        croak "Field $field does not exist in class $class";
    }

    return $field;
}


1;
