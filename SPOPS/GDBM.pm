package SPOPS::GDBM;

# $Header: /usr/local/cvsdocs/SPOPS/SPOPS/GDBM.pm,v 1.9 2000/10/15 18:48:31 cwinters Exp $

use strict;
use SPOPS;
use Carp          qw( carp );
use Data::Dumper  qw( Dumper );
use GDBM_File;

@SPOPS::GDBM::ISA       = qw( SPOPS );
@SPOPS::GDBM::VERSION   = sprintf("%d.%02d", q$Revision: 1.9 $ =~ /(\d+)\.(\d+)/);

use constant DEBUG       => 0;
use constant DEBUG_FETCH => 0;
use constant DEBUG_SAVE  => 0;

# Make this the default for everyone -- they can override it themselves...
sub class_initialize {
 my $class  = shift;
 my $CONFIG = shift;
 my $C = $class->CONFIG;
 if ( ref $C->{field} eq 'HASH' ) {
   $C->{field_list}  = [ sort{ $C->{field}->{$a} <=> $C->{field}->{$b} } keys %{ $C->{field} } ];
 }
 $class->_class_initialize( $CONFIG ); # allow subclasses to do their own thing
 return 1;
}

# Dummy for subclasses to override
sub _class_initialize { return 1; }

# Override the default SPOPS initialize call so
# we can use mixed-case fields
sub initialize {
 my $self = shift;
 my $p    = shift;
 return unless ( ref $p and scalar( keys %{ $p } ) );
 
 # Set the GDBM filename if it was passed
 if ( $p->{GDBM_FILENAME} ) {
   $self->{tmp_gdbm_filename} = $p->{GDBM_FILENAME};
   delete $p->{GDBM_FILENAME};
 }

 # We allow the user to substitute id => value instead for the
 # specific fieldname.
 if ( my $id = $p->{id} ) {
   $p->{ $self->id_field } ||= $id;
   delete $p->{id};
 }

 # Use all lowercase to allow people to 
 # give us fieldnames in mixed case (we are very nice)
 my %data = map { lc $_ => $p->{ $_ } } keys %{ $p };
 foreach my $key ( keys %data ) {
   $self->{ $key } = $data{ $key };
 }
 return $self;
}

# Override this to get the db handle from somewhere else, if necessary
sub global_gdbm_tie {
 my $item = shift;
 my $p     = shift;
 $p->{perm} ||= 'read';
 my $gdbm_filename = $p->{filename};
 unless ( $gdbm_filename ) {
   $gdbm_filename   = $item->{tmp_gdbm_filename} if ( ref $item );
   $gdbm_filename ||= $item->CONFIG->{gdbm_info}->{filename};
   $gdbm_filename ||= $item->global_config->{gdbm_info}->{filename};
 }
 warn " (GDBM/global_gdbm_tie): Trying file $gdbm_filename to connect\n"   if ( DEBUG );
 unless ( $gdbm_filename ) {
   die "Insufficient/incorrect information to tie to GDBM file! ($gdbm_filename)\n";
 }
 my $perm = GDBM_File::GDBM_READER;
 $perm    = GDBM_File::GDBM_WRITER  if ( $p->{perm} eq 'write' );
 $perm    = GDBM_File::GDBM_WRCREAT if ( $p->{perm} eq 'create' );
 warn " (GDBM/global_gdbm_tie): Trying to use perm $perm to connect\n"     if ( DEBUG );
 my %db = ();
 tie( %db, 'GDBM_File', $gdbm_filename, $perm, 0660 );
 return \%db;
}

# Override the SPOPS method for finding ID values
sub id {
 my $self = shift;
 if ( my $id_field = $self->id_field ) {
   return $self->{ $id_field };
 }
 return $self->CONFIG->{create_id}->( $self );
}

sub object_key {
 my $self = shift;
 my $id   = shift;
 $id ||= $self->id  if ( ref $self );
 die "Cannot create object key without object or id!\n"  unless ( $id );
 my $class = ref $self || $self;
 return join '--', $class, $id;
}

