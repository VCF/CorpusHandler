package Regexp::CorpusHandler::ActionSet;

use strict;
use Scalar::Util qw(weaken);
use base   qw(Regexp::CorpusHandler::CorpusCommon);
use parent qw(Regexp::CorpusHandler::Weighted
              Regexp::CorpusHandler::Prioritized);

sub new {
    my $class = shift;
    my $self = {
    };
    bless $self, $class;
    weaken( $self->{HANDLER} = shift );
    $self->parameter_methods( @_ );
    $self->set_defaults();
    return $self;
}

sub type      { return "ActionSet"; }
*set = \&actionset;
sub actionset { return shift; }
sub handler   { return shift->{HANDLER}; }

*init = \&reset;
sub reset {
    my $self = shift;
    $self->reset_working_priority();
    my @acts = $self->each_action();
    my $wrk  = $self->{WORKING} ||= {};
    $wrk->{STACK} = \@acts;
    map { $_->reset() } @acts;
}

sub next_action {
    my $self = shift;
    my $stack = $self->{WORKING}{STACK};
    return $stack ? shift @{$stack} : undef;
}

sub add_action {
    my $self = shift;
    my $args = $self->parseparams( @_ );
    my $actName = $args->{ACTION};
    unless ($actName) {
        $self->err("Can not add action",
                   "Must pass action name with -action");
        return undef;
    }
    unless ($actName =~ /^[A-Z]+$/i) {
        $self->err("Can not add action '$actName'",
                   "Action name must only be letters (A-Z)");
        return undef;
    }
    my $pkg = "Regexp::CorpusHandler::Action::$actName";
    if (!$self->{LOADED}{$actName}) {
        eval "require $pkg";
        if (my $err = $@) {
            my @bits = split(/\s*[\n\r]+\s*/, $err);
            my @msg;
            foreach my $line (@bits) {
                if ($line =~ /(.+?)\/.+\/(CorpusHandler\/.*\.pm line.+)/) {
                    # Just shorten up a bit
                    push @msg, "$1 $2";
                } elsif ($line =~ /^Compilation failed/) {
                    last;
                } else {
                    push @msg, $line;
                }
            }
            $self->msg("[!!]","Programming error", "The module '$actName' has errors", @msg);
            $self->{LOADED}{$actName} = -1;
        } else {
            $self->{LOADED}{$actName} = 1;
        }
    } elsif ($self->{LOADED}{$actName} < 0) {
        $self->msg("[!]", "Skipping request for mis-programmed action '$actName'");
        next;
    }

    unless ($pkg->can('new')) {
        $self->msg("[!]","Can not add action - unrecognized package '$pkg'");
        return undef;
    }

    my $defWgt = $self->default_delta_weight();
    my $action = $pkg->new($self, -weight => $defWgt, %{$args} );
    my $rn     = $action->name();
    if ($self->{ACTIONS}{$rn}) {
        $self->err("Can not add Action:", $action->to_one_line(),
                   "A action already exists with that name in this set");
        return undef;
    }
    my @prior = ();
    $self->{ACTIONS}{$rn} = $action;
    unless ($action->priority()) {
        $action->priority( $#prior == -1 ? 1 : $prior[-1]->priority() + 1);
    }
}

sub each_action {
    my $self = shift;
    my @actions = sort { 
        $a->priority() <=> $b->priority() 
    } values %{$self->{ACTIONS}};
    return @actions;
}

sub has_action {
    my $self = shift;
    my $req  = shift;
    if (ref($req)) {
        $self->death("Need to handle has_action( \$object )");
        # $req = deconvolute
    }
    if (exists $self->{ACTIONS}{uc($req)} &&
        $self->{ACTIONS}{uc($req)}) {
        return $self->{ACTIONS}{uc($req)};
    }
    return 0;
}

sub to_text {
    my $self = shift;
    my $pad  = shift || "";
    my $txt  = sprintf("%s[%2d] \"%s\"::\n", $pad, $self->priority(), $self->name());
    my @acts = $self->each_action();
    if ($#acts == -1) {
        $txt .= $pad . "  " . "/No actions defined yet/\n";
    } else {
        foreach my $action (@acts) {
            $txt .= $pad . "  ". $action->to_one_line( )."\n";
        }
    }
    return $txt;
}


1;
