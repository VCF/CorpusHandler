package Regexp::CorpusHandler::Results;

use strict;
use Scalar::Util qw(weaken);
use base   qw(Regexp::CorpusHandler::CorpusCommon);
use parent qw(Regexp::CorpusHandler::Weighted
              Regexp::CorpusHandler::Prioritized);

use BMS::Utilities::Debug;
our $dbg = BMS::Utilities::Debug->new( -skipkey => [qw(HANDLER)] );

sub new {
    my $class = shift;
    my $self = {
        DEFW => 1,
        DEFD => "+",
    };
    bless $self, $class;
    weaken( $self->{HANDLER} = shift );
    $self->parameter_methods( @_ );
    $self->set_defaults();
    return $self;
}

sub type    { return "Results"; }
sub handler { return shift->{HANDLER}; }

*init = \&reset;
sub reset {
    my $self = shift;
    $self->{WORKING} = {
        KEYINFO => {},
    };
    $self->reset_working_priority();
}

sub _key_info {
    my $self = shift;
    my $key  = shift;
    return undef unless ($key);
    return $self->{WORKING}{KEYINFO}{uc($key)} ||= {
        key  => $key, # Original case of the key
        vals => [],   # Stack of assigned values
        dep  => {},   # Dependent keys
        # vals => {},
        # srcs => {},
    };
}

*set_value = \&set_key;
sub set_key {
    my $self = shift;
    my ($key, $val, $w, $d, $src, $cond) = @_;
    return 0 unless ($key);
    my $info = $self->_key_info( $key );
    $val = "" unless (defined $val);
    $d   = $self->default_delta() if (!defined $d);
    $w   = $self->default_weight() if (!defined $w);
    push @{$info->{vals}}, [ $val, $w, $d, $src || "", $cond ];
    # Since we have altered the values assigned to the key, clear
    # the precalculated value to force recalculation on next request
    delete $info->{calc};
    foreach my $depKey (keys %{$info->{dep}}) {
        # Also clear any pre-calculated values that _depend_on_ this key:
        my $dInfo = $self->_key_info( $depKey );
        delete $dInfo->{calc};
    }
}

sub each_key {
    my $self = shift;
    my @keys = ();
    if (my $wrk = $self->{WORKING}) {
        @keys = sort { uc($a) cmp uc($b) } 
        map { $_->{key} } values %{$wrk->{KEYINFO}};
    }
    return @keys;
}

*jointoken = \&join_token;
sub join_token {
    my $self = shift;
    if (my $key = shift) {
        $key = uc($key);
        if (defined $_[0]) {
            my $nv = $_[0];
            if (uc($nv) eq 'NOJOIN') {
                delete $self->{JOINTOKEN}{$key};
            } else {
                $self->{JOINTOKEN}{$key} = $nv;
            }
        }
        return $self->{JOINTOKEN}{$key};
    }
    return undef;
}

sub _normalize_case_mode {
    my $self = shift;
    my $mode = lc(shift || "");
    return "" unless ($mode);

    if ($mode =~ /wiki/) {
        return 'WikiWord';
    } elsif ($mode =~ /cam/) {
        return 'camelCase';
    } elsif ($mode =~ /(snake)/) {
        return 'Snake_case';
    } elsif ($mode =~ /(up|cap)/) {
        return 'UPPER CASE';
    } elsif ($mode =~ /(low)/) {
        return 'lower case';
    } elsif ($mode =~ /(nice|pretty|start)/) {
        return 'Start Case';
    } elsif ($mode =~ /(sent[ae]nce)/) {
        return 'Sentence case';
    }
    return undef;
}

