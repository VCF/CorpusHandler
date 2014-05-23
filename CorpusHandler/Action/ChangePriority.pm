package Regexp::CorpusHandler::Action::ChangePriority;

use strict;
use base qw(Regexp::CorpusHandler::Action::ActionI);


# This module is stale and needs to be reworked. It was designed to
# dynamically alter the priority of objects to change their execution
# order (or prevent execution altogether) based on events that occur
# during parsing of the corpus. As the API has evolved it will need a
# lot of work.


sub type { return "ChangePriority"; }

# Not relevant, but will be set by default
sub results { };

sub target {
    my $self = shift;
    if (my $req = shift) {
        my $obj = $req;
        if (!ref($obj)) {
            $obj = $self->handler()->parse_target($obj);
        }
        if ($obj->can('priority')) {
            $self->{TARGET} = $obj;
        } else {
            $self->err("Can not set ChangePriority target to '$req'",
                       "It does not have a priority to change");
            
        }
    }
    return $self->{TARGET};
}

*val = \&value;
sub value {
    my $self = shift;
    if (defined $_[0] && $_[0] ne '') {
        my $nv = $_[0];
        if ($nv =~ /^([\-\+])?(\d+)$/) {
            $self->{VALUE} = $2;
            if (my $d = $1) {
                $self->delta($d);
            }
        } else {
            $self->err("Can not set ChangePriority value to '$nv'",
                       "It must be a positive or negative integer");
        }
    }
    return $self->{VALUE};
}

sub delta {
    my $self = shift;
    if (defined $_[0]) {
        my $nv = $_[0] || '';
        if ($nv eq '' || $nv =~ /^[0\-\+]$/) {
            $self->{DELTA} = $nv;
        } else {
            $self->err("Can not set ChangePriority delta to '$nv'",
                       "It must be zero, '+' (plus) or '-' (minus)");
        }
    }
    return $self->{DELTA} || 0;
}

sub to_one_line {
    my $self = shift;
    my $txt  = $self->SUPER::to_one_line();
    my $targ = $self->target();
    $targ = $targ ? $targ->fullname() : '-UNDEFINED-';
    $txt .= sprintf(" \"%s\" %s= %d", $targ, $self->delta() || '', $self->value());
    return $txt;
}

sub run {
    my $self = shift;
    my $targ = $self->target();
    return undef unless ($targ);
    my ($d, $v) = ($self->delta(), $self->value());
    if ($d) {
        my $pri = $targ->working_priority();
        if ($d eq '+') {
            $pri += $v;
        } else {
            $pri -= $v;
        }
        return $targ->working_priority( $pri );
    } else {
        return $targ->working_priority( $v );
    }
}
