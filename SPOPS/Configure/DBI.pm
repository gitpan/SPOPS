package SPOPS::Configure::DBI;

# $Id: DBI.pm,v 1.8 2001/06/06 06:15:54 lachoy Exp $

use strict;
use SPOPS qw( _w DEBUG );
use SPOPS::Configure;

@SPOPS::Configure::DBI::ISA      = qw( SPOPS::Configure );
$SPOPS::Configure::DBI::VERSION  = '1.7';
$SPOPS::Configure::DBI::Revision = substr(q$Revision: 1.8 $, 10);

# 
# EVAL'D SUBROUTINES
#
# This is the routine we'll be putting in the namespace of all the
# classes that have asked to be linked to other classes; obviously,
# the items marked like this: %%KEY%% will be replaced before the eval
# is done.

my $generic_linksto = <<'LINKSTO';

    sub %%CLASS%%::%%LINKSTO_ALIAS%% {
      my ($self, $p ) = @_;
      $p->{select} = [ '%%LINKSTO_ID_FIELD%%' ];
      $p->{from}   = [ '%%LINKSTO_TABLE%%' ];
      my $id_clause = $self->id_clause( $self->id, 'noqualify', $p );
      $p->{where}  = ( $p->{where} ) 
                      ? join ( ' AND ', $p->{where}, $id_clause ) : $id_clause;
      $p->{return} = 'list';
      my $rows = eval { %%CLASS%%->db_select( $p ) };
      if ( $@ ) {
        $SPOPS::Error::user_msg = 'Cannot retrieve %%LINKSTO_ALIAS%% object(s)';
        warn "$SPOPS::Error::user_msg -- $@";
        die $SPOPS::Error::user_msg;
      }
      my @obj = ();
      foreach my $info ( @{ $rows } ) {
        my $item = eval { %%LINKSTO_CLASS%%->fetch( $info->[0], $p ) };
        if ( $@ ) {
          warn " --Cannot fetch linked object %%LINKSTO_ALIAS%% => $SPOPS::Error::system_msg ($@)\n";
        }
        push @obj, $item if ( $item );
      }
      return \@obj;
    }
     
    sub %%CLASS%%::%%LINKSTO_ALIAS%%_add {
      my ( $self, $link_id_list, $p ) = @_;

      # Allow user to pass only one ID to add (scalar) or an arrayref (ref)
      $link_id_list = ( ref $link_id_list ) ? $link_id_list : [ $link_id_list ];
      my $added = 0;
      my @error_list = (); 
      foreach my $link_id ( @{ $link_id_list } ) {
        SPOPS::_wm( 1, $p->{DEBUG}, "Trying to add link to ID ($link_id)" );
        eval { %%CLASS%%->db_insert({ table => '%%LINKSTO_TABLE%%',
                                      field => [ '%%ID_FIELD%%', '%%LINKSTO_ID_FIELD%%' ],
                                      value => [ $self->{%%ID_FIELD%%}, $link_id ],
                                      db    => $p->{db},
                                      DEBUG => $p->{DEBUG} }) };
        if ( $@ ) { 
          my $count = scalar @error_list + 1;
          my $value_list = ( ref $SPOPS::Error::extra->{value} ) 
                             ? join( ' // ', @{ $SPOPS::Error::extra->{value} } )
                             : 'none reported';
          my $error_msg = "Error $count\n$@\n$SPOPS::Error::system_msg\n" .
                          "SQL: $SPOPS::Error::extra->{sql}\nValues: $value_list";
          push @error_list, $error_msg; 
        } 
        else { 
          $added++;
        }
      }
      if ( scalar @error_list ) {
        $SPOPS::Error::system_msg = join "\n\n", @error_list;
        die 'Add %%LINKSTO_ALIAS%% failed for one or more items';
      }
      return $added;
    }
     
    sub %%CLASS%%::%%LINKSTO_ALIAS%%_remove {
      my ( $self, $link_id_list, $p ) = @_;

      # Allow user to pass only one ID to remove (scalar) or an
      # arrayref (ref)

      $link_id_list = ( ref $link_id_list ) ? $link_id_list : [ $link_id_list ];
      my $removed = 0;
      my @error_list = ();
      foreach my $link_id ( @{ $link_id_list } ) {
        SPOPS::_wm( 1, $p->{DEBUG}, "Trying to remove link to ID ($link_id)" );
        my $from_id_clause = $self->id_clause( undef, 'noqualify', $p  );
        my $to_id_clause   = %%LINKSTO_CLASS%%->id_clause( $link_id, 'noqualify', $p );
        eval { %%CLASS%%->db_delete({ table => '%%LINKSTO_TABLE%%',
                                      where => join( ' AND ', $from_id_clause, $to_id_clause ),
                                      db    => $p->{db},
                                      DEBUG => $p->{DEBUG} }) };
        if ( $@ ) { 
          my $count = scalar @error_list + 1;
          my $value_list = ( ref $SPOPS::Error::extra->{value} ) 
                             ? join( ' // ', @{ $SPOPS::Error::extra->{value} } )
                             : 'none reported';
          my $error_msg = "Error $count\n$@\n$SPOPS::Error::system_msg\n" .
                          "SQL: $SPOPS::Error::extra->{sql}\nValues: $value_list";
          push @error_list, $error_msg; 
        } 
        else { 
          $removed++;
        }
      }
      if ( scalar @error_list ) {
        $SPOPS::Error::system_msg = join "\n\n", @error_list;
        die 'Remove %%LINKSTO_ALIAS%% failed for one or more items';
      }
      return $removed;
    }

LINKSTO


#
# ACTUAL SUBROUTINE
#

