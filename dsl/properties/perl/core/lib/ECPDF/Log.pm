package ECPDF::Log;
use base qw/Exporter/;

our @EXPORT = qw/logInfo logDebug logTrace logError/;
use strict;
use warnings;
use Data::Dumper;

our $LOG_LEVEL = 0;
our $LOG_TO_PROPERTY = '';

use constant {
    ERROR => -1,
    INFO  => 0,
    DEBUG => 1,
    TRACE => 2,
};

sub new {
    my ($class, $opts) = @_;

    my ($level, $log_to_property);

    if (!defined $opts->{level}) {
        $level = $LOG_LEVEL;
    }
    if (!defined $opts->{log_to_property}) {
        $log_to_property = $LOG_TO_PROPERTY;
    }
    my $self = {
        level           => $level,
        log_to_property => $log_to_property
    };
    bless $self, $class;
    return $self;
}

sub logInfo {
    my @params = @_;
    if (!ref $params[0]) {
        unshift @params, __PACKAGE__->new();
    }
    return info(@params);
}
sub info {
    my ($self, @messages) = @_;
    $self->_log(INFO, @messages);
}

sub logDebug {
    my @params = @_;
    if (!ref $params[0]) {
        unshift @params, __PACKAGE__->new();
    }
    return debug(@params);
}
sub debug {
    my ($self, @messages) = @_;
    $self->_log(DEBUG, '[DEBUG]', @messages);
}

sub logError {
    my @params = @_;
    if (!ref $params[0]) {
        unshift @params, __PACKAGE__->new();
    }
    return error(@params);
}
sub error {
    my ($self, @messages) = @_;
    $self->_log(ERROR, '[ERROR]', @messages);
}

sub logTrace {
    my @params = @_;
    if (!ref $params[0]) {
        unshift @params, __PACKAGE__->new();
    }
    return trace(@params);
}
sub trace {
    my ($self, @messages) = @_;
    $self->_log(TRACE, '[TRACE]', @messages);
}

sub level {
    my ($self, $level) = @_;

    if (defined $level) {
        $self->{level} = $level;
    }
    else {
        return $self->{level};
    }
}

sub log_to_property {
    my ($self, $prop) = @_;

    if (defined $prop) {
        $self->{log_to_property} = $prop;
    }
    else {
        return $self->{log_to_property};
    }
}


my $length = 40;

sub divider {
    my ($self, $thick) = @_;

    if ($thick) {
        $self->info('=' x $length);
    }
    else {
        $self->info('-' x $length);
    }
}

sub header {
    my ($self, $header, $thick) = @_;

    my $symb = $thick ? '=' : '-';
    $self->info($header);
    $self->info($symb x $length);
}

sub _log {
    my ($self, $level, @messages) = @_;

    return if $level > $self->level;
    my @lines = ();
    for my $message (@messages) {
        if (ref $message) {
            print Dumper($message);
            push @lines, Dumper($message);
        }
        else {
            print "$message\n";
            push @lines, $message;
        }
    }

    if ($self->{log_to_property}) {
        my $prop = $self->{log_to_property};
        my $value = "";
        eval {
            $value = $self->ec->getProperty($prop)->findvalue('//value')->string_value;
            1;
        };
        unshift @lines, split("\n", $value);
        $self->ec->setProperty($prop, join("\n", @lines));
    }
}


sub ec {
    my ($self) = @_;
    unless($self->{ec}) {
        require ElectricCommander;
        my $ec = ElectricCommander->new;
        $self->{ec} = $ec;
    }
    return $self->{ec};
}
