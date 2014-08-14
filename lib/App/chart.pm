package App::chart;

# DATE
# VERSION

use 5.010;
use strict;
use warnings;

use Text::Graph;
use Text::Graph::DataSet; # bug in Text::Graph, doesn't load this

use Moo;
with 'SHARYANTO::Role::TermAttrs';

sub gen_chart {
    my ($self, %args) = @_;

    if ($args{output} ne 'text') {
        return [400, "Unknown output format, ".
                    "refer to documentation for available formats"];
    }
    unless ($args{type} =~ /\A(bar|line)\z/) {
        return [400, "Invalid graph type, ".
                    "refer to documentation for available formats"];
    }
    unless ($args{y_scale} =~ /\A(linear|log)\z/) {
        return [400, "Invalid y_scale, ".
                    "either set 'linear' or 'log'"];
    }

    # determine data form
    my $data = $args{data};
    my $form;
    {
        my $ref = ref($data);
        if (!$ref) {
            return [400, "Invalid data, must be array/hash"];
        } elsif ($ref eq 'HASH') {
            $form = 'hash';
            last;
        } elsif ($ref eq 'ARRAY') {
            if (!@$data || !ref($data->[0])) {
                $form = 'array';
                last;
            }
            my $r0ref = ref($data->[0]);
            if ($r0ref eq 'ARRAY') {
                $form = 'aoa';
            } elsif ($r0ref eq 'HASH') {
                $form = 'aoh';
            } else {
                return [400, "Unknown data structure form"];
            }
        }
    }

    my $w = $self->term_width;
    my $max_label_len = 20;
    my $max_bar_len = $w - $max_label_len - 3 - 12;
    $max_bar_len = 2 if $max_bar_len < 2;

    #say "D:w=$w, max_bar_len=$max_bar_len";
    #use Data::Dump; dd $self;

    my $graph = Text::Graph->new(
        $args{type} eq 'line' ? 'Line' : 'Bar',
        showval => 1,
        maxlen => $max_bar_len,
        (log => 1) x ($args{y_scale} eq 'log' ? 1:0),
    );

    # select fields

    my $res;
    my ($rows, $labels);
    if ($form eq 'hash') {
        $rows   = [];
        $labels = [];
        for (sort keys %$data) {
            push @$rows  , $data->{$_};
            push @$labels, $_;
        }
    } elsif ($form eq 'array') {
        $rows = $data;
    } else {
        no warnings 'uninitialized', 'numeric';

        if (!defined($args{data_field})) {
            return [400, "must select data field"];
        } else {
            my $f = $args{data_field};
            $rows = [map {$form eq 'aoh' ? $_->{$f} : $_->[$f]} @$data];
        }

        if (defined $args{label_field}) {
            my $f = $args{label_field};
            $labels = [map {$form eq 'aoh' ? $_->{$f} : $_->[$f]} @$data];
        }
    }

    # trim labels
    if ($labels) {
        for (@$labels) {
            next unless defined($_);
            $_ = substr($_, 0, $max_label_len) if length($_) > $max_label_len;
        }
    }

    # draw it!
    $res = $graph->to_string(
        $rows,
        (labels=>$labels) x (!!$labels),
    );

    [200, "OK", $res];
}

1;
# ABSTRACT: Create chart for your data structure

=for Pod::Coverage ^(gen_chart)$

=head1 SYNOPSIS

See the command-line script L<chart>.

=cut