# Given a key, return the data structure from the db file
sub _return_structure_for_key {
 my $class = shift;
 my $key   = shift;
 my $p     = shift;
 my $db    = $p->{db} || $class->global_gdbm_tie( $p );
 my $item_info = $db->{ $key };
 return undef unless ( $item_info );
 my $data = undef;
 { 
   no strict 'vars'; 
   $data = eval $item_info; 
 }
 die "Cannot rebuild object! Error: $@" if ( $@ );
 return $data;
}

# Retreive an object 
sub fetch {
 my $class = shift;
 my $id    = shift;
 my $p     = shift;
 my $data = $p->{data};
 unless ( $data ) {
   return undef unless ( $id and $id !~ /^tmp/ );
   return undef unless ( $class->pre_fetch_action( { id => $id } ) );
   $data = $class->_return_structure_for_key( $class->object_key( $id ), { filename => $p->{filename} } );
 } 
 my $obj = $class->new( $data );
 $obj->clear_change;
 return undef unless ( $class->post_fetch_action );
 return $obj;
}

# Return all objects in a particular class
sub fetch_group {
 my $item = shift;
 my $p    = shift;
 my $db = $p->{db} || $item->global_gdbm_tie( { filename => $p->{filename} } );
 my $class = ref $item || $item;
 my @object_keys = grep /^$class/, keys %{ $db };
 my @objects = ();
 foreach my $key ( @object_keys ) {
   my $data = eval { $class->_return_structure_for_key( $key, { db => $db } ) };
   next unless ( $data );      
   push @objects, $class->fetch( undef, { data => $data } );
 } 
 return \@objects;
}

# Save (either insert or update) an item in the db
sub save {
 my $self = shift;
 my $p    = shift;
 $p->{perm} ||= 'write';

 my $DEBUG = DEBUG_SAVE || $p->{DEBUG};
 warn " (DBI/save): Trying to save a <<", ref $self, ">>\n"                if ( $DEBUG );
 my $id = $self->id;

 my $is_add = ( $p->{is_add} or ! $id or $id =~ /^tmp/ );
 unless ( $is_add or $self->changed ) {
   warn " (DBI/save): This object exists and has not changed. Exiting.\n"  if ( $DEBUG );
   return $id;
 }
 return undef unless ( $self->pre_save_action( { is_add => $is_add } ) );

 # Build the data and dump to string
 my %data = %{ $self };
 local $Data::Dumper::Indent = 0;
 my $obj_string = Data::Dumper->Dump( [ \%data ], [ 'data' ] );

 # Save to DB
 my $obj_index  = $self->object_key;
 my $db = $p->{db} || $self->global_gdbm_tie( { perm => $p->{perm}, filename => $p->{filename} } );
 $db->{ $obj_index } = $obj_string;

 return undef unless ( $self->post_save_action( { is_add => $is_add } ) );
 $self->clear_change;
 return $self->id;
}

# Remove an item from the db
sub remove {
 my $self = shift;
 my $p    = shift;
 my $obj_index  = $self->object_key;
 my $db = $p->{db} || $self->global_gdbm_tie( { perm => 'write', filename => $p->{filename} } );
 return delete $db->{ $obj_index };
}

1;

=pod

=head1 NAME

SPOPS::GDBM - Store SPOPS objects in a GDBM database

=head1 SYNOPSIS

 my $obj = Object::Class->new;
 $obj->{parameter1} = 'this';
 $obj->{parameter2} = 'that';
 my $id = $obj->save;

=head1 DESCRIPTION

Implements SPOPS persistence in a GDBM database. Currently the
interface is not as robust or powerful as the C<SPOPS::DBI>
implementation, but if you want more robust data storage, retrieval
and searching needs you should probably be using a SQL database anyway.

