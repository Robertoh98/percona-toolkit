#!/usr/bin/env perl

BEGIN {
   die "The PERCONA_TOOLKIT_BRANCH environment variable is not set.\n"
      unless $ENV{PERCONA_TOOLKIT_BRANCH} && -d $ENV{PERCONA_TOOLKIT_BRANCH};
   unshift @INC, "$ENV{PERCONA_TOOLKIT_BRANCH}/lib";
};

use strict;
use warnings FATAL => 'all';
use English qw(-no_match_vars);
use Test::More;

use PerconaTest;
use Sandbox;
require "$trunk/bin/pt-table-sync";

my $output;
my $dp = new DSNParser(opts=>$dsn_opts);
my $sb = new Sandbox(basedir => '/tmp', DSNParser => $dp);
my $source_dbh = $sb->get_dbh_for('source');
my $replica_dbh  = $sb->get_dbh_for('replica1');

if ( !$source_dbh ) {
   plan skip_all => 'Cannot connect to sandbox source';
}
elsif ( !$replica_dbh ) {
   plan skip_all => 'Cannot connect to sandbox replica';
}
else {
   plan tests => 2;
}

$sb->load_file('source', 't/pt-table-sync/samples/enum_fields.sql');

# #############################################################################
# Issue 804: mk-table-sync: can't nibble because index name isn't lower case?
# #############################################################################
$source_dbh->do('set sql_log_bin=0');
$source_dbh->do(q/INSERT INTO enum_fields_db.rgb (name, hex_code) VALUES ('blue','0x0000FF')/);
$output = `$trunk/bin/pt-table-sync --sync-to-source h=127.1,P=12346,u=msandbox,p=msandbox -d enum_fields_db --print`;
$output = remove_traces($output);
chomp($output);
is(
   $output,
   q/REPLACE INTO `enum_fields_db`.`rgb`(`name`, `hex_code`) VALUES ('blue', '0x0000FF');/,
   'Quote Enum fields'
);

# #############################################################################
# Done.
# #############################################################################
$source_dbh->do('set sql_log_bin=1');
$sb->wipe_clean($source_dbh);
$sb->wait_for_replicas();
ok($sb->ok(), "Sandbox servers") or BAIL_OUT(__FILE__ . " broke the sandbox");
exit;
