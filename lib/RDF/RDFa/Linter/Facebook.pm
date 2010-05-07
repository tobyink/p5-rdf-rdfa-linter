package RDF::RDFa::Linter::Facebook;

use 5.008;
use common::sense;
use constant OGP_NS => 'http://opengraphprotocol.org/schema/';
use constant FB_NS  => 'http://developers.facebook.com/schema/';
use RDF::Trine;
use RDF::Trine::Iterator qw'sgrep';
use RDF::TrineShortcuts qw'rdf_query';

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
}

sub new
{
	my ($class, $model, $uri) = @_;
	my $self = bless {}, $class;
	
	$self->{'original'} = $model;
	$self->{'filtered'} = RDF::Trine::Model->temporary_model;
	$self->{'uri'}      = $uri;
	
	my $filtered = sgrep \&sgrep_filter, $model->as_stream;
	while (my $st = $filtered->next)
		{ $self->{'filtered'}->add_statement($st); }
	
	return $self;
}

sub find_errors
{
	my ($self) = @_;
	my @rv;
	
	push @rv, $self->_unknown_types;
	
	return @rv;
}

sub _unknown_types
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
	my $iter   = rdf_query($sparql, $self->{'filtered'});
	
	while (my $row = $iter->next)
	{
		unless ($row->{'type'}->is_literal)
		{
			push @errs,
				{
					'subject' => $row->{'subject'},
					'error'   => 'Non-literal value for og:type: '.$row->{'type'}->as_ntriples,
					'level'   => 3,
					'link'    => 'http://opengraphprotocol.org/#types',
				};
			next;
		}
		if ($row->{'type'}->literal_value !~ m/^($regexp)$/x)
		{
			push @errs,
				{
					'subject' => $row->{'subject'},
					'error'   => 'Unrecognised value for og:type: '.$row->{'type'}->literal_value,
					'level'   => 3,
					'link'    => 'http://opengraphprotocol.org/#types',
				};
		}
	}
	
	return @errs;
}

1;