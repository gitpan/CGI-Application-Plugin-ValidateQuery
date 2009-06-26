package CGI::Application::Plugin::ValidateQuery;

use warnings;
use strict;

use base 'Exporter';

use Carp 'croak';
use Params::Validate ':all';

=head1 NAME

CGI::Application::Plugin::ValidateQuery - lightweight query validation for CGI::Application

=head1 VERSION

Version 0.99_4

=cut

our $VERSION = '0.99_4';

our @EXPORT_OK = qw(
    validate_query_config
    validate_query
    validate_query_error_mode
);
push @EXPORT_OK, @Params::Validate::EXPORT_OK;
our %EXPORT_TAGS = (all => \@EXPORT_OK);

local $Params::Validate::NO_VALIDATION = 0;

sub validate_query_config {
    my $self = shift;
    my @args = @_;

    my $opts = ref $args[0] eq 'HASH' ?
        $self->_cap_hash($args[0]) : $self->_cap_hash({@args});


    $self->{__CAP_VALQUERY_ERROR_MODE} = defined $opts->{ERROR_MODE} ?
        delete $opts->{ERROR_MODE} : 'validate_query_error_mode';

    # Potential problem with this code: given log_level isn't checked. Question:
    # Does this module /need/ to check user input that will end up being
    # checked (and croaked on) by a logging api, anyway?
    $self->{__CAP_VALQUERY_LOG_LEVEL} = defined $opts->{LOG_LEVEL} ?
        delete $opts->{LOG_LEVEL} : undef;

    croak 'log_level given but no logging interface exists.'
        if $self->{__CAP_VALQUERY_LOG_LEVEL} && !$self->can('log');

    croak 'Invalid option(s) ('.join(', ', keys %{$opts}).') passed to'
          .'validate_query_config' if %{$opts};

}

sub validate_query {
    my $self = shift;

    return unless @_;

    my @args = @_;

    my $query_props = ref $args[0] eq 'HASH' ? $args[0] : {@args};

    # Potential problem with this code: given log level isn't checked. Question:
    # Does this module /need/ to check user input that will end up being
    # checked (and probably croaked on) by a logging api, anyway?
    my $log_level = delete $query_props->{log_level}
                      || $self->{__CAP_VALQUERY_LOG_LEVEL};

    # what's left of $query_props should be something can pass to validate().
    # problem: users may only want to validate a small handful of GET
    # variables instead of the full query object (which potentially contains a
    # large numer of POST ariables already being validated by DFV or something
    # similar). 
    # Given, say, a post of {one=>'one',two=>'two'} and a get of
    # {three=>'three'} and a $query_props of just {three=>'three'} validation
    # will fail given the unknown keys in POST.
    # This makes sense; if someone is tampering with the query object you want
    # to catch any extra keys. 
    # option 1: for any key found in query not present in query_props, add to
    # query props and mark as optional.
    # option 2: just pass query_props and let it fail for any keys found in
    # query no in query_props.

    # Solution: pass ignore_rest_p to toggle behavior. If you know you are in
    # a situation where you need only test one or two things in query (because
    # the rest is delegated) you can toggle for situation one. Otherwise
    # toggle for situation two and validate the whole query object.
    my $ignore_rest_p = delete $query_props->{ignore_rest_p} || 0;

    my %validated;
    eval {
        my @vars_array;
        for my $p ($self->query->param) {
            my @values = $self->query->param($p);
            push @vars_array, ($p, scalar @values > 1 ? \@values : $values[0]);

            $query_props->{$p} = 0 if ($ignore_rest_p && !exists $query_props->{$p}); 
        }
        %validated = validate(@vars_array, $query_props);
    };
    if ($@) {
        my $log_msg = "Query Validation Failed: $@";
        if ( $log_level ) {
            $self->log->$log_level($log_msg);
        }
        $self->error_mode($self->{__CAP_VALQUERY_ERROR_MODE});

        croak $log_msg;
    }

    # account for default values.
    map { $self->query->param($_ => $validated{$_}) } keys %validated;
}

