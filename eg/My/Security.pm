package My::Security;

# $Id: Security.pm,v 3.1 2002/09/13 13:05:57 lachoy Exp $

use strict;
use Data::Dumper  qw( Dumper );
use SPOPS         qw( DEBUG );
use SPOPS::Initialize;
use SPOPS::Secure qw( :level :scope );

$My::Security::VERSION = sprintf("%d.%02d", q$Revision: 3.1 $ =~ /(\d+)\.(\d+)/);

sub _base_config {
    my $config = {
       'security' => {
           class        => 'My::Security',
           isa          => [ 'SPOPS::Secure::DBI', 'My::Common' ],
           rules_from   => [ 'SPOPS::Tool::DBI::DiscoverField' ],
           field_discover => 'yes',
           field        => [],
           id_field     => 'sid',
           increment_field => 1,
           sequence_name => 'sp_security_seq',
           no_insert    => [ qw/ sid / ],
           skip_undef   => [ qw/ object_id scope_id / ],
           no_update    => [ qw/ sid object_id class scope scope_id / ],
           base_table   => 'spops_security',
           sql_defaults => [ qw/ object_id scope_id / ],
           alias        => [],
           has_a        => {},
           links_to     => {},
           skip_object_key => 1,
       },
    };
    return $config;
}

sub config_class {
    SPOPS::Initialize->process({ config => [ _base_config() ] });
}

&config_class;

1;
