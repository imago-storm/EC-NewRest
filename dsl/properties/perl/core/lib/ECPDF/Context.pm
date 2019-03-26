package ECPDF::Context;

=head1 NAME

ECPDF::Context

=head1 DESCRIPTION

ECPDF::Context is a class that represents current running context.

This class allows user to access procedure parameters, config values and define a step result.

=head1 METHODS

=cut


use base qw/ECPDF::BaseClass/;
use strict;
use warnings;

use ECPDF::Config;
use ECPDF::StepParameters;
use ECPDF::Parameter;
use ECPDF::Credential;
use ECPDF::StepResult;
use ECPDF::Log;

use Carp;
use Data::Dumper;
use ElectricCommander;

sub classDefinition {
    return {
        procedureName         => 'str',
        stepName              => 'str',
        runContext            => 'str',
        pluginObject          => '*',
        ec                    => 'ElectricCommander',
        currentStepParameters => '*',
    };
}

=over 

=item B<getStepParameters>

Returns a L<ECPDF::StepParameters> object to be used as accessor for current step parameters.
This method does not require parameters.

    my $params = $context->getStepParameters();
    # this method returns a L<ECPDF::Parameter> object, or undef, if no parameter with that name has been found.
    my $param = $params->getParameter('myStepParameter');
    if ($param) {
        print "Param value is:", $param->getValue(), "\n";
    }

=back

=cut

sub getStepParameters {
    my ($context) = @_;

    if (my $retval = $context->getCurrentStepParameters()) {
        return $retval;
    }
    my $stepParametersHash = $context->getCurrentStepParametersAsHash();

    my $parametersList = [];
    my $parameters = {};
    for my $k (keys %$stepParametersHash) {
        push @{$parametersList}, $k;
        my $p;
        if (!ref $stepParametersHash->{$k}) {
            $p = ECPDF::Parameter->new({
                name  => $k,
                value => $stepParametersHash->{$k}
            });
        }
        else {
            # it is a hash reference, so it is credential
            my $value = ECPDF::Credential->new({
                credentialName => $k,
                # TODO: Change it to something more reliable later.
                # Currently we have support of default credentials only.
                credentialType => 'default',
                userName => $stepParametersHash->{$k}->{userName},
                secretValue => $stepParametersHash->{$k}->{password},
            });
        }
        $parameters->{$k} = $p;
    }

    my $stepParameters = ECPDF::StepParameters->new({
        parametersList => $parametersList,
        parameters => $parameters
    });

    $context->setCurrentStepParameters($stepParameters);
    return $stepParameters;
}

=over

=item B<getConfigValues>

This method returns a L<ECPDF::Config> object that represents plugin configuration. This method does not require parameters.

    my $configValues = $context->getConfigValues();
    my $cred = $configValues->getParameter('credential');
    if ($cred) {
        print "Secret value is: ", $cred->getSecretValue(), "\n";
    }

=back

=cut

sub getConfigValues {
    my ($context) = @_;

    my $stepParameters = $context->getStepParameters();
    my $po = $context->getPluginObject();
    logTrace("Plugin Object: ", Dumper $po);
    my $configLocations = $po->getConfigLocations();
    my $configFields    = $po->getConfigFields();

    my $configField = undef;
    for my $field (@$configFields) {
        if ($stepParameters->isParameterExists($field)) {
            $configField = $field;
            last;
        }
    }

    if (!$configField) {
        croak "No config field detected in current step parameters";
    }
    my $configHash = undef;
    for my $location (@$configLocations) {
        my $tempConfig = $context->retrieveConfigByNameAndLocation(
            $stepParameters->getParameter($configField)->getValue(),
            $location
        );

        if ($tempConfig) {
            $configHash = $tempConfig;
            last;
        }
    }

    # TODO: Improve this error message.
    if (!$configHash) {
        croak "Config does not exist";
    }

    my $keys = [];
    my $configValuesHash = {};
    for my $k (keys %$configHash) {
        push @$keys, $k;

        my $tempRow = $configHash->{$k};
        # TODO: Refactor this a bit, move my $value to this line
        if (!ref $tempRow) {
            my $value = ECPDF::Parameter->new({
                name => $k,
                value => $configHash->{$k}
            });
            $configValuesHash->{$k} = $value;
        }
        else {
            my $value = ECPDF::Credential->new({
                credentialName => $k,
                # TODO: Change it to something more reliable later.
                credentialType => 'default',
                userName => $configHash->{$k}->{userName},
                secretValue => $configHash->{$k}->{password},
            });
            $configValuesHash->{$k} = $value;
        }
    }

    my $retval = ECPDF::Config->new({
        parametersList => $keys,
        parameters => $configValuesHash
    });
    return $retval;
}

