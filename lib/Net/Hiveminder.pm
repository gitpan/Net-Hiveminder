#!/usr/bin/env perl
package Net::Hiveminder;
use Moose;
extends 'Net::Jifty';

use Number::RecordLocator;
my $LOCATOR = Number::RecordLocator->new;

=head1 NAME

Net::Hiveminder - Perl interface to hiveminder.com

=head1 VERSION

Version 0.02 released 12 Jan 08

=cut

our $VERSION = '0.02';

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

This will take a list of hash references, C<TASKS>, and convert each to a
human-readable form.

In scalar context it will return the readable forms of these tasks joined by
newlines.

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

        $display .= " [priority: " . $self->priority($task->{priority}) . "]"
            if $task->{priority} != 3;

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

Runs a search with C<ARGS> for tasks. There are no defaults here, so this can
be used for anything.

Returns a list of hash references, each one being a task. Use C<display_tasks>
if necessary.

=cut

sub get_tasks {
    my $self = shift;
    return @{ $self->act('TaskSearch', @_)->{content}{tasks} };
}

=head2 todo_tasks [ARGS]

Returns a list of hash references, each one a task. This uses the same query
that the home page of Hiveminder uses. The optional C<ARGS> will be passed as
well so you can narrow down your todo list.

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

Returns a list of tasks in human-readable form. The optional C<ARGS> will be
passed as well so you can narrow down your todo list.

In scalar context it will return the concatenation of the tasks.

=cut

sub todo {
    my $self = shift;

    $self->display_tasks( $self->todo_tasks(@_) );
}

=head2 create_task SUMMARY

Creates a new task with C<SUMMARY>.

=cut

sub create_task {
    my $self    = shift;
    my $summary = shift;

    $self->create(Task => summary => $summary);
}

=head2 read_task LOCATOR

Load task C<LOCATOR>.

=cut

sub read_task {
    my $self  = shift;
    my $loc   = shift;
    my $id    = $self->tasks2ids($loc);

    return $self->read(Task => id => $id);
}

=head2 update_task LOCATOR, ARGS

Update task C<LOCATOR> with C<ARGS>.

=cut

sub update_task {
    my $self = shift;
    my $loc  = shift;
    my $id   = $self->tasks2ids($loc);

    return $self->update(Task => id => $id, @_);
}

=head2 delete_task LOCATOR

Delete task C<LOCATOR>.

=cut

sub delete_task {
    my $self = shift;
    my $loc  = shift;
    my $id   = $self->tasks2ids($loc);

    return $self->delete(Task => id => $id);
}

=head2 braindump TEXT[, TOKENS]

Braindumps C<TEXT>. C<TOKENS> may be used to provide default attributes to all
the braindumped tasks (this is part of what the filter feature of Hiveminder's
IM bot does).

=cut

sub braindump {
    my $self = shift;
    my $text = shift;
    my $tokens = shift || '';

    return $self->act('ParseTasksMagically', text => $text, tokens => $tokens)
                ->{message};
}

=head2 upload_text TEXT

Uploads C<TEXT> to BTDT::Action::UploadTasks.

=cut

sub upload_text {
    my $self = shift;
    my $text = shift;

    return $self->act(UploadTasks => content => $text, format => 'sync')
                ->{message};
}

=head2 upload_file FILENAME

Uploads C<FILENAME> to BTDT::Action::UploadTasks.

=cut

sub upload_file {
    my $self = shift;
    my $file = shift;

    my $text = do { local (@ARGV, $/) = $file; <> };

    return $self->upload_text($text);
}

=head2 download_text

Downloads your tasks. This also gets the metadata so that you can edit the text
and upload it, and it'll make the same changes to your task list.

This does not currently accept query arguments, because Hiveminder expects a
"/not/owner/me/group/personal" type argument string, when all we can produce is
"owner_not => 'me', group => 'personal'"

=cut

sub download_text {
    my $self = shift;
    my $query = shift;

    return $self->act(DownloadTasks => query => $query, format => 'sync')->{content}{result};
}

=head2 download_file FILENAME

Downloads your tasks and puts them into C<FILENAME>.

This does not currently accept query arguments, because Hiveminder expects a
"/not/owner/me/group/personal" type argument string, when all we can produce is
"owner_not => 'me', group => 'personal'"

=cut

sub download_file {
    my $self = shift;
    my $file = shift;

    my $text = $self->download_text(@_);
    open my $handle, '>', $file
        or confess "Unable to open $file for writing: $!";
    print $handle $text;
    close $handle;
}

=head2 priority (NUMBER | TASK) -> Maybe String

Returns the "word" of a priority. One of: lowest, low, normal, high, highest.
If the priority is out of range, C<undef> will be returned.

=cut

my @priorities = (undef, qw/lowest low normal high highest/);
sub priority {
    my $self = shift;
    my $priority = shift;

    # if they pass in a task, DTRT :)
    $priority = $priority->{priority}
        if ref($priority) eq 'HASH';

    return $priorities[$priority];
}

=head2 done LOCATORS

Marks the given tasks as complete.

=cut

sub done {
    my $self = shift;

    for (@_) {
        my $id = $self->tasks2ids($_);
        $self->update('Task', id => $id, complete => 1);
    }
}

=head2 tasks2ids LOCATORS -> IDS

Transforms the given record locators (or tasks) to regular IDs.

=cut

sub tasks2ids {
    my $self = shift;

    my @ids = map {
        my $locator = $_;
        $locator =~ s/^#+//; # remove leading #
        $LOCATOR->decode($locator);
    } @_;

    return wantarray ? @ids : $ids[0];
}

=head1 SEE ALSO

L<Jifty>, L<Net::Jifty>

=head1 AUTHOR

Shawn M Moore, C<< <sartak at bestpractical.com> >>

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

