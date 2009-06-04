
=head1 NAME

CGI::Application::Plugin::ValidateQuery - lightweight query validation for CGI::Application

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
can define your own error page to return on failure, or we'll supply a
plain default one internally. 

You may also define a C<log_level>, if you do, we will also log each
validation failure at the chosen level like this:

 $self->log->$loglevel("Query validation failed: $@");

L<CGI::Application::Plugin::LogDispatch> is one plugin which implements
this logging API.

=head2 validate_query 

    $self->validate_query(
                            pet_id => SCALAR,
                            type   => { type => SCALAR, default => 'food' },
                            log_level => 'critical', # optional
     );

Validates C<< $self->query >> using L<Params::Validate>. If any required
query param is missing or invalid, the  run mode defined with C<<
validate_query_config >> will be used, or a plain internal page will be
returned by default. C<< validate_query_config >> is usually called in
C<< setup() >>, or a in a project super-class.

If <log_level> is defined, it will override the the log file provided in
C<< validate_query_config >> and log a validation failure at that log
evel 

If you set a default, the query will be modified with the new value.

=cut

sub validate_query {

}

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
someone else provides a patch, perhaps support will be added. 

=head1 AUTHOR

Mark Stosberg C<< mark@summersault.com >>