sub validate_query_error_mode {
    my $self  = shift;
    return "<html><head><title>Request not understood</title></head><body>The
            request submitted could not be understood.</body></html>";
}

1;

__END__

=head1 SYNOPSIS

 sub setup {
     my $self = shift;

     $self->validate_query_config(
            # define a page to show for invalid queries, or default to
            # serving a plain, internal page
            error_mode =>  'my_invalid_query_run_mode',
            log_level  => 'notice',
     );

 }

 sub my_run_mode {
    my $self = shift;

    # validate the query and return a standard error page on failure.
    $self->validate_query(
            pet_id    => SCALAR,
            direction => { type => SCALAR, default => 'up' },
    );

    # go on with life...

 }

=head1 DESCRIPTION

This plugin is for small query validation tasks. For example, perhaps
you link to a page where a "pet_id" is required, and you need to reality
check that this exists or return essentially a generic error message to
the user.

Even if your application generates the link, it may become altered
through tampering, malware, or other unanticipated events.

This plugin uses L<Params::Validate> to validate the query string.  You
can define your own error page to return on failure, or import a plain default
one that we supply.

You may also define a C<log_level>, if you do, we will also log each
validation failure at the chosen level like this:

 $self->log->$loglevel("Query validation failed: $@");

L<CGI::Application::Plugin::LogDispatch> is one plugin which implements
this logging API.

=head2 validate_query

    $self->validate_query(
                            pet_id => SCALAR,
                            type   => { type => SCALAR, default => 'food' },
                            log_level     => 'critical', # optional
                            ignore_rest_p => 1
     );

Validates C<< $self->query >> using L<Params::Validate>. If any required
query param is missing or invalid, the  run mode defined with C<<
validate_query_config >> will be used. If  you don't want to supply one, you
can import a plain error run mode--C<< validate_query_error_mode >>
that we provide. It will be returned by default. C<< validate_query_config >>
is usually called in C<< setup() >>, or a in a project super-class.

If C<log_level> is defined, it will override the the log level provided in
C<< validate_query_config >> and log a validation failure at that log
level.

If ignore_rest_p is defined and true, any parameter found in $self->query not
listed in the call to validate_query will be ignored by the check. If this is
your only validation, don't use this; this option is here for cases where,
say, a bunch of POST values are already being checked by something heavier
like L<Data::FormValidator> and you just want to check one or two GET values.

If you set a default, the query will be modified with the new value.


=head2 IMPLENTATION NOTES

We set "local $Params::Validate::NO_VALIDATION = 0;" to be sure that
Params::Validate works for us, even if is globally disabled.

To alter the application flow when validation fails, we set
'error_mode()' at the last minute, and then die, so the error mode is
triggered. Other uses of error_mode() should continue to work as normal.

This module is intended to be use for simple query validation tasks,
such as a link with  query string with a small number of arguments. For
larger validation tasks, especially for processing for submissions using
L< Data::FormValidator > is recommended, along with L<
CGI::Application::ValidateRM > if you using CGI::Application.

=head2 FUTURE

This concept could be extended to all check values set through
$self->param(), or through $ENV{PATH_INFO} .

This plugin does handle file upload validations, and won't in the
future.

Providing untainting is not a goal of this module, but if it's easy and
someone else provides a patch, perhaps support will be added. Params::Validate
provides untainting functionality and may be useful.

=head1 AUTHOR

Nate Smith C<< nate@summersault.com >>, Mark Stosberg C<< mark@summersault.com >>

=head1 BUGS & ISSUES

Please report any bugs or feature requests to
C<bug-cgi-application-plugin-validatequery at rt.cpan.org>, or through the web interface at
L<http://rt.cpan.org/NoAuth/ReportBug.html?Queue=CGI-Application-Plugin-ValidateQuery>.
I will be notified, and then you'll automatically be notified of progress on
your bug as I make changes.

=head1 COPYRIGHT & LICENSE

Copyright 2009 Summersault, LLC., all rights reserved.

This program is free software; you can redistribute it and/or modify it
under the same terms as Perl itself.

=cut
