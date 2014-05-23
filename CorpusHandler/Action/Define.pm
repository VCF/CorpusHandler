package Regexp::CorpusHandler::Action::Define;

use strict;
use base qw(Regexp::CorpusHandler::Action::ResultsModifierI);

sub new {
    my $class = shift;
    my $self = $class->SUPER::new( @_ );
    $self->set_defaults();
    # Defined variables should run immediately:
    $self->run();
    return $self;
}

sub type { return "Define"; }

sub run_immediately { return 1; }

*tag = \&key;
sub key {
    my $self = shift;
    if (my $nv = shift) {
        $self->{KEY} = $nv;
    }
    return $self->{KEY};
}

sub full_key {
    my $self = shift;
    my $tname = $self->results();
    $tname = $tname ? $tname->name() : "-UNDEFINED-";
    my $key = $self->key();
    my $fn = join('::', $tname, $key || "-UNDEFINED-");
    # $fn = "\"$fn\"" if ($fn =~ /\s/);
    return $fn;
}

*val = \&value;
sub value {
    my $self = shift;
    if (defined $_[0]) {
        $self->{VAL} = $_[0];
    }
    return $self->{VAL};
}

sub to_one_line {
    my $self = shift;
    my $txt   = $self->SUPER::to_one_line();
    my $targ  = $self->results();
    my $tname = $targ ? $targ->fullname() : '-UNDEFINED-';
    my $val   = $self->value();
    $txt .= sprintf(" >>%s>> %s='%s' %d", $tname, $self->key() || '-?-',
                    defined $val ? $val : "", $self->delta_weight());
    return $txt;
}

*working_source = \&source;
sub source { return "N/A"; }

sub run {
    my $self = shift;
    my $res  = $self->working_results();
    my $key  = $self->working_key();
    return unless ($key && $res);
    return $res->set_key( $key, $self->value(), 
                          $self->weight(), $self->delta(), 
                          $self->condition());
}

1;
