package ECPDF::StepResult;
use base qw/ECPDF::BaseClass/;
use strict;
use warnings;
use Carp;
use Data::Dumper;
use ECPDF::StepResult::Action;

sub classDefinition {
    return {
        context => 'ECPDF::Context',
        actions => '*',
        cache => '*'
    };
}

sub apply {
    my ($self) = @_;

    my $actions = $self->getActions();
    for my $action (@$actions) {
        if (!ref $action) {
            # TODO: Improve error message here.
            croak "Reference is expected";
        }
        if (ref $action ne 'ECPDF::StepResult::Action') {
            croak "ECPDF::StepResult::Action is expected. Got: ", ref $action;
        }

        my $currentAction = $action->getActionType();
        my $left = $action->getEntityName();
        my $right = $action->getEntityValue();
        my $ec = $self->getContext()->getEc();
        if ($currentAction eq 'setJobOutcome' || $currentAction eq 'setJobStepOutcome') {
            $ec->setProperty($left, $right);
        }
        # TODO: Refactor this if condition
        elsif ($currentAction eq 'setPipelineSummary' || $currentAction eq 'setOutcomeProperty' || $currentAction eq 'setJobSummary' || $currentAction eq 'setJobStepSummary') {
            $ec->setProperty($left, $right);
        }
        elsif ($currentAction eq 'setOutputParameter') {
            croak "Output parameters are not implemented yet for StepResult\n";
        }
        else {
            croak "Action $currentAction is not implemented yet\n";
        }
    }
    print Dumper $self->{actions};
    print Dumper $self->{cache};
    return $self;

}


sub getCacheForAction {
    my ($self, $actionType, $name, $value) = @_;

    my $cache = $self->getCache();
    if ($cache->{$actionType} && $cache->{$actionType}->{$name}) {
        return $cache->{$actionType}->{$name};
    }
    return '';
}

sub setCacheForAction {
    my ($self, $actionType, $name, $value) = @_;

    print "Parameters for set cache: '$actionType', '$name', '$value'\n";
    my $cache = $self->getCache();
    my $line = $value;
    if ($cache->{$actionType} && $cache->{$actionType}->{$name}) {
        $line = sprintf("%s\n%s", $line, $value);
    }

    $cache->{$actionType}->{$name} = $line;
    return $line;
}

sub setJobStepOutcome {
    my ($self, $path, $outcome) = @_;

    # if (!$path || !$outcome) {
    #     croak "Path and outcome are mandatory for setOutcome function.\n";
    # }
    # If only one parameter has been provided, we're setting other parameters.
    if ($path && !$outcome) {
        $outcome = $path;
        $path = '/myJobStep/outcome';
    }
    if ($outcome !~ m/^(?:error|warning|success)$/s) {
        croak "Outcome is expected to be one of: error, warning, success. Got: $outcome\n";
    }
    my $action = ECPDF::StepResult::Action->new({
        actionType  => 'setJobOutcome',
        entityName  => $path,
        entityValue => $outcome
    });

    my $actions = $self->getActions();
    push @$actions, $action;
    return $self;

}


sub setPipelineSummary {
    my ($self, $pipelineProperty, $pipelineSummary) = @_;

    if (!$pipelineProperty || !$pipelineSummary) {
        croak "pipelineProperty and pipelineSummary are mandatory.\n";
    }

    my $action = ECPDF::StepResult::Action->new({
        actionType  => 'setPipelineSummary',
        entityName  => '/myPipelineStageRuntime/ec_summary/' . $pipelineProperty,
        entityValue => $self->setCacheForAction('setPipelineSummary', $pipelineSummary)
    });

    my $actions = $self->getActions();
    push @$actions, $action;
    return $self;
}


sub setJobStepSummary {
    my ($self, $summary) = @_;

    if (!$summary) {
        croak "Summary is mandatory in setJobStepSummary\n";
    }

    my $property = '/myJobStep/summary';
    my $action = ECPDF::StepResult::Action->new({
        actionType => 'setJobStepSummary',
        entityName => $property,
        entityValue => $self->setCacheForAction('setJobStepSummary', $property, $summary)
    });
    my $actions = $self->getActions();
    push @$actions, $action;
    return $self;
}

sub setJobSummary {
    my ($self, $summary) = @_;

    if (!$summary) {
        croak "Summary is mandatory in setJobStepSummary\n";
    }

    my $property = '/myCall/summary';
    my $action = ECPDF::StepResult::Action->new({
        actionType => 'setJobSummary',
        entityName => $property,
        entityValue => $self->setCacheForAction('setJobSummary', $property, $summary)
    });
    my $actions = $self->getActions();
    push @$actions, $action;
    return $self;
}

sub setOutcomeProperty {
    my ($self, $propertyPath, $propertyValue) = @_;

    if (!$propertyPath || !$propertyValue) {
        croak "PropertyPath and PropertyValue are mandatory";
    }

    my $action = ECPDF::StepResult::Action->new({
        actionType => 'setOutcomeProperty',
        entityName => $propertyPath,
        entityValue => $propertyValue
    });
    my $actions = $self->getActions();
    push @$actions, $action;
    return $self;
}

sub flush {
    my ($self) = @_;

    my $actions = $self->getActions();
    # now we're copying an actions array because it is a reference.
    my @clonedActions = @$actions;
    $self->setActions([]);
    $self->setCache({});

    return \@clonedActions;
}

sub applyAndFlush {
    my ($self) = @_;

    $self->apply();
    return $self->flush();
}

1;

