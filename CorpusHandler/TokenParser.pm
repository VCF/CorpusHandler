package Regexp::CorpusHandler::TokenParser;
use strict;



sub parse_resultAndKey {
    my $self = shift;
    my $text = shift;
    # Passing a second true value indicates loose parsing, where
    # the leading $$ is not required
    my $prfx = shift @_ ? '(?:\$\$)?' : '\$\$';
    return wantarray ? () : undef unless (defined $text);
    # $self->msg("[>]","'$text'");
    if ($text =~ /($prfx\{([^\}]+)\})/i        ||
        $text =~ /($prfx([A-Z0-9_]+\:\:[A-Z0-9_]+))/i ||
        $text =~ /($prfx([A-Z0-9_]+))/i)  {
        # Variable format
        # $$Key               # Key must be alphanumeric 
        # $$Results::Key      # Key and Results both alphanumeric
        # $${A Key}           # Key can be anything but { } :
        # $${A Result::A Key} # Either any but { } :

        my ($rep, $key) = ($1, $2);
        # Is there a Results name also defined?
        my $res = "";
        if ($key =~ /^([^:]+)::([^:]+)$/) {
            ($res, $key) = ($1, $2);
        }
        my @rv = ($key, $res, $rep);
        # $self->msg("[+]", "'$key', '$res', '$rep'");
        return wantarray ? @rv : \@rv;
    }
    return wantarray ? () : undef;
}


our $deltaRegExp = '(?:([\+\-\*\/])=?\s*)';

sub parse_weightAndDelta {
    my $self = shift;
    my $text = shift;
    return wantarray ? () : undef unless (defined $text);
    if ($text =~ /^$deltaRegExp?(\d+|\d*\.\d+)$/) {
        my @rv = ($2, $1 || "");
        return wantarray ? @rv : \@rv;
    }
    return wantarray ? () : undef;
}

sub parse_delta {
    my $self = shift;
    my $text = shift;
    return wantarray ? () : undef unless (defined $text);
    if ($text =~ /^$deltaRegExp?$/) {
        my @rv = ($1 || "");
        return wantarray ? @rv : \@rv;
    }
    return wantarray ? () : undef;
}
