package Regexp::CorpusHandler::Action::ResultsModifierI;

use strict;
use Scalar::Util qw(weaken);
# use Regexp::CorpusHandler::Action::ActionI;
use base qw(Regexp::CorpusHandler::Action::ActionI);

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

sub source {
    my $self = shift;
    if (my $req = shift) {
        my $okSrc;
        if ($req =~ /^(\*|\$_)$/) {
            $self->{SOURCE} = '*';
        } else {
            my @srcs;
            my $hack = $req;
            my $hand = $self->handler();
            while (my $rk = $self->parse_resultAndKey( $hack )) {
                my ($key, $resName, $rep) = @{$rk};
                $resName ||= $hand->current_results_name();

                # I had considered keeping the results a string, the
                # idea being to allow recursive expansion of the
                # string based on current results values. While
                # thinking about how to implement this, it seemed both
                # a nightmare and stupid. So the source is fixed at
                # 'compile time' when the Action is defined.

                my $res = $hand->results($resName);
                push @srcs, [$res, $key];
                $hack =~ s/\Q$rep\E/ /g;
            }
            if ($#srcs != -1) {
                $okSrc = \@srcs;
                unless ($hack =~ /^\s*$/) {
                    $self->msg("[?]","Leftover unrecognized text while parsing source", "Provided: '$req'", "Leftover: '$hack'");
                }
            }
        }
        if ($okSrc) {
            $self->{SOURCE} = $okSrc;
        } else {
            $self->msg("[?]",$self->to_one_line(),
                       "Failed to set the source to '$req'",
                       "Use either '*' (the main corpus) or a Key specifier (eg 'SomeResultsName::SomeKeyName')");
        }
    }
    return $self->{SOURCE};
}

sub working_source {
    my $self = shift;
    my $src  = $self->source();
    my $hand = $self->handler();
    if (ref($src)) {
        # One or more result keys
        my @vals;
        foreach my $rk (@{$src}) {
            my ($res, $key) = @{$rk};
            my $val = $res->value( $key );
            # Any merit in including empty strings?
            push @vals, $val unless ($val eq '');
        }
        return join("\n", @vals) || "";
    } elsif ($src eq '*') {
        # The main Corpus text
        return $hand->text();
    }
    return "";
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
