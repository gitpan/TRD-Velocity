#!perl -T

use strict;
use warnings;
use Test::More tests => 4;

BEGIN {
	use_ok( 'TRD::Velocity' );
}

my $result;
$result = &test_param();
ok( $result, 'test_param' );
$result = &test_if();
ok( $result, 'test_if' );
$result = &test_foreach();
ok( $result , 'test_foreach' );

sub test_param {
	my $velo = new TRD::Velocity;
	my $templ = 'TEST=${test}';
	$velo->setTemplateData( $templ );
	$velo->set( 'test', 'OK' );
	my $doc = $velo->marge();

	if( $doc eq 'TEST=OK' ){
		1;
	} else {
		undef;
	}
}

sub test_if {
	my $velo = new TRD::Velocity;
	my $templ= 'TEST=#if( $test eq \'OK\' )OK#elseNG#end';
	$velo->setTemplateData( $templ );
	$velo->set( 'test', 'OK' );
	my $doc = $velo->marge();

	if( $doc eq 'TEST=OK' ){
		1;
	} else {
		undef;
	}
}
	
sub test_foreach {
	my $velo = new TRD::Velocity;
	my $templ= 'TEST=#foreach( $item in $items )${item.value}#end';
	$velo->setTemplateData( $templ );

	my $items;
	for( my $i=0; $i<10; $i++ ){
		my $item = { 'value' => 'OK'. ($i+1) };
		push( @{$items}, $item );
	}
	$velo->set( 'items', $items );
	my $doc = $velo->marge();

	if( $doc eq 'TEST=OK1OK2OK3OK4OK5OK6OK7OK8OK9OK10' ){
		# ok
		1;
	} else {
		# ng
		undef;
	}
}

