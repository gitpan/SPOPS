# -*-perl-*-

# $Id: 03_uuid_key.t,v 1.2 2001/12/31 16:10:36 lachoy Exp $

use strict;

{

    # Get the configuration info (in this case, just whether we're
    # supposed to run or not)

    do "t/config.pl";
    my $config = _read_config_file();
    $config->{UUID_test} ||= 'n';
    if ( $config->{UUID_test} ne 'y' ) {
        print "1..0\n";
        print "Skipping test on this platform\n";
        exit;
    }

    require Test::More;
    Test::More->import( tests => 6 );

    my %config = (
      test => {
         class    => 'LoopbackTest',
         isa      => [ qw( SPOPS::Key::UUID SPOPS::Loopback ) ],
         field    => [ qw( id_field field_name ) ],
         id_field => 'id_field',
      },
    );

    # Create our test class using the loopback

    # TEST: 1
    require_ok( 'SPOPS::Initialize' );

    # TEST: 2-3
    my $class_init_list = eval { SPOPS::Initialize->process({ config => \%config }) };
    ok( ! $@, "Initialize process run $@" );
    is( $class_init_list->[0], 'LoopbackTest', 'Loopback initialized' );

    # Create an object and save it, checking to see if {id_field} was
    # generated by SPOPS::Key::UUID

    # TEST: 4
    my $item = eval { LoopbackTest->new };
    ok( ! $@, "Create object" );

    # TEST: 5
    eval { $item->save };
    $item->save;
    ok( $item->{id_field}, "UUID generate on save()" );

    # Now just call it directly and ensure they're unique

    # TEST: 6
    my %track = ();
    for ( 1..100 ) {
        my $new_uuid = SPOPS::Key::UUID->pre_fetch_id;
        $track{ $new_uuid }++;
    }
    is( scalar keys %track, 100, "Unique keys generated" );
}
