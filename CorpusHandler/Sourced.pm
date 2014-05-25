package Regexp::CorpusHandler::Sourced;

use strict;
use base qw( Regexp::CorpusHandler::CorpusCommon );

=head1 DESCRIPTION

This module defines methods use to access a "source" of text. It is
not designed to be used directly, but will instead be inherited by
other modules that need this functionality.

=head1 AUTHOR

Charles Tilford <podmail@biocode.fastmail.fm>

//Subject __must__ include 'Perl' to escape mail filters//

=head1 LICENSE

Copyright 2014 Charles Tilford

 http://mit-license.org/

Permission is hereby granted, free of charge, to any person obtaining
a copy of this software and associated documentation files (the
"Software"), to deal in the Software without restriction, including
without limitation the rights to use, copy, modify, merge, publish,
distribute, sublicense, and/or sell copies of the Software, and to
permit persons to whom the Software is furnished to do so, subject to
the following conditions:

The above copyright notice and this permission notice shall be
included in all copies or substantial portions of the Software.

  THE SOFTWARE IS PROVIDED 'AS IS', WITHOUT WARRANTY OF ANY KIND,
  EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF
  MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND
  NONINFRINGEMENT. IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT HOLDERS
  BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER IN AN
  ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM, OUT OF OR IN
  CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
  SOFTWARE.

=head2 source

 Title   : source
 Usage   : $obj->source( $someSourceOfText )
 Function: Defines the source of text for text manipulation methods
 Returns : The string '*' (one asterisk) for the default corpus text
           Otherwise an array ref of [ ResultSet, KeyName ] entries
 Args    : Either a specification for one or more ResultSet::Key, or
           an asterisk to use the CorpusHandler text

The default source will simply be the text returned by
Regexp::CorpusHandler::text(), and can be set with '*'. However, if
you wish to read text from a result set, you can specify one or more
keys. For syntax see Regexp::CorpusHandler::TokenParser::parse_resultAndKey()

=cut

sub source {
    my $self = shift;
    if (my $req = shift) {
        my $okSrc;
        if ($req =~ /^(\*|\$_)$/) {
            $okSrc = '*';
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

=head2 working_source

 Title   : working_source
 Usage   : my $txt = $obj->working_source();
 Function: Retrieves the actual source text once parsing has begun
 Returns : A string of text from the defined source
 Args    : None

The "working" methods are designed for use during run()
operations. The source() method defines the initial source. In many
cases, the working_source() will be identical to this. However, the
separate method is designed to allow dynamic changes during
processing, while maintaining the original specification from source()
unaltered.

=cut

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

1;
