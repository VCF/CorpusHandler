package Regexp::CorpusHandler;

use strict;
use Regexp::CorpusHandler::ActionSet;
use Regexp::CorpusHandler::Results;
use base qw( BMS::Utilities );
use parent qw(Regexp::CorpusHandler::TokenParser);

sub new {
    my $class = shift;
    my $self = {
        ACTIONSET => {},
        DEFAULT_ACTIONSET => "DefaultActionSet",
        DEFAULT_RESULTS   => "DefaultResults",
    };
    bless $self, $class;
    return $self;
}

*action_set = \&actionset;
sub actionset {
    my $self = shift;
    my $name = shift;
    if (ref($name)) {
        # This is actually an object already
        # Should sanity check here!!
        $name = $name->name();
    } elsif (!$name) {
        $name = $self->current_actionset_name();
    }
    # $self->err("[DEBUG]", "ActionSet request for '$name'");
    return $self->{ACTIONSET}{uc($name)} ||= 
        Regexp::CorpusHandler::ActionSet->new( $self, -name => $name );
}

sub each_actionset {
    my $self = shift;
    return sort { $a->priority() 
                      <=> $b->priority() } values %{$self->{ACTIONSET}};
}

sub results {
    my $self = shift;
    my $name = shift;
    if (ref($name)) {
        # This is actually an object already
        # Should sanity check here!!
        $name = $name->name();
    } elsif (!$name) {
        $name = $self->current_results_name();
    }
    return $self->{RESULTS}{uc($name)} ||= 
        Regexp::CorpusHandler::Results->new( $self, -name => $name );
}

sub default_results {
    my $self = shift;
    return $self->results( $self->default_results_name() );
}

sub default_results_name {
    my $self = shift;
    if (my $nv = shift) {
        $self->{PARSE}{DEFAULT_RESULTS} = $nv;
    }
    return $self->{PARSE}{DEFAULT_RESULTS} || $self->{DEFAULT_RESULTS};
}

sub current_results_name {
    my $self = shift;
    if (my $nv = shift) {
        $self->{PARSE}{RESULTS} = $nv;
    }
    return $self->{PARSE}{RESULTS} || $self->default_results_name();
}

sub current_results {
    my $self = shift;
    return $self->results( $self->current_results_name( shift ) );
}

sub value {
    my $self = shift;
    my $req = shift;
    return "" unless ($req);
    my ($key, $rs) = ($req);
    if ($req =~ /::/) {
        if (my $rk = $self->parse_resultAndKey( $req, 'loose' )) {
            ($key, $rs) = @{$rk};
            $rs = $self->results($rs);
        } else {
            $self->msg("[?]", "Failed to interpret value request for '$req'");
            return "";
        }
    } else {
        $rs = $self->default_results();
    }
    return $rs->value($key);
}

sub default_actionset_name {
    my $self = shift;
    if (my $nv = shift) {
        $self->{PARSE}{DEFAULT_ACTIONSET} = $nv;
    }
    return $self->{PARSE}{DEFAULT_ACTIONSET} || $self->{DEFAULT_ACTIONSET};
}

sub current_actionset_name {
    my $self = shift;
    if (my $nv = shift) {
        $self->{PARSE}{ACTIONSET} = $nv;
    }
    return $self->{PARSE}{ACTIONSET} || $self->default_actionset_name();
}

sub current_actionset {
    my $self = shift;
    return $self->actionset( $self->current_actionset_name( shift ) );
}

*each_result = \&each_results;
sub each_results {
    my $self = shift;
    return sort { $a->priority() 
                      <=> $b->priority() } values %{$self->{RESULTS}};
}

*init = \&reset;
sub reset {
    my $self = shift;
    $self->{TEXT} = [];
    my @acts = $self->each_actionset();
    my @ress = $self->each_result();
    map { $_->reset() } @ress;
    map { $_->working_priority( $_->priority() ) } @acts;
    map { $_->reset() } @acts;
    my $rv = $self->{WORKING} = {
        SETS => \@acts,
    };
    # Should not need to do this... for now...
    $self->reorder_actionsets();
    return $rv;
}

