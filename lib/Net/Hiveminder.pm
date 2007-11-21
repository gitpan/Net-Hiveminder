#!/usr/bin/env perl
package Net::Hiveminder;
use Moose;
extends 'Net::Jifty';

use Number::RecordLocator;
my $LOCATOR = Number::RecordLocator->new;

=head1 NAME

Net::Hiveminder - Perl interface to hiveminder.com

=head1 VERSION

Version 0.01 released 21 Nov 07

=cut

our $VERSION = '0.01';

=head1 SYNOPSIS

    use Net::Hiveminder;
    my $hm = Net::Hiveminder->new(use_config => 1);
    print $hm->todo;
    $hm->create_task("Boy these pretzels are making me thirsty [due tomorrow]");

=head1 DESCRIPTION

Hiveminder is a collaborate todo list organizer, built with L<Jifty>.

This module uses Hiveminder's REST API to let you manage your tasks any way you
want to.

This module is built on top of L<Net::Jifty>. Consult that module's
documentation for the lower-level interface.

=cut

has '+site' => (
    default => 'http://hiveminder.com'
);

has '+cookie_name' => (
    default => 'JIFTY_SID_HIVEMINDER',
);

has '+appname' => (
    default => 'BTDT',
);

has '+config_file' => (
    default => "$ENV{HOME}/.hiveminder",
);

=head2 display_tasks TASKS

This will take a list of hash references (tasks) and convert them to
human-readable form.

In scalar context it will return the tasks joined by newlines.

=cut

sub display_tasks {
    my $self = shift;
    my @out;

    my $now = DateTime->now;
    my %email_of;

    for my $task (@_) {
        my $locator = $LOCATOR->encode($task->{id});
        my $display = "#$locator: $task->{summary}";

        # don't display start date if it's <= today
        delete $task->{starts}
            if $task->{starts}
            && $self->load_date($task->{starts}) < $now;

        $display .= " [$task->{tags}]" if $task->{tags};
        for my $field (qw/due starts group/) {
            $display .= " [$field: $task->{$field}]"
                if $task->{$field};
        }

        my $helper = sub {
            my ($field, $name) = @_;

            my $id = $task->{$field}
                or return;

            # this wants to be //=. oh well
            my $email = $email_of{$id} ||= $self->email_of($id)
                or return;

            $self->is_me($email)
                and return;

            $display .= " [$name: $email]";
        };

        $helper->('requestor_id', 'for');
        $helper->('owner_id', 'by');

        push @out, $display;
    }

    return wantarray ? @out : join "\n", @out;
}

=head2 get_tasks ARGS

Runs a search (with ARGS) for tasks. There are no defaults here, so this can
be used for anything.

=cut

sub get_tasks {
    my $self = shift;
    return @{ $self->act('TaskSearch', @_)->{content}{tasks} };
}

=head2 todo_tasks [ARGS]

Returns a list of hash references, each one a task. This uses the same query
that the home page of Hiveminder uses.

=cut

sub todo_tasks {
    my $self = shift;

    $self->get_tasks(
        complete_not     => 1,
        accepted         => 1,
        owner            => 'me',
        starts_before    => 'tomorrow',
        depends_on_count => 0,

        # XXX: this is one place to improve the API

        @_
    );
}

=head2 todo [ARGS]

Returns a list of tasks in human-readable form. Additional arguments will be
included in the search.

In scalar context it will return the concatenation of the tasks.

=cut

sub todo {
    my $self = shift;

    $self->display_tasks( $self->todo_tasks(@_) );
}

=head2 create_task SUMMARY

Creates a new task with the given summary.

=cut

sub create_task {
    my $self    = shift;
    my $summary = shift;

    $self->create(Task => summary => $summary);
}

=head2 read_task Locator

Load a task with the given record locator.

=cut

sub read_task {
    my $self  = shift;
    my $loc   = shift;
    my $id    = $LOCATOR->decode($loc);

    return $self->read(Task => id => $id);
}

=head2 update_task Locator, Args

Takes a record locator and uses it to update that task with Args.

=cut

sub update_task {
    my $self = shift;
    my $loc  = shift;
    my $id   = $LOCATOR->decode($loc);

    return $self->update(Task => id => $id, @_);
}

=head2 delete_task Locator

Takes a record locator and uses it to delete that task.

=cut

sub delete_task {
    my $self = shift;
    my $loc  = shift;
    my $id   = $LOCATOR->decode($loc);

    return $self->delete(Task => id => $id);
}

=head2 braindump Text[, Tokens]

Braindumps the given text. You may also pass a string of tokens to give
defaults to each of the braindumped tasks.

=cut

sub braindump {
    my $self = shift;
    my $text = shift;
    my $tokens = shift || '';

    return $self->act('ParseTasksMagically', text => $text, tokens => $tokens)
                ->{message};
}

=head2 email_of id

Take a user ID and retrieve that user's email address.

=cut

# XXX: this should go into Net::Jifty

sub email_of {
    my $self = shift;
    my $id = shift;

    my $user = $self->read(User => id => $id);
    return $user->{email};
}

=head2 canonicalize_priority priority

Attempts to understand a variety of different priority formats and change it
to the standard 1-5. This will C<confess> if it doesn't understand the
priority.

=cut

my %priority_map = (
    lowest  => 1,
    low     => 2,
    normal  => 3,
    high    => 4,
    highest => 5,
    e       => 1,
    d       => 2,
    c       => 3,
    b       => 4,
    a       => 5,
    1       => 1,
    2       => 2,
    3       => 3,
    4       => 4,
    5       => 5,
);

sub canonicalize_priority {
    my $self = shift;
    my $priority = shift;

    return $priority_map{lc $priority}
        or confess "Unknown priority: '$priority'"
}

=head1 SEE ALSO

L<Jifty>, L<Net::Jifty>

=head1 AUTHOR

Shawn M Moore, C<< <sartak at gmail.com> >>

=head1 BUGS

Please report any bugs or feature requests to
C<bug-net-hiveminder at rt.cpan.org>, or through the web interface at
L<http://rt.cpan.org/NoAuth/ReportBug.html?Queue=Net-Hiveminder>.

=head1 COPYRIGHT & LICENSE

Copyright 2007 Best Practical Solutions.

This program is free software; you can redistribute it and/or modify it
under the same terms as Perl itself.

=cut

1;

