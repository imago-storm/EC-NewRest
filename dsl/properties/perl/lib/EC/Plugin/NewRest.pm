package EC::Plugin::NewRest;
use strict;
use warnings;
use base qw/ECPDF/;
use ECPDF::Log;
use Data::Dumper;
use Carp;

# Service function that is being used to set some metadata for a plugin.
sub pluginInfo {
    return {
        pluginName    => '@PLUGIN_KEY@',
        pluginVersion => '@PLUGIN_VERSION@',
        configFields  => ['config'],
        configLocations => ['ec_plugin_cfgs']
    };
}

sub sampleProcedure {
    my ($pluginObject) = @_;

    # retrieving current context:
    my $context = $pluginObject->newContext();

    # retrieving parameters for the current step
    my $params = $context->getStepParameters();

    # retrieving config values, well, we don't need them for this procedure,
    # so, we're commenting them out
    # my $configValues = $context->getConfigValues();


    my $targetUrl = $params->getParameter('targetUrl');
    unless ($targetUrl) {
        croak "Missing target URL\n";
    }

    my $restClient = $context->newRESTClient();
    my $request = $restClient->newRequest(GET => $targetUrl->getValue());


    my $response = $restClient->doRequest($request);
    logInfo("Response code: " . $response->code());
    logInfo("Response content:", $response->decoded_content());
    my $stepResult = $context->newStepResult();
    if ($response->is_success()) {
        $stepResult->setJobStepOutcome('success');
        $stepResult->setJobStepSummary("Successfully performed GET from ", $targetUrl->getValue());
    }
    else {
        $stepResult->setJobStepOutcome('error');
        $stepResult->setJobStepSummary("Error occured during GET from ", $targetUrl->getValue());
    }

    $stepResult->apply();
}
## === step ends ===


1;
