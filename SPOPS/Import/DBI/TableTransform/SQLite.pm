package SPOPS::Import::DBI::TableTransform::SQLite;

# $Id: SQLite.pm,v 3.1 2003/01/02 05:57:40 lachoy Exp $

use strict;
use base qw( SPOPS::Import::DBI::TableTransform );

$SPOPS::Import::DBI::TableTransform::SQLite::VERSION  = sprintf("%d.%02d", q$Revision: 3.1 $ =~ /(\d+)\.(\d+)/);

sub increment {
    my ( $self, $sql ) = @_;
    $$sql =~ s/%%INCREMENT%%/INTEGER NOT NULL/g;
}

sub increment_type {
    my ( $self, $sql ) = @_;
    $$sql =~ s/%%INCREMENT_TYPE%%/INTEGER/g;
}

1;

__END__

=head1 NAME

SPOPS::Import::DBI::TableTransform::SQLite - Table transformations for SQLite

=head1 SYNOPSIS

 my $table = qq/
   CREATE TABLE blah ( id %%INCREMENT%% primary key,
                       name varchar(50) )
 /;
 my $transformer = SPOPS::Import::DBI::TableTransform->new( 'sqlite' );
 $transformer->increment( \$table );
 print $table;

 # Output:
 # CREATE TABLE blah ( id INTEGER NOT NULL primary key,
 #                     name varchar(50) )

=head1 DESCRIPTION

SQLite-specific type conversions for the auto-increment field type.

=head1 METHODS

B<increment>

Returns 'INTEGER NOT NULL'

B<increment_type>

Returns 'INTEGER'

=head1 BUGS

None known.

=head1 TO DO

Nothing known.

=head1 SEE ALSO

L<SPOPS::Import::DBI::TableTransform|SPOPS::Import::DBI::TableTransform>

=head1 COPYRIGHT

Copyright (c) 2002 intes.net, inc.. All rights reserved.

This library is free software; you can redistribute it and/or modify
it under the same terms as Perl itself.

=head1 AUTHORS

Chris Winters E<lt>chris@cwinters.comE<gt>

