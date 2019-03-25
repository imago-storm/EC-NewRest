package ECPDF::Credential;
use base qw/ECPDF::BaseClass/;
use strict;
use warnings;

sub classDefinition {
    return {
        credentialName => 'str',
        credentialType => 'str',
        userName => 'str',
        secretValue => 'str',
    }
}

1;
