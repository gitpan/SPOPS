#!/usr/bin/perl

# $Id: dbi_config.pl,v 2.0 2002/03/19 04:00:07 lachoy Exp $

use strict;
use DBI;

my %DRIVERS = (
   ASAny  => 'SPOPS::DBI::Sybase',
   mysql  => 'SPOPS::DBI::MySQL',
   Oracle => 'SPOPS::DBI::Oracle',
   Pg     => 'SPOPS::DBI::Pg',
   SQLite => 'SPOPS::DBI::SQLite',
   Sybase => 'SPOPS::DBI::Sybase',
);

my %DRIVER_ACTIONS = ( Sybase => \&sybase_setup,
                       Oracle => \&oracle_setup, );

my %DRIVER_NO_TYPE = map { $_ => 1 } qw();

my $SIMPLE_TABLE = <<'SIMPLESQL';
CREATE TABLE %s (
    spops_id    int not null primary key,
    spops_name  char(20),
    spops_goop  char(20) not null,
    spops_num   int default 2
)
SIMPLESQL

my $MULTI_TABLE = <<'MULTISQL';
CREATE TABLE %s (
   spops_time   int not null,
   spops_user   int not null,
   spops_name   char(20),
   spops_goop   char(20) not null,
   spops_num    int default 2,
   primary key( spops_time, spops_user )
)
MULTISQL



# Read in the config file and make sure we're supposed to run; if we
# are, return the configuration

sub test_dbi_run {
    do "t/config.pl";
    my $config = _read_config_file();
    $config->{DBI_test} ||= 'n';
    if ( $config->{DBI_test} ne 'y' ) {
        print "1..0\n";
        print "Skipping test on this platform\n";
        exit;
    }
    return $config;
}

sub get_db_handle {
    my ( $config ) = @_;
    my $db = DBI->connect( $config->{DBI_dsn},
                           $config->{DBI_user},
                           $config->{DBI_password} );
    unless ( $db ) {
        die "Cannot connect to database using parameters given. Please\n",
            "edit 'spops_test.conf' with correct information if you'd like\n",
            "to perform the tests. (Error: ", DBI->errstr, ")\n";
    }

    $db->{AutoCommit} = 1;
    $db->{ChopBlanks} = 1;
    $db->{RaiseError} = 1;
    $db->{PrintError} = 0;
    return $db;
}


sub create_table {
    my ( $db, $type, $name ) = @_;
    my ( $table_raw );
    $table_raw = $SIMPLE_TABLE if ( $type eq 'simple' );
    $table_raw = $MULTI_TABLE  if ( $type eq 'multi' );
    my $table_sql = sprintf( $table_raw, $name );
    eval { $db->do( $table_sql ) };
    if ( $@ ) {
        die "Halting DBI tests -- Cannot create table ($name) in DBI database! Error: $@\n";
    }
    return $name;
}


sub cleanup {
    my ( $db, $table_name ) = @_;
    my $clean_sql = "DROP TABLE $table_name";
    eval { $db->do( $clean_sql ) };
    if ( $@ ) {
        warn "All tests passed ok, but we cannot run ($clean_sql). Error: $@\n";
    }
    $db->disconnect;
}


sub sybase_setup {
     my ( $config ) = @_;
     if ( $config->{ENV_SYBASE} ) {
         $ENV{SYBASE} = $config->{ENV_SYBASE};
     }
}


sub oracle_setup {
    my ( $config ) = @_;
    if ( $config->{ENV_ORACLE_HOME} ) {
        $ENV{ORACLE_HOME} = $config->{ENV_ORACLE_HOME};
    }
}


sub assign_manual_types {
    my ( $class ) = @_;
    $class->CONFIG->{dbi_type_info} = { spops_id   => 'num',
                                        spops_name => 'char',
                                        spops_goop => 'char',
                                        spops_num  => 'num' };
}


# Ensure we can use the installed version of the DBD picked. Currently
# we only need to test for DBD::ASAny

sub check_dbd_compliance {
    my ( $config, $driver_name, $spops_class ) = @_;

    if ( $driver_name eq 'ASAny' ) {
        eval { require DBD::ASAny };
        if ( $@ ) {
            die "Cannot require DBD::ASAny module. Are you sure that you have ",
                "it installed? (Error: $@)\n";
        }

        # get around annoying (!) -w declaration that var is only used
        # once...

        my $dumb_ver = $DBD::ASAny::VERSION;

        # See that the right version is installed. 1.09 has been
        # tested and found ok. (Assuming higher versions will also be
        # ok.)

        if ( $DBD::ASAny::VERSION < 1.09 ) {
            die <<ASANY;
-- The DBD::ASAny driver prior version 1.09 did not support the {TYPE}
attribute Please upgrade the driver before using SPOPS. If you do not
do so, SPOPS will not work properly!

Skipping text on this platform
ASANY
        }
    }

    # If the driver is *known* not to process {TYPE} info, we tell the
    # test class to include the type info in its configuration

    if ( $DRIVER_NO_TYPE{ $driver_name } ) {
        warn "\nDBD Driver $driver_name does not support {TYPE} information\n",
             "Installing manual types for test.\n";
        assign_manual_types( $spops_class );
    }

    if ( ref $DRIVER_ACTIONS{ $driver_name } eq 'CODE' ) {
        $DRIVER_ACTIONS{ $driver_name }->( $config );
    }
    return $DRIVERS{ $config->{DBI_driver} };
}
