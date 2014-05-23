package Regexp::CorpusHandler::Prioritized;

sub priority {
    my $self = shift;
    my $nv   = shift;
    if (defined $nv) {
        if ($nv =~ /^\-?\d+$/) {
            $self->{PRIORITY} = $nv + 0;
        } else {
            $self->msg("[?]","priority() must be set to an integer, not '$nv'");
        }
    }
    return $self->{PRIORITY} || 0;
}

sub working_priority {
    my $self = shift;
    my $nv   = shift;
    if (defined $nv) {
        $self->{WORKING}{PRIORITY} = $nv;
    }
    return $self->{WORKING}{PRIORITY};
}

sub reset_working_priority {
    my $self = shift;
    my $val  = shift;
    my $wrk  = $self->{WORKING} ||= { };
    return $wrk->{PRIORITY} = $self->priority();
}

1;