sub reorder_actionsets {
    my $self = shift;
    my $wrk = $self->{WORKING}{SETS};
    $self->{WORKING}{SETS} = [ sort { 
        $a->working_priority() <=> $b->working_priority()
                               } @{$wrk} ] if ($wrk);
    # Return the prior order of ActionSets:
    return $wrk;
}

sub run {
    my $self = shift;
    my $sets = $self->{WORKING}{SETS};
    while (my $as = $sets->[0]) {
        if (my $act = $as->next_action()) {
            $act->run();
        } else {
            # All the actions in this set have run
            # Remove the ActionSet from the stack
            shift @{$sets};
        }
    }
}

sub text {
    my $self = shift;
    foreach my $nv (@_) {
        next unless (defined $nv);
        push @{$self->{TEXT}}, $nv;
    }
    return wantarray ? @{$self->{TEXT}} : join("\n", @{$self->{TEXT}});
}

sub clear_text {
    my $self = shift;
    $self->{TEXT} = [];
}

sub parse_target {
    my $self = shift;
    my $req  = shift;
    my $typ  = lc(shift || "");
    if ($typ) {
        if ($typ =~ /res/) {
            return $self->results($req);
        } elsif ($typ =~ /set/) {
            return $self->actionset($req);
        } else {
            $self->msg("[?]","Target reqest '$req' for unrecognized type '$typ'");
        }
    }
    if (my $r = ref($req)) {
        # Need better reference checking here
        return $req;
    } elsif ($req =~ /^(\S.*)::(\S.*)$/) {
        # ActionSet + Action
        my ($asName, $aName) = ($1, $2);
        my $as = $self->actionset($asName);
        if (my $act = $as->has_action( $aName )) {
            return $act;
        } else {
            $self->msg("[?]","Failed to find Action '$req'");
        }
    } else {
        # Treat as a ActionSet
        return $self->actionset($req);
    }
    return undef;
}

sub delete_actionset {
    my $self = shift;
    my $name = shift;
    $name = $name->name() if (ref($name));
    my $rv = $self->{ACTIONSET}{$name};
    delete $self->{ACTIONSET}{$name};
    return $rv;
}

