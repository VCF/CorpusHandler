package Regexp::CorpusHandler::Weighted;

use strict;


*defweight = \&default_weight;
sub default_weight {
    my $self = shift;
    if (defined $_[0]) {
        my $nv = $_[0];
        if (my $wd = $self->parse_weightAndDelta($nv)) {
            $self->{DEFW} = $wd->[0];
            $self->default_delta($wd->[1]);
        } else {
            $self->msg("[!]","Can not set default_weight to '$nv'",
                       "Must be a floating point number or integer");
        }
    }
    return defined $self->{DEFW} ? $self->{DEFW} : 1;
}

*defdelta = \&default_delta;
sub default_delta {
    my $self = shift;
    if (defined $_[0]) {
        my $nv = $_[0] || '';
        if (my $d = $self->parse_delta($nv)) {
            $self->{DEFD} = $d->[0];
        } else {
            $self->err("Can not set default_delta to '$nv'",
                       "It must be zero, '+' (plus) or '-' (minus)");
        }
    }
    return $self->{DEFD} || "";
}

sub default_delta_weight {
    my $self = shift;
    return $self->default_delta() . $self->default_weight();
}