sub create_relationship {
  my ( $class, $info ) = @_;
  
  # Before we do anything, call our parent
  
  $class->SUPER::create_relationship( $info );

  DEBUG() && _w( 1, "Adding DBI relationships for: ($info->{class})" );
  
  # Go through each alias defined in the config
  # and process DBI-specific stuff
  
  my $this_class    = $info->{class};
  my $this_id_field = $info->{id_field};
  my $this_alias    = $info->{main_alias};

  # Process the 'links_to' aliases -- pretty straightforward (see pod)

  if ( my $links_to = $info->{links_to} ) { 
    while ( my ( $linksto_class, $table ) = each %{ $links_to } ) {
      my $linksto_config   = $linksto_class->CONFIG;
      my $linksto_alias    = $linksto_config->{main_alias};
      my $linksto_id_field = $linksto_config->{id_field};
      DEBUG() && _w( 1, "Aliasing $linksto_alias, ${linksto_alias}_add and ",
                      "${linksto_alias}_remove in $this_class"  );
      my $linksto_sub = $generic_linksto;
      $linksto_sub =~ s/%%ID_FIELD%%/$this_id_field/g;
      $linksto_sub =~ s/%%CLASS%%/$this_class/g;
      $linksto_sub =~ s/%%LINKSTO_CLASS%%/$linksto_class/g;
      $linksto_sub =~ s/%%LINKSTO_ALIAS%%/$linksto_alias/g;
      $linksto_sub =~ s/%%LINKSTO_ID_FIELD%%/$linksto_id_field/g;
      $linksto_sub =~ s/%%LINKSTO_TABLE%%/$table/g;
      DEBUG() && _w( 2, "Now going to eval the routine:\n$linksto_sub" );
      {
        local $SIG{__WARN__} = sub { return undef };
        eval $linksto_sub;
      }
      if ( $@ ) {
        die "Cannot eval links_to routines into $this_class\n",
            "Error: $@\n",
            "Routines: $linksto_sub";
      }
    }
  }
  DEBUG() && _w( 1, "Finished adding DBI relationships for ($info->{class})" );
  return $this_class;
}

1;

__END__

=pod

=head1 NAME

SPOPS::Configure::DBI - Define additional configuration methods

=head1 SYNOPSIS

  my $init_classes = SPOPS::Configure::DBI->parse_config( { config => $CONFIG->{SPOPS} } );

=head1 DESCRIPTION

We override the method I<create_relationship()> from
L<SPOPS::Configure> so we can create subroutines in the classes that
want to B<link_to> other objects, among other things.

It is possible -- and perhaps desirable for the sake of clarity --
to create a method within I<SPOPS::DBI> that does all 
the work for us, then we would only need to create a subroutine
that calls that subroutine.

However, creating routines with the values embedded directly in them
should be quicker and more efficient. So we will try it this way.

=head1 METHODS

B<create_relationship( $spops_config )>

Get the config and plow through the SPOPS classes, seeing if 
any of them have the B<links_to> key defined. If so, we 
create three subroutines with the proper info.

The first is named '${links_to}' and simply returns an arrayref
of objects that the main object links to. For instance:

Example:

 # $links_to = 'group'
 # Retrieve all groups that this user is a member of

 my $group_list = eval { $user->group };

The second is named '${links_to}_add' and links the object to any
number of other objects. The return value is the number of successful
links.

The third is named '${links_to}_remove' and removes links from the
object to any number of other objects. The return value is the number
of successful removals.

Examples:

 # $links_to = 'group'
 # First retrieve all groups

 my $group_list = eval { $user->group };
 print "Group list: ", join( ' // ', map { $_->{group_id} } @{ $group_list } );

 >> 2 // 3 // 5

 # Now add some more, making the user a member of these new groups

 my $added = eval { $user->group_add( [ 7, 9, 21, 23 ] ) };
 print "Group list: ", join( ' // ', map { $_->{group_id} } @{ $group_list } );

 >> 2 // 3 // 5 // 7 // 9 // 21 // 23
 
 # Now remove two of them

 my $removed = eval { $user->group_remove( [ 2, 21 ] ) };
 print "Group list: ", join( ' // ', map { $_->{group_id} } @{ $group_list } );

 >> 3 // 5 // 7 // 9 // 23

=head1 CONFIGURATION FIELDS EXPLAINED

B<links_to> (\%)

The 'links_to' field allows you to specify a SPOPS alias and specify
which table is used to link the objects:

 {
    'SPOPS-tag' => 'table_name',
 }

Note that this relationship assumes a link table that joins two
separate tables. When you sever a link between two objects, you are
only deleting the link rather than deleting an object. See L<TO DO>
for another proposal.

We are also considering making 'SPOPS-tag' into 'SPOPS-class' to make
this more versatile. See L<SPOPS::Configure> for more info.

=head1 TO DO

B<Make 'links_to' more flexible>

We need to account for different types of linking; this may require an
additional field beyond 'links_to' that has a similar effect but works
differently.

For instance, Table-B might have a 'has_a' relationship with Table-A,
but Table-A might have a 'links_to' relationship with Table-B. (Themes
in OpenInteract work like this.) We need to be able to specify that
when Table-A severs its relationship with one or more objects from
Table-B, the actual B<object> is removed rather than just a link
between them.

=head1 BUGS

None known.

=head1 COPYRIGHT

Copyright (c) 2001 intes.net, inc.. All rights reserved.

This library is free software; you can redistribute it and/or modify
it under the same terms as Perl itself.

=head1 AUTHORS

Chris Winters  <chris@cwinters.com>

Ray Zimmerman <rz10@cornell.edu> and eliot night <enight@sporks.com>
found a bug in the '_remove' clause generated, where a database handle
being passed in was not passed along to the C<id_clause()> methods.

=cut
