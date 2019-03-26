package ECPDF::Client::REST;
use base qw/ECPDF::BaseClass/;
use ECPDF::ComponentManager;
use strict;
use warnings;
use LWP::UserAgent;
use HTTP::Request;

sub classDefinition {
    return {
        ua    => 'LWP::UserAgent',
        proxy => '*',
        oauth => '*'
    };
}

sub new {
    my ($class, $params) = @_;

    if (!$params->{ua}) {
        $params->{ua} = LWP::UserAgent->new();
    }
    if ($params->{proxy}) {
        my $proxy = ECPDF::ComponentManager->loadComponent('ECPDF::Component::Proxy', $params->{proxy})->init();
        $proxy->apply();
        $params->{ua} = $proxy->augment_lwp($params->{ua});
    }
    my $self = $class->SUPER::new($params);
    return $self;

}

sub newRequest {
    my ($self, @params) = @_;

    my $req = HTTP::Request->new(@params);
    my $proxy = $self->getProxy();
    if ($proxy) {
        my $proxyComponent = ECPDF::ComponentManager->getComponent('ECPDF::Component::Proxy');
        $req = $proxyComponent->augment_request($req);
    }
    return $req;
}


sub doRequest {
    my ($self, @params) = @_;

    my $ua = $self->getUa();
    return $ua->request(@params);
}


1;