sub retrieveConfigByNameAndLocation {
    my ($self, $configName, $configLocation) = @_;

    my $po = $self->getPluginObject();
    my $plugin_project_name = sprintf(
        '%s-%s',
        $po->getPluginName(),
        $po->getPluginVersion()
    );
    # my $ec = $self->getEc();
    # Retrieving a places where plugin configs could be stored. They will be queued from first to last.
    my $config_locations = $po->getConfigLocations();
    my $config_fields = $po->getConfigFields();

    my $config_property_sheet = sprintf("/projects/%s/%s/%s", $plugin_project_name, $configLocation, $configName);
    logDebug("Config property sheet: $config_property_sheet");
    my $property_sheet_id = eval { $self->getEc->getProperty($config_property_sheet)->findvalue('//propertySheetId')->string_value };
    if ($@) {
        return undef;
    }
    my $properties = $self->getEc->getProperties({propertySheetId => $property_sheet_id});

    my $retval = {};
    for my $node ( $properties->findnodes('//property')) {
        my $value = $node->findvalue('value')->string_value;
        my $name = $node->findvalue('propertyName')->string_value;
        if ($name =~ m/_?credential$/s) {
            my $credentials = $self->getEc->getFullCredential($configName);
            my $user_name = $credentials->findvalue('//userName')->string_value;
            my $password = $credentials->findvalue('//password')->string_value;
            # $retval->{$name} = {};
            $retval->{$name}->{userName} = $user_name;
            $retval->{$name}->{password} = $password;
        }
        else {
            $retval->{$name} = $value;
        }

    }

    print "Retval", Dumper $retval;
    return $retval;

}

=over

=item B<newStepResult>

This method returns an L<ECPDF::StepResult> object, which is being used to work with procedure output.

    my $stepResult = $context->newStepResult();
    ...;
    $stepResult->apply();

=back

=cut

sub newStepResult {
    my ($self) = @_;

    return ECPDF::StepResult->new({
        context => $self,
        actions => [],
        cache   => {}
    });
}

# getPluginObject is defined automatically.
# sub getPluginObject {};

sub new {
    my ($class, @params) = @_;

    my $context = $class->SUPER::new(@params);
    unless ($context->getEc()) {
        $context->setEc(ElectricCommander->new());
    }

    $context->setRunContext($context->buildRunContext());

    return $context;
}


sub buildRunContext {
    my ($self) = @_;

    my $ec = $self->getEc();
    my $context = 'pipeline';
    my $flowRuntimeId = '';

    eval {
        $flowRuntimeId = $ec->getProperty('/myFlowRuntimeState/id')->findvalue('//value')->string_value;
    };
    return $context if $flowRuntimeId;

    eval {
        $flowRuntimeId = $ec->getProperty('/myFlowRuntime/id')->findvalue('/value')->string_value();
    };
    return $context if $flowRuntimeId;

    eval {
        $flowRuntimeId = $ec->getProperty('/myPipelineStageRuntime/id')->findvalue('/value')->string_value();
    };
    return $context if $flowRuntimeId;

    $context = 'schedule';
    my $scheduleName = '';
    eval {
        $scheduleName = $self->getCurrentScheduleName();
        1;
    } or do {
        logError("error occured: $@");
    };

    if ($scheduleName) {
        return $context;
    }
    $context = 'procedure';
    return $context;
}


