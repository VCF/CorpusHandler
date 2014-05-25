package Regexp::CorpusHandler::Action::ResultsModifierI;

use strict;
use Scalar::Util qw(weaken);
# use Regexp::CorpusHandler::Action::ActionI;
use base qw( Regexp::CorpusHandler::Action::ActionI
             Regexp::CorpusHandler::Sourced);

sub new {
    my $class = shift;
    my $self = $class->SUPER::new( @_ );
    $self->set_defaults();
    return $self;
}

sub set_defaults {
    my $self = shift;
    unless ($self->source()) {
        # Use the main CorpusHandler text as the default source
        $self->source('*');
    }
    unless (defined $self->weight()) {
        $self->weight(1);
    }
    $self->SUPER::set_defaults( @_ );
}

sub weight {
    my $self = shift;
    if (defined $_[0]) {
        my $nv = $_[0];
        if (my $wd = $self->parse_weightAndDelta($nv)) {
            $self->{W} = $wd->[0];
            $self->delta($wd->[1]);
        } else {
            $self->msg("[!]","Can not set weight to '$nv'",
                       "Must be a floating point number or integer");
        }
    }
    return $self->{W};
}

sub delta {
    my $self = shift;
    if (defined $_[0]) {
        my $nv = $_[0] || '';
        if (my $d = $self->parse_delta($nv)) {
            $self->{DELTA} = $d->[0];
        } else {
            $self->err("Can not set ".$self->type()." delta to '$nv'",
                       "It must be zero, '+' (plus) or '-' (minus)");
        }
    }
    return $self->{DELTA} || '';
}

sub delta_weight {
    my $self = shift;
    return $self->delta() . $self->weight();
}

sub key {
    my $self = shift;
    if (my $req = shift) {
        my $hack = $req;
        my $key;
        while (my $rk = $self->parse_resultAndKey( $hack, 'loose' )) {
            my ($k, $resName, $rep) = @{$rk};
            $hack =~ s/\Q$rep\E/ /g;
            $self->results($resName) if ($resName);
            $key = $k;
            last;
        }
        if (!$key) {
            $self->err("Failed to identify key() in '$req'");
        } else {
            $self->{TARGKEY} = $key;
            $self->err("Parsed key($key) from '$req'",
                       "Extra text ignored: '$hack'") if ($hack !~ /^\s*$/);
        }
    }
    return $self->{TARGKEY};
}

sub results {
    my $self = shift;
    if (my $req = shift) {
        if (my $obj = $self->results_object($req)) {
            $self->{TARGRES} = $obj;
        } else {
            die "MESSAGE HERE";
        }
    }
    return $self->{TARGRES};
}

sub condition {
    my $self = shift;
    return undef;
}

sub run_immediately { return 0; }

*init = \&reset;
sub reset {
    my $self = shift;
    $self->SUPER::reset();
    $self->{WORKING}{TARGKEY} = $self->key();
    $self->{WORKING}{TARGRES} = $self->results();
    $self->run() if ($self->run_immediately());
}

sub working_key {
    my $self = shift;
    if (my $nv = shift) {
        die "WORKING!";
        
    }
    return $self->{WORKING}{TARGKEY};
}

sub working_results {
    my $self = shift;
    if (my $nv = shift) {
        die "WORKING!";
        
    }
    return $self->{WORKING}{TARGRES};
    
}
