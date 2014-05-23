package Regexp::CorpusHandler::Action::Extact;

use strict;
use base qw(Regexp::CorpusHandler::Action::ResultsModifierI);

sub type { return "Extract"; }

*key  = \&keys;
*tag  = \&keys;
*tags = \&keys;
sub keys {
    my $self = shift;
    if (my $nv = shift) {
        $self->{KEY} = $nv;
    }
    return $self->{KEY};
}