sub getCurrentScheduleName {
    my ($self, $jobId) = @_;

    $jobId ||= $ENV{COMMANDER_JOBID};

    my $scheduleName = '';
    eval {
        my $result = $self->getEc()->getJobDetails($jobId);
        $scheduleName = $result->findvalue('//scheduleName')->string_value();
        if ($scheduleName) {
            # $self->logger()->info('Schedule found: ', $scheduleName);
            logDebug("Schedule found: $scheduleName");
        };
        1;
    } or do {
        # $self->logger()->error($@);
        logError("Error: $@");
    };

    return $scheduleName;
}

sub getCurrentStepParameters {
    # return $self->get_step_parameters();
}

sub readActualParameter {
    my ($self, $param) = @_;

    my $ec = $self->getEc();
    my $retval;
    my $xpath;


    my @subs = ();
    push @subs, sub {
        my $jobId = $ec->getProperty('/myJob/id')->findvalue('//value')->string_value;
        my $xpath = $ec->getActualParameter({
            jobId => $jobId,
            actualParameterName => $param
        });
        return $xpath;
    };

    push @subs, sub {
        my $jobStepId = $ec->getProperty('/myJobStep/id')->findvalue('//value')->string_value;
        my $xpath = $ec->getActualParameter({
            jobStepId => $jobStepId,
            actualParameterName => $param,
        });
        return $xpath;
    };

    push @subs, sub {
        my $jobStepId = $ec->getProperty('/myJobStep/parent/id')->findvalue('//value')->string_value;
        my $xpath = $ec->getActualParameter({
            jobStepId => $jobStepId,
            actualParameterName => $param,
        });
        return $xpath;
    };


    push @subs, sub {
        my $jobStepId = $ec->getProperty('/myJobStep/parent/parent/id')->findvalue('//value')->string_value;
        my $xpath = $ec->getActualParameter({
            jobStepId => $jobStepId,
            actualParameterName => $param,
        });
        return $xpath;
    };


    for my $sub (@subs) {
        my $xpath = eval { $sub->() };

        if (!$@ && $xpath && $xpath->exists('//actualParameterName')) {
            return $xpath->findvalue('//value')->string_value;
        }

    }

    die qq{Failed to get actual parameter $param};
}

sub get_param {
    my ($self, $param) = @_;

    my $retval;
    eval {
        $retval = $self->readActualParameter($param);
        logInfo(qq{Got parameter "$param" with value "$retval"\n});
        1;
    } or do {
        logError("Error '$@' was occured while getting property: $param");
        $retval = undef;
    };
    return $retval;
}

sub getCurrentStepParametersAsHash {
    my ($self) = @_;

    my $params = {};
    my $procedure_name = $self->getEc()->getProperty('/myProcedure/name')->findvalue('//value')->string_value;
    my $po = $self->getPluginObject();
    my $xpath = $self->getEc()->getFormalParameters({
        # projectName => '@PLUGIN_NAME@',
        projectName => sprintf('%s-%s', $po->getPluginName(), $po->getPluginVersion()),
        procedureName => $procedure_name
    });
    for my $param ($xpath->findnodes('//formalParameter')) {
        my $name = $param->findvalue('formalParameterName')->string_value;
        my $value = $self->get_param($name);

        my $name_in_list = $name;
        # TODO: Add credentials handling logic. Now we're nexting.
        if ($param->findvalue('type')->string_value eq 'credential') {
            my $cred = $self->getEc()->getFullCredential($value);
            my $username = $cred->findvalue('//userName')->string_value;
            my $password = $cred->findvalue('//password')->string_value;
            $params->{$name_in_list}->{userName} = $username;
            $params->{$name_in_list}->{password} = $password;
        }
        else {
            # TODO: Add trim here
            $params->{$name_in_list} = $value;
            # $self->out(1, qq{Got parameter "$name" with value "$value"\n});
            logInfo(qq{Got parameter "$name" with value "$value"\n});
        }
    }
    return $params;
}

1;
