package SPOPS::Initialize;

# $Id: Initialize.pm,v 1.4 2001/06/03 22:43:34 lachoy Exp $

use strict;
use SPOPS        qw( _w DEBUG );
use SPOPS::Configure;

$SPOPS::Initialize::VERSION   = '1.7';
$SPOPS::Initialize::Revision  = substr(q$Revision: 1.4 $, 10);

# Main interface -- take the information read in from 'read_config()'
# and create SPOPS classes, then initialize them

sub process {
  my ( $class, $p ) = @_;
  $p ||= {};
  if ( $p->{directory} or $p->{filename} ) {
    my $new_config = $class->read_config( $p );
    return unless ( ref $new_config eq 'HASH' );
    delete $p->{filename};
    delete $p->{directory};
    delete $p->{pattern};
    $p->{config} = $new_config;
  }
  $p->{require_isa} = 1;

  my $class_created_ok = SPOPS::Configure->process_config( $p );
  return unless ( scalar @{ $class_created_ok } );
  my %class_created_map = map { $_ => 1 } @{ $class_created_ok };

  # Now go through each of the classes created and initialize

  my @full_success = ();
  foreach my $spops_key ( keys %{ $p->{config} } ) {
    my $spops_class = $p->{config}->{ $spops_key }->{class};
    next unless ( $class_created_map{ $spops_class } );
    $spops_class->class_initialize( $p->{config}->{ $spops_key } );
    if ( $@ ) {
      die "Running '->class_initialize()' on SPOPS class ($spops_class) failed: $@";
    }
    push @full_success, $spops_class;
  }
  return \@full_success;
}


# Read in one or more configuration files (see POD)

sub read_config {
  my ( $class, $p ) = @_;
  my @config_files = ();

  # You can specify one or more filenames to read

  if ( $p->{filename} ) {
    if ( ref $p->{filename} eq 'ARRAY' ) {
      push @config_files, @{ $p->{filename} };
    }
    else {
      push @config_files, $p->{filename};      
    }
  }

  # Or specify a directory and, optionally, a pattern to match for
  # files to read

  elsif ( $p->{directory} and -d $p->{directory} ) {    
    my $dir = $p->{directory};
    DEBUG() && _w( 1, "Reading configuration files from ($dir) with pattern ($p->{pattern})" );
    opendir( CONF, $dir ) 
           || die "Cannot open directory ($dir): $!";
    my @directory_files = readdir( CONF );    
    close( CONF );
    foreach my $file ( @directory_files ) {
      my $full_filename = "$dir/$file";
      next unless ( -f $full_filename );
      if ( $p->{pattern} ) {
        next unless ( $file =~ /$p->{pattern}/ );
      }
      push @config_files, $full_filename;
    }
  }

  # Now read in each of the files and assign the values to the main
  # $spops_config.

  my %spops_config = ();
  foreach my $file ( @config_files ) {
    DEBUG() && _w( 1, "Reading configuration from file: ($file)" );
    my $data = $class->read_perl_file( $file );
    if ( ref $data eq 'HASH' ) {
      foreach my $spops_key ( keys %{ $data } ) {
        $spops_config{ $spops_key } = $data->{ $spops_key };
      }
    }
  }

  return \%spops_config;
}


# Read in a Perl data structure from a file and return

sub read_perl_file {
  my ( $class, $filename ) = @_;
  return undef unless ( -f $filename );
  eval { open( INFO, $filename ) || die $! };
  if ( $@ ) {
    warn "Cannot open config file for evaluation ($filename): $@ ";
    return undef;
  }
  local $/ = undef;
  no strict;
  my $info = <INFO>;
  close( INFO );
  my $data = eval $info;
  if ( $@ ) {
    die "Cannot read data structure! from $filename\n",
        "Error: $@";
  }
  return $data;
}

1;

__END__

=pod

=head1 NAME

SPOPS::Initialize - Provide methods for initializing groups of SPOPS objects at once

=head1 SYNOPSIS

 # Bring in the class
 
 use SPOPS::Initialize;

 # Assumes that all your SPOPS configuration information is collected
 # in a series of files 'spops/*.perl'

 my $config = SPOPS::Initialize->read_config({ 
                                     directory => '/path/to/spops',
                                     pattern   => '\.perl' });

 # You could also have all your SPOPS classes in a single file:

 my $config = SPOPS::Initialize->read_config({ 
                              filename => '/path/to/my/spops.config' });

 # Or in a couple of files:

 my $config = SPOPS::Initialize->read_config({ 
                              filename => [ '/path/to/my/spops.config.1',
                                            '/path/to/my/spops.config.2' ] });

 # Bring all necessary SPOPS:: classes and initialize them

 SPOPS::Initialize->process({ config => $config });

 # As a shortcut, you read the config and process all at once

 SPOPS::Initialize->process({ filename => '/path/to/my/spops.config' });

=head1 DESCRIPTION

This class makes it simple to initialize SPOPS classes and should be
suitable for utilizing at a server (or long-running process) startup.

Initialization of a SPOPS class consists of four steps:

=over 4

=item 1.

Read in the configuration. The configuration can be in a separate
file, read from a database or built on the fly.

=item 2.

Ensure that the classes used by SPOPS are 'require'd.

=item 3.

Build the SPOPS class, using L<SPOPS::Configure> or a subclass of
it. 

=item 4.

Initialize the SPOPS class. This ensures any initial work the class
needs to do on behalf of its objects is done. Once this step is
complete you can instantiate objects of the class and use them at
will.

=back

=head1 METHODS

B<process( \%spops_config, \%params )>

Take configuration information

The first parameter, C<\%spops_config> is a hashref of SPOPS object
information. Key should be the SPOPS alias, value the configuration
information for this object.

Parameters (passed in C<\%params>) depend on C<SPOPS::Configure> --
any values you pass will be passed through. This is fairly rare -- the
only one you might ever want to pass is 'meta', which is a hashref of
information that determines how the object configuration is
treated. (See L<SPOPS::Configure> for more info.)

You can also pass in parameters that can be used for C<read_config()>
-- see below.

B<read_config( \%params )>

Read in SPOPS configuration information from one or more files in the
filesystem.

Parameters:

=over 4

=item *

B<filename> ($ or \@)

One or more filenames, each with a fully-qualified path.

=item *

B<directory> ($)

Directory to read files from. If no B<pattern> given, we try to read
all the files from this directory.

B<pattern> ($)

Regular expression pattern to match the files in the directory
B<directory>. For instance, you can use

  \.perl$

to match all the files ending in '.perl' and read them in.

=back

=head1 SEE ALSO

L<SPOPS::Configure>

=head1 COPYRIGHT

Copyright (c) 2001 Chris Winters. All rights reserved.

This library is free software; you can redistribute it and/or modify
it under the same terms as Perl itself.

=head1 AUTHORS

Chris Winters <chris@cwinters.com>

=cut
