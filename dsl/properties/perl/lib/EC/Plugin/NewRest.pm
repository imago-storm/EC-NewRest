package EC::Plugin::NewRest;
use strict;
use warnings;
use base qw/ECPDF/;
use Data::Dumper;

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
    my $context = $pluginObject->newContext();
    print "Current context is: ", $context->getRunContext(), "\n";
    my $params = $context->getStepParameters();
    # print Dumper $params;

    # print $params->isParameterExists('config'), "\n";
    my $headers = $params->getParameter('request_headers');
    my $config = $params->getParameter('config');


    # print Dumper $headers;
    # print Dumper $config;
    printf "Config: %s, headers: %s\n", $config->getValue(), $headers->getValue();

    my $configValues = $context->getConfigValues();

    # print Dumper $configValues;

    my $stepResult = $context->newStepResult();
    print "Created stepresult\n";
    $stepResult->setJobStepOutcome('warning');
    print "Set stepResult\n";

    $stepResult->setJobSummary("See, this is a whole job summary");
    $stepResult->setJobStepSummary('And this is a job step summary');

    $stepResult->apply();
}
## === step ends ===


1;