sub add_actions_from_file {
    my $self = shift;
    my $args = $self->parseparams( @_ );
    my $file = $args->{FILE};
    if (!$file) {
        $self->err("[!]","add_actions_from_file() needs a -file parameter");
        return;
    } elsif (!-e $file) {
        $self->err("[!]","Failed to read actions file",
                   $file, "File not found");
        return;
    } elsif (!-s $file) {
        $self->err("[!]","Failed to read actions file", $file, "File empty");
        return;
    }
    unless (open(RSFILE, "<$file")) {
        $self->err("[!]","Failed to read actions file", $file, $!);
        return;
    }
    
    $self->{PARSE} = {};

    my $lookAhead = "";
    while (my $line = $lookAhead || <RSFILE>) {
        if ($line =~ /^\s*#/) {
            # Comment line, skip
            next;
        }
        $line =~ s/[\n\r\s]+$//;
        if ($line =~ /^\s*$/) {
            # Blank line, skip
            next;
        }
        unless ($line =~ /^[A-Z]+/) {
            # We really should start with a directive here
            # Warn the user that there is a problem
            $args->msg("[!]", "Unexpected line while parsing actions file",
                       "# $. = '$line'", $file,
                       "Expected a directive at this point");
            next;
            
        }

        # read any other lines that follow, stopping if we reach the end
        # of the file or another directive
        while ($lookAhead = <RSFILE>) {
            # If we found another directive, we will wait to use it later
            last if ($lookAhead =~ /^[A-Z]+/);
            $lookAhead =~ s/[\n\r\s]+$//;
            next if ($lookAhead =~ /^\s*#/ ||
                     $lookAhead =~ /^\s*$/);

            unless ($lookAhead =~ /^\s+/) {
                $self->msg("[!]", "Unexpected line while parsing actions file",
                       "# $. = '$lookAhead'", $file,
                       "Expected either a directive or continuation of the prior directive");
                $lookAhead = "";
                last;
            }
            $line .= $lookAhead;
        }

        $self->{_NOWLINE} = $line;
        my $cmd;
        if ($line =~ /^([A-Z]+)$/ || 
            $line =~ /^([A-Z]+)\s+(.*?)$/) {
            ($cmd, $line) = ($1, $2);
        } else {
            $self->_parse_err("[!!]", "Programming Error!!",
                              "Failed to parse actions line");
            next;
        }
        if ($cmd eq 'ACTIONSET') {
            # Defining the current ActionSet
            # Actions will be added to this set
            my ($xtra, $params) = $self->_parse_standard_bits( $line );
            my $name = $params->{name};
            my $as = $self->current_actionset( $name );
            if ($params->{isdefault}) {
                $self->default_actionset_name( $name );
                delete $params->{isdefault};
            }
            $as->parameter_methods( %{$params} );
            $self->_parse_err("Leftover, unparsed text '$xtra'")
                unless ($xtra eq '');
        } elsif ($cmd eq 'RESULTS') {
            # Defining the current Results
            # Any following commands that utilize a Results object but do
            # not explicitly define one will use the most recently specified
            my ($xtra, $params) = $self->_parse_standard_bits( $line );
            my $name = $params->{name};
            if ($params->{isdefault}) {
                $self->default_results_name( $name );
                delete $params->{isdefault};
            }
            my $rs = $self->current_results( $name );
            $rs->parameter_methods( %{$params} );
            $self->_parse_err("Leftover, unparsed text '$xtra'")
                unless ($xtra eq '');
        } elsif ($cmd eq 'ACTION') {
            my ($xtra, $params) = $self->_parse_standard_bits( $line );
            my $actSet = $self->current_actionset();
            $self->_set_action_defaults( $params );
            $actSet->add_action( %{$params} );
            $self->_parse_err("Leftover, unparsed text '$xtra'")
                unless ($xtra eq '');
        } elsif ($cmd =~ /^(JOIN|JOINER)$/) {
            my ($xtra, $params) = $self->_parse_standard_bits( $line );
            my @err;
            my $tok  = $params->{token};
            push @err, "-token is not defined" unless (defined $tok);
            my ($rks, $rlo) = 
                $self->_parse_result_key( $params->{key}, 'loose');
            if ($#{$rks} == -1) {
                push @err, "-key is not defined";
            } elsif (defined $tok) {
                foreach my $rk (@{$rks}) {
                    my ($res, $key) = @{$rk};
                    $res->join_token($key, $tok);
                }
                push @err, "Extra, unparsed text in -key : '$rlo'" if ($rlo);
            }
            push @err, "Leftover, unparsed text '$xtra'" unless ($xtra eq '');
            $self->_parse_err("Issues parsing $cmd line", @err)
                unless ($#err == -1);
        } elsif ($cmd =~ /^(CASE|CASEMODE)$/) {
            my ($xtra, $params) = $self->_parse_standard_bits( $line );
            my @err;
            my $mode  = $params->{mode};
            push @err, "-mode is not defined" unless (defined $mode);
            my ($rks, $rlo) = 
                $self->_parse_result_key( $params->{key}, 'loose');
            if ($#{$rks} == -1) {
                push @err, "-key is not defined";
            } elsif (defined $mode) {
                foreach my $rk (@{$rks}) {
                    my ($res, $key) = @{$rk};
                    $res->case_mode($key, $mode);
                }
                push @err, "Extra, unparsed text in -key : '$rlo'" if ($rlo);
            }
            push @err, "Leftover, unparsed text '$xtra'" unless ($xtra eq '');
            $self->_parse_err("Issues parsing $cmd line", @err)
                unless ($#err == -1);
        } else {
            $self->_parse_err("Unrecognized command '$cmd'" );
        }
    }
    close RSFILE;
}

sub _parse_err {
    my $self = shift;
    my @msg  = @_;
    return if ($#msg == -1);
    unshift @msg, "[?]" unless ($_[0] =~ /^\[/);
    $self->msg(@msg, "#$. = '$self->{_NOWLINE}'");
}

sub to_text {
    my $self = shift;
    my $txt = "";
    my $pad = shift || "";
    my @sets = $self->each_actionset();
    my $snum = $#sets + 1;
    if ($snum) {
        my $head =  sprintf("%s%d ActionSet%s:", $pad,
                            $snum, $snum == 1 ? '' : 's');
        $txt .= $head ."\n" .("-" x length($head))."\n";
        foreach my $rs (@sets) {
            $txt .= $rs->to_text($pad . "  ");
        }
    } else {
        $txt .= "/No ActionSets defined/\n";
    }
    my @ress = $self->each_results();

    my $rNum = $#ress + 1;
    if ($rNum) {
        my $head = sprintf("%s%d Results Container%s:", $pad,
                        $rNum, $rNum == 1 ? '' : 's');
        $txt .= $head ."\n" .("-" x length($head))."\n";
        foreach my $rs (@ress) {
            $txt .= $rs->to_text($pad . "  ");
        }
    } else {
        $txt .= "/No Results defined/\n";
    }
    

    return $txt;
}

our $peToken  = "ParseEsc";
our $peFormat = $peToken.'[%d]';

sub _esc_text {
    my $self = shift;
    my $text = shift;
    $text    = "" unless (defined $text);
    my $escTokens;
    while ($text =~ /(\\.)/) {
        my $rep = $1;
        push @{$escTokens ||= []}, $rep;
        my $tok = sprintf($peFormat, $#{$escTokens});
        $text =~ s/\Q$rep\E/$tok/g;
    }
    return ($text, $escTokens);
}

sub _unesc_text {
    my $self = shift;
    my ($text, $escTokens) = @_;
    $text    = "" unless (defined $text);
    return $text unless ($escTokens);
    for my $et (0..$#{$escTokens}) {
        my $tok = sprintf($peFormat, $et);
        my $rep = $escTokens->[$et];
        $text =~ s/\Q$tok\E/$rep/g;
    }
    return $text;
}

sub _parse_standard_bits {
    my $self = shift;
    my ($line, $escTokens) = $self->_esc_text( shift );
    my %rv;
    # Parse out the arguments in a line
    while ($line =~ /(\s*\-?([a-z_]+)=\"([^\"]*)\"\s*)$/ ||
           $line =~ /(\s*\-?([a-z_]+)=\'([^\']*)\'\s*)$/ ||
           $line =~ /(\s*\-?([a-z_]+)=(\S+)\s*)$/) {
        my ($rep, $k, $v) = ($1, lc($2), $self->_unesc_text($3, $escTokens));
        $line =~ s/\Q$rep\E$//;
        $rv{$k} = $v;
    }
    my $leftOver = $self->_unesc_text($line, $escTokens);
    $leftOver =~ s/^\s+//; $leftOver =~ s/\s+$//;
    return ($leftOver, \%rv);
}

sub _parse_result_key {
    my $self = shift;
    my $txt = shift;
    my $isLoose = shift;
    my @rv;
    if ($txt) {
        while (my $resKey = $self->parse_resultAndKey( $txt, $isLoose )) {
            my ($key, $rName, $rep) = @{$resKey};
            my $res = $rName ? $self->results($rName) : $self->current_results();
            push @rv, [$res, $key];
            $txt =~ s/\Q$rep\E/ /g;
        }
    }
    $txt =~ s/^\s+//; $txt =~ s/\s+$//;
    return (\@rv, $txt);
}

sub _set_action_defaults {
    my $self = shift;
    my $params = shift;
    my $action = $params->{action} || "";
    $params->{results} ||= $self->current_results_name();
    if ($action eq 'ChangePriority') {
        # If the target is not specified, use the current one.
        $params->{target} ||= $self->current_actionset_name();
    }
}

1;
