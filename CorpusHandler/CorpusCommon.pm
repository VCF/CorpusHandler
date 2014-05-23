package Regexp::CorpusHandler::CorpusCommon;

use strict;
use Scalar::Util qw(weaken);
use base qw( BMS::ErrorInterceptor );
use parent qw( Regexp::CorpusHandler::TokenParser );
use Data::Dumper;

sub new {
    my $class = shift;
    my $self = { };
    bless $self, $class;
    $self->death("This package ($self) is not intended to be used directly",
                 "It is inherited by other, more specific classes");
}


sub set_defaults {
    my $self = shift;
    my $hand = $self->handler();
    if ($self->can('priority') && !$self->priority()) {
        $self->priority( ++$hand->{AUTOPRIORITY} );
    }
    unless ($self->name()) {
        $self->name( sprintf("%s%03d", $self->can('type') ? 
                             $self->type() : "Object", ++$hand->{AUTONAME}));
    }
}

sub parameter_methods {
    my $self = shift;
    my $args = $self->parseparams( @_ );
    while (my ($call, $val) = each %{$args}) {
        $call = lc($call);
        if (my $meth = $self->can($call)) {
            &{$meth}($self, $val);
        } else {
            $self->msg("[?]","Can not set '$call' on $self - unknown method");
        }
    }
}

*fullname = \&name;
sub name {
    my $self = shift;
    if (my $nv = shift) {
        $self->{NAME} = $nv;
    }
    return $self->{NAME};
}

sub dump {
    my $self = shift;
    return Data::Dumper->Dump([@_]);
}

sub results_object {
    my $self = shift;
    my $req  = shift;
    return undef unless ($req);
    if (my $r = ref($req)) {
        die $r;
    } else {
        return $self->handler->results($req);
    }
}


1;