This is also a little different than the C<SPOPS::DBI> module in that
you have a little more flexibility as to how you refer to the actual
GDBM file required. Instead of defining one database throughout the
operation, you can change in midstream. (To be fair, you can also do
this with the C<SPOPS::DBI> module, it is just a little more
difficult.) For example:

 # Read objects from one database, save to another
 my @objects = Object::Class->fetch_group( { filename => '/tmp/object_old.gdbm' } );
 foreach my $obj ( @objects ) {
   $obj->save( { is_add => 1, gdbm_filename => '/tmp/object_new.gdbm' } );
 }

=head1 METHODS

B<id_field>

If you want to define an ID field for your class, override this. Can
be a class or object method.

B<class_initialize>

Much the same as in DBI. (Nothing interesting.)

B<initialize( \%params )>

Much the same as in DBI, although you are able to initialize an object
to use a particular filename by passing a value for the
'GDBM_FILENAME' key in the hashref for parameters when you create a
new object:

 my $obj = Object::Class->new( { GDBM_FILENAME = '/tmp/mydata.gdbm' } );

B<global_gdbm_tie( \%params )>

Returns a tied hashref if successful. 

Parameters:

 perm ($ (default 'read')
   Defines the permissions to open the GDBM file. GDBM recognizes
   three permissions: 'GDBM_READER', 'GDBM_WRITER', 'GDBM_WRCREAT'
   (for creating and having write access to the file). You only need
   to pass 'read', 'write', or 'create' instead of these constants.

   If you pass nothing, C<SPOPS::GDBM> will assume 'read'. Also note
   that on some GDBM implementations, specifying 'write' permission to
   a file that has not yet been created still creates it, so 'create'
   might be redundant on your system.

 filename ($) (optional)
   Filename to use. If it is not passed, we look into the
   'tmp_gdbm_filename' field of the object, and then the 'filename'
   key of the 'gdbm_info' key of the class config, and then the
   'filename' key of the 'gdbm_info' key of the global configuration.

B<id>

If you have defined a routine that returns the 'id_field' of an
object, it returns the value of that for a particular
object. Otherwise it executes the coderef found in the 'create_id' key
of the class configuration for the object. Usually this is something
quite simple:

 ...
 'create_id' => sub { return join( '--', $_[0]->{name}, $_[0]->{version} ) }
 ...

In the config file just joins the 'name' and 'version' parameters of
an object and returns the result. 

B<object_key>

Creates a key to store the object in GDBM. The default is to prepend
the class to the value returned by I<id()> to prevent ID collisions
between objects in different classes. But you can make it anything you
want.

B<fetch( $id, \%params >

Retrieve a object from a GDBM database. Note that $id corresponds
B<not> to the object key, or the value used to store the data. Instead
it is a unique identifier for objects within this class.

You can pass normal db parameters.

B<fetch_group( \%params )>

Retrieve all objects from a GDBM database from a particular class. If
you modify the 'object_key' method, you will probably want to modify
this as well.

You can pass normal db parameters.

B<save( \%params )>

Save (either insert or update) an object in a GDBM database.

You can pass normal db parameters.

B<remove( \%params )>

Remove an object from a GDBM database.

You can pass normal db parameters.

=head2 Private Methods

B<_return_structure_for_key( \%params )>

Returns the data structure in the GDBM database corresponding to a
particular key. This data structure is B<not> blessed yet, it is
likely just a hashref of data (depending on how you implement your
objects, although the default method for SPOPS objects is a tied
hashref).

This is an internal method, so do not use it.

You can pass normal db parameters.

=head1 TO DO

=head1 BUGS

=head1 SEE ALSO

 GDBM software: http://www.fsf.org/gnulist/production/gdbm.html

 GDBM on Perl/Win32: http://www.roth.net/perl/GDBM/

=head1 COPYRIGHT

Copyright (c) 2000 intes.net, inc.. All rights reserved.

This library is free software; you can redistribute it and/or modify
it under the same terms as Perl itself.

=head1 AUTHORS

 Chris Winters (cwinters@intes.net)

=cut
