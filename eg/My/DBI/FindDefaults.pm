package My::DBI::FindDefaults;

# $Id: FindDefaults.pm,v 2.0 2002/03/19 04:00:07 lachoy Exp $

use strict;
use SPOPS               qw( DEBUG _w );
use SPOPS::ClassFactory qw( ERROR OK NOTIFY );

sub behavior_factory {
    my ( $class ) = @_;
    DEBUG() && _w( 1, "Installing default discovery for ($class)" );
    return { manipulate_configuration => \&find_defaults };
}


sub find_defaults {
    my ( $class ) = @_;
    my $CONFIG = $class->CONFIG;
    return ( OK, undef ) unless ( $CONFIG->{find_default_id} and
                                  ref $CONFIG->{find_default_field} eq 'ARRAY' and
                                  scalar @{ $CONFIG->{find_default_field} } );
    my $dbh = $class->global_datasource_handle( $CONFIG->{datasource} );
    unless ( $dbh ) {
      return ( NOTIFY, "Cannot find defaults because no DBI database " .
                       "handle available to class ($class)" );
    }

    my $default_fields = join( ', ', @{ $CONFIG->{find_default_field} } );
    my $id_clause = $class->id_clause( $CONFIG->{find_default_id},
                                       '', { db => $dbh } );
    my $sql = qq/
         SELECT $default_fields
           FROM $CONFIG->{base_table}
          WHERE $id_clause /;
    my ( $sth );
    eval {
        $sth = $dbh->prepare( $sql );
        $sth->execute;
    };
    if ( $@ ) {
      return ( NOTIFY, "Cannot find defaults because SELECT failed to execute.\n" .
                       "SQL: $sql\nError: $@\nClass: $class" );
    }
    my $row = $sth->fetchrow_arrayref;

    unless ( ref $row eq 'ARRAY' and scalar @{ $row } ) {
        return ( NOTIFY, "No record found for ID $CONFIG->{find_default_id} in " .
                         "class ($class)" );
    }

    my $count = 0;
    foreach my $field ( @{ $CONFIG->{find_default_field} } ) {
        $CONFIG->{default_values}{ $field } = $row->[ $count ];
        $count++;
    }
    return ( OK, undef );
}

1;

__END__

=pod

=head1 NAME

My::DBI::FindDefaults - Load default values from a particular record

=head1 SYNOPSIS

 # Load information from record 4 for fields 'language' and 'country'

 my $spops = {
    class               => 'This::Class',
    isa                 => [ 'SPOPS::DBI' ],
    field               => [ 'email', 'language', 'country' ],
    id_field            => 'email',
    base_table          => 'test_table',
    rules_from          => [ 'My::DBI::FindDefaults' ],
    find_default_id     => 4,
    find_default_fields => [ 'language', 'country' ],
 };

=head1 DESCRIPTION

This class allows you to specify default values based on the
information in a particular record in the database. Just specify the
ID of the record and the fields which you want to copy as defaults.

=head1 METHODS

B<behavior_factory()>

Loads the behavior during the
L<SPOPS::ClassFactory|SPOPS::ClassFactory> process.

B<find_defaults()>

Retrieve the defaults from the database.

=head1 BUGS

None known.

=head1 TO DO

Nothing known.

=head1 SEE ALSO

L<SPOPS::ClassFactory|SPOPS::ClassFactory>

POOP Group mailing list thread:

  http://www.geocrawler.com/lists/3/SourceForge/3024/0/6867367/

=head1 COPYRIGHT

Copyright (c) 2001-2002 intes.net, inc.. All rights reserved.

This library is free software; you can redistribute it and/or modify
it under the same terms as Perl itself.

=head1 AUTHORS

Chris Winters <chris@cwinters.com>

=cut
