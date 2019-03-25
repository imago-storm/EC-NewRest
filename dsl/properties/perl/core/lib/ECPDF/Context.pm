package ECPDF::Context;
use base qw/ECPDF::BaseClass/;
use strict;
use warnings;

use ECPDF::Config;
use ECPDF::StepParameters;
use ECPDF::Parameter;
use ECPDF::Credential;
use ECPDF::StepResult;
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

# sub new {
#     my ($self, $params) = @_;

#     if (!$params->{ec}) {
#         $params->{ec} = ElectricCommander->new();
#     }
# }
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
        my $p = ECPDF::Parameter->new({name => $k, value => $stepParametersHash->{$k}});
        $parameters->{$k} = $p;
    }

    my $stepParameters = ECPDF::StepParameters->new({
        parametersList => $parametersList,
        parameters => $parameters
    });

    $context->setCurrentStepParameters($stepParameters);
    return $stepParameters;
}


sub getConfigValues {
    my ($context) = @_;

    my $stepParameters = $context->getStepParameters();
    my $po = $context->getPluginObject();
    print "Got plugin object:", Dumper $po;
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
                userName => $configValuesHash->{$k}->{userName},
                secretValue => $configValuesHash->{$k}->{password},
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
    print "Config property sheet: $config_property_sheet\n";
    my $property_sheet_id = eval { $self->getEc->getProperty($config_property_sheet)->findvalue('//propertySheetId')->string_value };
    if ($@) {
        return undef;
    }
    my $properties = $self->getEc->getProperties({propertySheetId => $property_sheet_id});

    my $retval = {};
    for my $node ( $properties->findnodes('//property')) {
        my $value = $node->findvalue('value')->string_value;
        my $name = $node->findvalue('propertyName')->string_value;
        $retval->{$name} = $value;


        if ($name =~ /proxy_credential/) {
            # Proxy credential can exist not, and EC will fail. Avoiding
            my $saved_abort_on_error_value = $self->getEc->abortOnError();
            eval {
                $self->getEc->abortOnError(0);
                my $credentials = $self->getEc->getFullCredential($configName . '_proxy_credential');
                my $user_name = $credentials->findvalue('//userName')->string_value;
                my $password = $credentials->findvalue('//password')->string_value;

                $retval->{proxy_credential}->{userName} = $user_name;
                $retval->{proxy_credential}->{password} = $password;
            } or do {
                print "Can't get proxy credential: $@ \n";
            };

            # Restore value
            $self->getEc()->abortOnError($saved_abort_on_error_value);
        }
        elsif ($name =~ /credential/) {
            my $credentials = $self->getEc->getFullCredential($configName);
            my $user_name = $credentials->findvalue('//userName')->string_value;
            my $password = $credentials->findvalue('//password')->string_value;
            print "RETVAL:", Dumper $retval;
            $retval->{credential} = {};
            $retval->{credential}->{userName} = $user_name;
            $retval->{credential}->{password} = $password;
        }

    }

    return $retval;

}
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
        print "error occured: $@\n";
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
            print "Schedule found: $scheduleName\n";
        };
        1;
    } or do {
        # $self->logger()->error($@);
        print "Error: $@\n";
    };

    return $scheduleName;
}

sub getCurrentStepParameters {
    # return $self->get_step_parameters();
}

sub read_actual_parameter {
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
        $retval = $self->read_actual_parameter($param);
        print qq{Got parameter "$param" with value "$retval"\n};
        1;
    } or do {
        print "Error '$@' was occured while getting property: $param";
        $retval = undef;
    };
    return $retval;
}

sub getCurrentStepParametersAsHash {
    my ($self) = @_;

    my $params = {};
    my $procedure_name = $self->getEc()->getProperty('/myProcedure/name')->findvalue('//value')->string_value;
    my $xpath = $self->getEc()->getFormalParameters({projectName => '@PLUGIN_NAME@', procedureName => $procedure_name});
    for my $param ($xpath->findnodes('//formalParameter')) {
        my $name = $param->findvalue('formalParameterName')->string_value;
        my $value = $self->get_param($name);

        my $name_in_list = $name;
        # TODO: Revisit this line
        # $name_in_list =~ s/ecp_weblogic_//;
        # TODO: Add credentials handling logic. Now we're nexting.
        if ($param->findvalue('type')->string_value eq 'credential') {
            # my $cred = $self->getEc()->getFullCredential($value);
            # my $username = $cred->findvalue('//userName')->string_value;
            # my $password = $cred->findvalue('//password')->string_value;

            # $params->{$name_in_list . 'Username'} = $username;
            # $params->{$name_in_list . 'Password'} = $password;
        }
        else {
            # TODO: Add trim here
            $params->{$name_in_list} = $value;
            # $self->out(1, qq{Got parameter "$name" with value "$value"\n});
            print qq{Got parameter "$name" with value "$value"\n};
        }
    }
    return $params;
}

1;
