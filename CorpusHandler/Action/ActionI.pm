package Regexp::CorpusHandler::Action::ActionI;

use strict;
use Scalar::Util qw(weaken);
use base qw(Regexp::CorpusHandler::CorpusCommon);
use parent qw(Regexp::CorpusHandler::Prioritized);

sub new {
    my $class = shift;
    my $self = {
    };
    bless $self, $class;
    weaken( $self->{ACTIONSET} = shift );
    $self->parameter_methods( @_ );
    $self->set_defaults();
    return $self;
}

sub type      { return "Action"; }
sub action    { return shift; }
*set = \&actionset;
sub actionset { return shift->{ACTIONSET}; }
sub handler   { return shift->actionset()->handler(); }

sub name {
    my $self = shift;
    if (my $nv = shift) {
        if (my $old = $self->{NAME}) {
            if ($old ne $nv) {
                # We are changing the name
                $self->msg("[!]", "Action name change not currently supported");
                return $old;
            }
        } else {
            $self->{NAME} = $nv;
        }
    }
    return $self->{NAME} || "";
}

sub fullname {
    my $self = shift;
    return $self->actionset()->fullname().'::'.$self->name();
}

sub to_one_line {
    my $self = shift;
    my $txt  = sprintf("[%2d] \"%s\" {%s}", $self->priority(),
                       $self->name(), $self->type());
    return $txt;
}

sub reset {
    my $self = shift;
    $self->{WORKING} = {
    };
}
