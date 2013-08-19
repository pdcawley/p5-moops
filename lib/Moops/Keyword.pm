use v5.14;
use strict;
use warnings FATAL => 'all';
no warnings qw(void once uninitialized numeric);

package Moops::Keyword;

our $AUTHORITY = 'cpan:TOBYINK';
our $VERSION   = '0.010';

use Moo;
use B qw(perlstring);
use Module::Runtime qw(module_notional_filename);
use namespace::sweep;

has 'keyword'    => (is => 'ro');
has 'ccstash'    => (is => 'ro');
has 'package'    => (is => 'ro');
has 'version'    => (is => 'ro', predicate => 'has_version');
has 'relations'  => (is => 'ro');
has 'is_empty'   => (is => 'ro');
has 'imports'    => (is => 'ro', predicate => 'has_imports');

sub generate_code
{
	my $self = shift;
	my $class = ref $self;
	my $package = $self->package;
	
	# Create the package declaration and version
	my $inject = "package $package;";
	$inject .= (
		$self->has_version
			? "BEGIN { our \$VERSION = '${\ $self->version }' };"
			: "BEGIN { our \$VERSION = '' };"
	);
	$inject .= "BEGIN { \$INC{${\ perlstring module_notional_filename $package }} = __FILE__ };";
	
	# Standard imports
	$inject .= join qq[\n], $self->generate_package_setup;
	
	# Additional imports
	$inject .= $self->imports->generate_code($package) if $self->has_imports;
	
	# Stuff that must happen at runtime rather than compile time
	$inject .= "'Moops'->at_runtime('$package');";
	
	return $inject;
}

sub generate_package_setup
{
	my $self = shift;
	
	return if $self->is_empty;
	
	my $kw      = $self->keyword;
	my $class   = ref($self);
	my $package = $self->package;
	
	return (
		'use Carp qw(confess);',
		"use Function::Parameters '$class'->arguments_for_function_parameters(q[$package]);",
		'use Moops::DefineKeyword;',
		'use Scalar::Util qw(blessed);',
		'use Try::Tiny;',
		'use Types::Standard qw(-types);',
		'use v5.14;',
		'use strict;',
		'use warnings FATAL => qw(all); no warnings qw(void once uninitialized numeric);',
		'BEGIN { (*true, *false) = (\&Moops::_true, \&Moops::_false) };',
	);
}

sub arguments_for_function_parameters
{
	my $class = shift;
	my ($pkg) = @_;
	
	state $reify = sub {
		state $guard = do { require Type::Utils };
		Type::Utils::dwim_type($_[0], for => $_[1]);
	};
	
	return +{
		fun => {
			name                 => 'optional',
			default_arguments    => 1,
			check_argument_count => 1,
			named_parameters     => 1,
			types                => 1,
			reify_type           => $reify,
		},
	};
}

sub known_relationships
{
	return;
}

sub qualify_relationship
{
	return 1;
}

1;
