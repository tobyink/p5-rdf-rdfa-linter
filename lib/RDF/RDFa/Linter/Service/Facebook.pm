package RDF::RDFa::Linter::Service::Facebook;

use 5.008;
use base 'RDF::RDFa::Linter::Service';
use common::sense;
use constant OGP_NS => 'http://opengraphprotocol.org/schema/';
use constant FB_NS  => 'http://developers.facebook.com/schema/';
use RDF::TrineShortcuts qw'rdf_query rdf_statement';

our $VERSION = '0.01';

our @ogp_terms = qw(title type image url description site_name
	latitude longitude street-address locality region postal-code country-name
	email phone_number fax_number upc isbn);

our @fb_terms  = qw(admins app_id);

sub sgrep_filter
{
	my ($st) = @_;
	
	foreach my $term (@ogp_terms)
		{ return 1 if $st->predicate->uri eq OGP_NS.$term; }

	foreach my $term (@fb_terms)
		{ return 1 if $st->predicate->uri eq FB_NS.$term; }

	return 0;
};

sub new
{
	my $self = RDF::RDFa::Linter::Service::new(@_);
	
	$self->{'filtered'}->add_statement(rdf_statement(
		$self->{'uri'},
		'http://www.w3.org/1999/02/22-rdf-syntax-ns#type', 
		'urn:x-rdf-rdfa-linter:internals:OpenGraphProtocolNode',
		));
	
	return $self;
}

sub info
{
	return {
		short        => 'Facebook',
		title        => 'Facebook / Open Graph Protocol',
		description  => 'The Open Graph Protocol, from Facebook. See opengraphprotocol.org for details.',
		};
}

sub prefixes
{
	my ($proto) = @_;
	return { 'og' => OGP_NS , 'fb' => FB_NS };
}

sub find_errors
{
	my $self = shift;
	my @rv = $self->SUPER::find_errors(@_);
	
	push @rv, $self->_check_unknown_types;
	push @rv, $self->_check_required_properties;
	
	return @rv;
}

sub _check_unknown_types
{
	my ($self) = @_;
	my @errs;
	
	my $regexp = 'activity|sport|bar|company|cafe|hotel|restaurant|
	              cause|sports_league|sports_team|band|government|
	              non_profit|school|university|actor|athlete|author|
	              director|musician|politician|public_figure|city|
	              country|landmark|state_province|album|book|drink|
	              food|game|movie|product|song|tv_show|article|blog|website';
	
	my $sparql = sprintf('SELECT * WHERE { ?subject <%s%s> ?type . }', OGP_NS, 'type');
	my $iter   = rdf_query($sparql, $self->filtered_graph);
	
	while (my $row = $iter->next)
	{
		unless ($row->{'type'}->is_literal)
		{
			push @errs,
				RDF::RDFa::Linter::Error->new(
					'subject' => $row->{'subject'},
					'text'    => 'Non-literal value for og:type: '.$row->{'type'}->as_ntriples,
					'level'   => 3,
					'link'    => 'http://opengraphprotocol.org/#types',
				);
			next;
		}
		if ($row->{'type'}->literal_value !~ m/^($regexp)$/x)
		{
			push @errs,
				RDF::RDFa::Linter::Error->new(
					'subject' => $row->{'subject'},
					'text'    => 'Unrecognised value for og:type: '.$row->{'type'}->literal_value,
					'level'   => 3,
					'link'    => 'http://opengraphprotocol.org/#types',
				);
		}
	}
	
	return @errs;
}

sub _check_required_properties
{
	my ($self) = @_;
	my @errs;
	
	my $sparql  = sprintf('DESCRIBE <%s>', $self->{'uri'});
	my $hashref = rdf_query($sparql, $self->filtered_graph)->as_hashref;
	
	foreach my $prop (qw(title type image url))
	{
		push @errs,
			RDF::RDFa::Linter::Error->new(
				'subject' => RDF::Trine::Node::Resource->new($self->{'uri'}),
				'text'    => 'Missing property: og:'.$prop,
				'level'   => 2,
				'link'    => 'http://opengraphprotocol.org/#metadata',
			)
			unless defined $hashref->{ $self->{'uri'} }->{ OGP_NS.$prop };
	}
	
	return @errs;
}

1;