our $caseHandlers = {
    "WikiWord" => sub {
        my $txt   = shift;
        $txt = "" if (!defined $txt);
        my @words = split(/\s+/, lc($txt));
        map { substr($_, 0, 1) = uc(substr($_, 0, 1)) } @words;
        return join('', @words);
    },
    'Sentence case' => sub {
        my $txt   = shift;
        $txt = "" if (!defined $txt);
        $txt = lc($txt);
        my $rv = "";
        while (length($txt)) {
            my $blk = $txt;
            $txt = "";
            if ($blk =~ /^(.+?[\.\!\?\;]+)(.*)/) {
                ($blk, $txt) = ($1, $2);
            }
            $blk =~ s/^\s+//;
            substr($blk, 0, 1) = uc(substr($blk, 0, 1));
            $rv .= "$blk ";
        }
        $rv =~ s/\s+$//;
        return $rv;
    },
    'Snake_case' => sub {
        my $txt   = shift;
        $txt = "" if (!defined $txt);
        my @words = split(/\s+/, lc($txt));
        substr($words[0], 0, 1) = uc(substr($words[0], 0, 1));
        return join('_', @words);
    },
    'Start Case' => sub {
        my $txt   = shift;
        $txt = "" if (!defined $txt);
        my @words = split(/\s+/, lc($txt));
        map { substr($_, 0, 1) = uc(substr($_, 0, 1)) } @words;
        return join(' ', @words);
    },
    'UPPER CASE' => sub {
        my $txt   = shift;
        $txt = "" if (!defined $txt);
        return uc($txt);
    },
    'camelCase' => sub {
        my $txt   = shift;
        $txt = "" if (!defined $txt);
        my @words = split(/\s+/, lc($txt));
        map { substr($words[$_], 0, 1) = uc(substr($words[$_], 0, 1)) } (1..$#words);
        return join('', @words);
    },
    'lower case' => sub {
        my $txt   = shift;
        $txt = "" if (!defined $txt);
        return lc($txt);
    },
    "" => sub { return shift; }
};

# https://en.wikipedia.org/wiki/Letter_case
*casemode = \&case_mode;
sub case_mode {
    my $self = shift;
    if (my $key = shift) {
        $key = uc($key);
        if (defined $_[0]) {
            my $mode = $self->_normalize_case_mode( $_[0] );
            if (!defined $mode) {
                $self->msg("[?]", "Unrecognized case mode '$_[0]'");
            } elsif (!$mode) {
                delete $self->{CASEMODE}{$key};
            } else {
                $self->{CASEMODE}{$key} = $mode;
            }
        }
        return $self->{CASEMODE}{$key} || "";
    }
    return "";
}

sub change_case {
    my $self = shift;
    my $txt  = shift;
    $txt = "" unless (defined $txt);
    my $mode = shift;
    return $txt unless ($mode);
    my $cb = $caseHandlers->{$mode} ||
        $caseHandlers->{$self->_normalize_case_mode( $mode )};
    unless ($cb) {
        $self->msg("[?]", "Unrecognized case mode '$mode'");
        return $txt;
    }
    return &{$cb}( $txt );
}

sub value {
    my $self = shift;
    my $key = shift;
    return wantarray ? () : "" unless ($key);
    my $info = $self->_key_info( $key );
    # If a pre-calculated value is available, use it
    return wantarray ? @{$info->{calc}} : $info->{calc}[0]
        if (defined $info->{calc});
    my @valBits = @{$info->{vals}};
    if ($#valBits == -1) {
        my $rv = $info->{calc} = [""];
        return wantarray ? @{$rv} : $rv->[0];
    }
    my %valH;
    foreach my $vdat (@valBits) {
        my ($val, $w, $d, $src, $cond) = @{$vdat};
        if ($cond) {
            # This is a conditional value. Only include it if the
            # condition passes
            $self->death("Need conditional value test, plus dependency check for conditional variables");
        }
        my $vd = $valH{uc($val)} ||= [ $val, 0, {} ];
        $vd->[2]{$src}++;
        if ($d eq '+') {
            $vd->[1] += $w;
        } elsif ($d eq '-') {
            $vd->[1] -= $w;
        } elsif ($d eq '*') {
            $vd->[1] *= $w;
        } elsif ($d eq '/') {
            if ($w) {
                $vd->[1] /= $w;
            } else {
                $vd->[1] = 999999;
                $self->msg("[!!]","Attempt to divide weight for key '$key' by zero","Weight set to 'large' value of $vd->[1]");
            }
        } else {
            $vd->[1] = $w;
        }
    }
    my (@vals, %srcs);
    foreach my $vd (sort { $b->[1] <=> $a->[1] } values %valH) { 
        # Do not keep values with weights <= zero
        last if ($vd->[1] <= 0);
        push @vals, $vd->[0];
        while (my ($src, $num) = each %{$vd->[2]}) {
            $srcs{$src} += $num;
        }
    }
    # If we have no values assigned, or none survived the weight filter
    # and any conditional tests, return an empty string:
    if ($#vals == -1) {
        my $rv = $info->{calc} = [""];
        return wantarray ? @{$rv} : $rv->[0];
    }
 
    # Trim the list down to the "best" value if no joiner is defined:
    my $joiner = $self->join_token( $key );
    # @vals = ($vals[0]) unless (wantarray || defined $joiner);
   
    for my $v (0..$#vals) {
        $vals[$v] = $self->expand_text( $vals[$v], $key );
    }
    # warn "value($key) = ".$dbg->branch({ valH => \%valH, vals => \@vals});
    
    $info->{calc} = $joiner ? [ join($joiner, @vals) ] : \@vals;
    return wantarray ? @{$info->{calc}} : $info->{calc}[0];
}

sub expand_text {
    my $self = shift;
    my $text = shift;
    return "" unless (defined $text);
    # Do not need to do anything if there are no variable tokens:
    return $text unless ($text =~ /\$\$/);
    
    # The text has at least one Key variable defined in it
    # Make sure we are not starting an endless loop ala:
    # $$Chicken = "$$Egg"
    # $$Egg = "$$Chicken"

    my $key  = $self->fully_qualified_key(shift);
    if (my $err = $self->_loop_check($key)) {
        $self->msg("[!!]","Failed to evaluate the value for '$key'",
                   $err,
                   "The rules you are using create an infinite loop");
        $text =~ s/\$\$/??/g;
        return $text;
    }

    my $hand = $self->handler();
    my $info = $self->_key_info( $key );
    
    # Now for each variable, extract the value and substitute
    while (my $resKey = $self->parse_resultAndKey( $text)) {
        my ($otherKey, $resName, $rep) = @{$resKey};
        my $res = $resName ? $hand->results($resName) : $self;
        my $val = $res->value($otherKey);
        $text =~ s/\Q$rep\E/$val/g;
        # Note that the expanded key is dependent on this one:
        $info->{dep}{uc($otherKey)} = 1;
    }

    my $loop = $hand->{LOOPCHECK};
    if ($loop->[0] eq $key) {
        # We have completed recursion
        delete $hand->{LOOPCHECK};
    } else {
        pop @{$loop};
    }
    return $text;
}

sub fully_qualified_key {
    my $self = shift;
    my $key  = shift;
    return "" unless ($key);
    my $rv = uc(join('::', $self->name(), $key));
    $rv = "{$rv}" if ($rv =~ /\s/);
    return '$$'.$rv;
}

sub _loop_check {
    my $self = shift;
    my $key = shift;
    return 0 unless ($key);
    my $hand = $self->handler();
    my @loop = @{$hand->{LOOPCHECK} ||= []};
    for my $l (0..$#loop) {
        if ($loop[$l] eq $key) {
            # Uh oh. We have just looped around to the key we are
            # trying to expand
            return join(" -> ", @loop, $key);
        }
    }
    push @{$hand->{LOOPCHECK} ||= []}, $key;
    return 0;
}

sub to_text {
    my $self = shift;
    my $pad  = shift || "";
    my $pad2 = "$pad  ";
    my $pad3 = "$pad    ";
    my $txt  = sprintf("%s[%2d] >>%s>>\n", $pad,
                       $self->priority(), $self->name());
    $txt .= sprintf("%sDefault weight: %s\n", $pad2, 
                    $self->default_delta_weight());
    my %jbits;
    while (my ($key, $jv) = each %{$self->{JOINTOKEN} || {}}) {
        push @{$jbits{$jv}}, $key if (defined $jv);
    }
    my @jToks = sort keys %jbits;
    unless ($#jToks == -1) {
        $txt .= sprintf("%sJoined keys:\n", $pad2);
        foreach my $jv (@jToks) {
            $txt .= sprintf("%s'%s' : %s\n", $pad3, $jv, sort @{$jbits{$jv}});
        }
    }

    my %cbits;
    while (my ($key, $cm) = each %{$self->{CASEMODE} || {}}) {
        push @{$cbits{$cm}}, $key if ($cm);
    }
    my @cModes = sort keys %cbits;
    unless ($#cModes == -1) {
        $txt .= sprintf("%sCase Modes:\n", $pad2);
        foreach my $cm (@cModes) {
            my @kv = map { $_ =~ /\s/ ? "\$\${$_}" : $_ } 
            map { $self->change_case($_, $cm) } sort @{$cbits{$cm}};
            $txt .= sprintf("%s'%s' : %s\n", $pad3, $cm, join(', ', @kv));
        }
    }
    
    my @keys = $self->each_key();
    if ($#keys == -1) {
        $txt .= $pad2 . "/No key-value pairs assigned/\n";
    } else {
        foreach my $key (@keys) {
            my $val = $self->value($key);
            $txt .= sprintf("%s%s='%s'\n", $pad2, $key, $val);
        }
    }
    return $txt;
}
