package ECPDF::Plugin;
use strict;
use warnings;
use Carp;
use Data::Dumper;
sub new {
    my ($class) = @_;

    my $self = {};
    bless $self, $class;
    return $self;
}

sub import {
    my ($package) = @_;

    my $type = '';
    if ($package =~ m/Logic$/s) {
        $type = 'logic';
    }
    elsif ($package =~ m/EF$/s) {
        $type = 'ef';
    }
    ECPDF::register_ep($type => $package);
}

sub get_ep {
    print "Calling base EP\n";
    #     croak "Can't register base class as an entry point";
}

1;
