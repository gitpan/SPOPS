package SPOPS::DBI::MySQL;

# $Id: MySQL.pm,v 1.11 2001/10/12 21:00:26 lachoy Exp $

use strict;
use SPOPS  qw( _w DEBUG );
use SPOPS::Key::DBI::HandleField;

@SPOPS::DBI::MySQL::ISA      = ();
$SPOPS::DBI::MySQL::VERSION  = '1.90';
$SPOPS::DBI::MySQL::Revision = substr(q$Revision: 1.11 $, 10);

sub sql_current_date  { return 'NOW()' }


# Backward compatibility (basically) -- you just have to set a true
# value in the config if you have an auto-increment field in the
# table. If so we call the post_fetch_id method from
# SPOPS::Key::DBI::HandleField.

sub post_fetch_id {
    my ( $item, @args ) = @_;
    return undef unless ( $item->CONFIG->{increment_field} );
    $item->CONFIG->{handle_field} ||= 'mysql_insertid';
    DEBUG() && _w( 1, "Setting to handle field: $item->CONFIG->{handle_field}" );
    return SPOPS::Key::DBI::HandleField::post_fetch_id( $item, @args );
}

1;

__END__

=pod

=head1 NAME

SPOPS::DBI::MySQL -- MySQL-specific code for DBI collections

=head1 SYNOPSIS

 myobject => {
   isa             => [ qw( SPOPS::DBI::MySQL SPOPS::DBI ) ],
   increment_field => 1,
 };

=head1 DESCRIPTION

This just implements some MySQL-specific routines so we can abstract
them out.

One of these items is to return the just-inserted ID. Only works for
tables that have at least one auto-increment field:

 CREATE TABLE my_table (
   id  int not null auto_increment,
   ...
 )

You must also specify a true value for the class configuration
variable 'increment_field' to be able to automatically retrieve
auto-increment field values.

=head1 BUGS

None known.

=head1 TO DO

Nothing known.

=head1 SEE ALSO

L<SPOPS::Key::HandleField|SPOPS::Key::HandleField>

L<DBD::mysql|DBD::mysql>

L<DBI|DBI>

=head1 COPYRIGHT

Copyright (c) 2001 intes.net, inc.. All rights reserved.

This library is free software; you can redistribute it and/or modify
it under the same terms as Perl itself.

=head1 AUTHORS

Chris Winters  <chris@cwinters.com>

=cut
