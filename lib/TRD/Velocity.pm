package TRD::Velocity;

#use warnings;
use strict;
use Carp;

use version;
our $VERSION = qv('0.0.3');
our $debug = 0;

#======================================================================
sub new {
	my $pkg = shift;
	bless {
		params => undef,
		templatefile => undef,
		template => undef,
		contents => undef,
		command => undef,
		else => undef,
	}, $pkg;
};

#======================================================================
sub set {
	my $self = shift;
	my $name = shift;
	my $value = shift;

	$self->{params}->{$name} = $value;
}

#======================================================================
sub setTemplateFile {
	my $self = shift;
	my $templateFile = shift;
	my $fdata;

	$self->{templatefile} = $templateFile;

	open( my $fh, '<', $self->{templatefile} )|| die $!;
	while( <$fh> ){
		$fdata .= $_;
	}
	close( $fh );

	$self->{template} = $fdata;
}

#======================================================================
sub marge {
	my $self = shift;
	my $contents;

	$contents = $self->{template};

	if( $debug ){
		$contents =~s/([\t| ]*##.*)\n/<!--${1}-->\n/g;
	} else {
		$contents =~s/[\t| ]*##.*\n//g;
	}

	$contents = $self->tag_handler( $contents );
	$contents =~s/\${(.+?)}/$self->marge_val( $1 )/egos;

	$contents;
}

#======================================================================
sub tag_handler {
	my $self = shift;
	$self->{contents} = shift;
	my( $htm, $tag, $contents );

	$htm = '';
	$tag = '';
	while( $self->{contents} ne '' ){
		( $htm, $tag, $self->{contents} ) = split( /(#if|#foreach)/is, $self->{contents}, 2 );
		if( $tag eq '#if' ){
			$self->if_sub();
		} elsif( $tag eq '#foreach' ){
			$self->foreach_sub();
		}
		$contents .= $htm;
	}

	$contents;
}

#======================================================================
sub if_sub {
	my $self = shift;
	my $contents = '';
	my( $joken, $str, $stat, $cmd );

	$self->get_end();

	if( $self->{command} =~m/^\((.*?)\)(.*)/s ){
		$joken = $1;
		$str = $2;

		if( ($joken =~s/\$(\w+)\[(\d+)\]\.(\w+)\[(\d+)\]\.(\w+)/\$self->{params}->{$1}[$2]->{$3}[$4]->{$5}/g) ){
		} elsif( ($joken =~s/\$(\w+)\[(\d+)\]\.(\w+)/\$self->{params}->{$1}[$2]->{$3}/g) ){
		} elsif( ($joken =~s/\$(\w+)\.(\w+)/\$self->{params}->{$1}->{$2}/g) ){
		} else {
			$joken =~s/\$(\w+)/\$self->{params}->{$1}/g;
		}

		$stat = 0;
		$cmd = qq!\$stat = 1 if( $joken );!;
		eval( $cmd ); ## no critic
		if( $stat ){
			if( $debug ){
				$contents .= "<!-- if(${joken}) -->". $str. "<!-- else ". $self->{else}. " end-->";
			} else {
				$contents .= $str;
			}
		} else {
			if( $debug ){
				$contents .= "<!-- if(${joken}) ${str} else -->". $self->{else}. "<!-- end -->";
			} else {
				$contents .= $self->{else};
			}
		}
	}

	$self->{contents} = $contents. $self->{contents};
}

#======================================================================
sub foreach_sub {
	my $self = shift;
	my( $contents, $cmd );

	$self->get_end();

	if( $self->{command} =~m/^\((.*?)\)(.*)$/s ){
		my $joken = $1;
		my $str = $2;
		my( $param1, $param2, $param3 );
		if( $joken =~m/^\s*\$(\w+?)\s+in\s+\$([\w\.\[\]]+?)\s*$/ ){
			$param1 = $1;
			$param2 = $2;
		}
		my @parts = split( /\./, $param2 );
		my $cnt = scalar( @parts );
		$param3 = $param2;
		$param3 =~s/(\w+)/\{${1}\}/g;
		$param3 =~s/\[\{(\d+)\}\]/\[${1}\]/g;
		$param3 =~s/\./->/g;
		$param3 = '$self->{params}->'. $param3;
		my $stat = 0;
		$cmd = qq!\$stat = 1 if( exists( $param3 ) );!;
		eval( $cmd ); ## no critic
		if( $@ ){
			print STDERR "ERROR: $@: ${cmd}<br>\n";
			$contents .= "ERROR: $@: ${cmd}";
		}
		if( $stat ){
			my @datas;
			$cmd = qq!\@datas = \@{${param3}};!;
			eval( $cmd ); ## no critic
			my $buff;
			my $cnt = 0;
			foreach my $item ( @datas ){
				$buff = $str;
				$buff =~s/\${$param1\./\${$param2\[$cnt\]\./g;
				$buff =~s/\$$param1\./\$$param2\[$cnt\]\./g;
				$contents .= $buff;
				$cnt ++;
			}
		} else {
			print STDERR "ERROR: foreach_sub: not exist ${param3}\n";
			$contents .= "ERROR: foreach_sub: not exist ${param3}";
		}
	}

	$self->{contents} = $contents. $self->{contents};
}

#======================================================================
sub get_end {
	my $self = shift;
	my( $htm, $tag, $retstr );
	my $if = 0;
	my $mode = 0;

	$self->{command} = '';
	$self->{else} = '';

	while( $self->{contents} ne '' ){
		( $htm, $tag, $self->{contents} ) = split( /(#if|#foreach|#end|#else)/is, $self->{contents}, 2 );
		$retstr .= $htm;
		if(( $tag eq '#if' )||( $tag eq '#foreach' )){
			$if += 1;
		} elsif( $tag eq '#end' ){
			if( $if == 0 ){
				last;
			}
			$if -= 1;
		} elsif( $tag eq '#else' ){
			if( $if == 0 ){
				$mode = 1;
				$self->{command} = $retstr;
				$retstr = '';
				$tag = '';
			}
		}
		$retstr .= $tag;
	}

	if( $mode == 0 ){
		$self->{command} = $retstr;
	} else {
		$self->{else} = $retstr;
	}
}

#======================================================================
sub marge_val {
	my $self = shift;
	my $ch_name = shift;
	my $retstr;

	my $param = $ch_name;
	$param =~s/(\w+)/\{${1}\}/g;
	$param =~s/\[\{(\d+)\}\]/\[${1}\]/g;
	$param =~s/\./->/g;
	$param = '$self->{params}->'. $param;
	my $cmd = qq!\$retstr = $param;!;
	eval( $cmd ); ## no critic

	$retstr;
}

#======================================================================
sub dump {
	my $self = shift;

	my $d = Dumpvalue->new();
	$d->dumpValue( \$self->{params} );
	print "templatefile=". $self->{templatefile}. "\n";
}

1; # Magic true value required at end of module
__END__

=head1 NAME

TRD::Velocity - [One line description of module's purpose here]


=head1 VERSION

This document describes TRD::Velocity version 0.0.1


=head1 SYNOPSIS

    use TRD::Velocity;

=for author to fill in:
    Brief code example(s) here showing commonest usage(s).
    This section will be as far as many users bother reading
    so make it as educational and exeplary as possible.
  
  
=head1 DESCRIPTION

=for author to fill in:
    Write a full description of the module and its features here.
    Use subsections (=head2, =head3) as appropriate.


=head1 INTERFACE 

=for author to fill in:
    Write a separate section listing the public components of the modules
    interface. These normally consist of either subroutines that may be
    exported, or methods that may be called on objects belonging to the
    classes provided by the module.


=head1 DIAGNOSTICS

=for author to fill in:
    List every single error and warning message that the module can
    generate (even the ones that will "never happen"), with a full
    explanation of each problem, one or more likely causes, and any
    suggested remedies.

=over

=item new
new Constructor of people.

=item set
set parameter.

=item setTemplateFile
set Template file.

=item marge
marge Template to parameters.

=item dump
dump parameters.

=item tag_handler
tag handler

=item if_sub
tag '#if' subroutine.

=item foreach_sub
tag '#foreach' subroutine.

=item get_end
get to tag '#end'

=item marge_val
store parameter.

=item C<< Error message here, perhaps with %s placeholders >>

[Description of error here]

=item C<< Another error message here >>

[Description of error here]

[Et cetera, et cetera]

=back


=head1 CONFIGURATION AND ENVIRONMENT

=for author to fill in:
    A full explanation of any configuration system(s) used by the
    module, including the names and locations of any configuration
    files, and the meaning of any environment variables or properties
    that can be set. These descriptions must also include details of any
    configuration language used.
  
TRD::Velocity requires no configuration files or environment variables.


=head1 DEPENDENCIES

=for author to fill in:
    A list of all the other modules that this module relies upon,
    including any restrictions on versions, and an indication whether
    the module is part of the standard Perl distribution, part of the
    module's distribution, or must be installed separately. ]

None.


=head1 INCOMPATIBILITIES

=for author to fill in:
    A list of any modules that this module cannot be used in conjunction
    with. This may be due to name conflicts in the interface, or
    competition for system or program resources, or due to internal
    limitations of Perl (for example, many modules that use source code
    filters are mutually incompatible).

None reported.


=head1 BUGS AND LIMITATIONS

=for author to fill in:
    A list of known problems with the module, together with some
    indication Whether they are likely to be fixed in an upcoming
    release. Also a list of restrictions on the features the module
    does provide: data types that cannot be handled, performance issues
    and the circumstances in which they may arise, practical
    limitations on the size of data sets, special cases that are not
    (yet) handled, etc.

No bugs have been reported.

Please report any bugs or feature requests to
C<bug-trd-velocity@rt.cpan.org>, or through the web interface at
L<http://rt.cpan.org>.


=head1 AUTHOR

Takuya Ichikawa  C<< <trd.ichi@gmail.com> >>


=head1 LICENCE AND COPYRIGHT

Copyright (c) 2008, Takuya Ichikawa C<< <trd.ichi@gmail.com> >>. All rights reserved.

This module is free software; you can redistribute it and/or
modify it under the same terms as Perl itself. See L<perlartistic>.


=head1 DISCLAIMER OF WARRANTY

BECAUSE THIS SOFTWARE IS LICENSED FREE OF CHARGE, THERE IS NO WARRANTY
FOR THE SOFTWARE, TO THE EXTENT PERMITTED BY APPLICABLE LAW. EXCEPT WHEN
OTHERWISE STATED IN WRITING THE COPYRIGHT HOLDERS AND/OR OTHER PARTIES
PROVIDE THE SOFTWARE "AS IS" WITHOUT WARRANTY OF ANY KIND, EITHER
EXPRESSED OR IMPLIED, INCLUDING, BUT NOT LIMITED TO, THE IMPLIED
WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE. THE
ENTIRE RISK AS TO THE QUALITY AND PERFORMANCE OF THE SOFTWARE IS WITH
YOU. SHOULD THE SOFTWARE PROVE DEFECTIVE, YOU ASSUME THE COST OF ALL
NECESSARY SERVICING, REPAIR, OR CORRECTION.

IN NO EVENT UNLESS REQUIRED BY APPLICABLE LAW OR AGREED TO IN WRITING
WILL ANY COPYRIGHT HOLDER, OR ANY OTHER PARTY WHO MAY MODIFY AND/OR
REDISTRIBUTE THE SOFTWARE AS PERMITTED BY THE ABOVE LICENCE, BE
LIABLE TO YOU FOR DAMAGES, INCLUDING ANY GENERAL, SPECIAL, INCIDENTAL,
OR CONSEQUENTIAL DAMAGES ARISING OUT OF THE USE OR INABILITY TO USE
THE SOFTWARE (INCLUDING BUT NOT LIMITED TO LOSS OF DATA OR DATA BEING
RENDERED INACCURATE OR LOSSES SUSTAINED BY YOU OR THIRD PARTIES OR A
FAILURE OF THE SOFTWARE TO OPERATE WITH ANY OTHER SOFTWARE), EVEN IF
SUCH HOLDER OR OTHER PARTY HAS BEEN ADVISED OF THE POSSIBILITY OF
SUCH DAMAGES.
