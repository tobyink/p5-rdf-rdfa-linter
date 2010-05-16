package RDF::RDFa::Linter;

use 5.010;
use common::sense;
use RDF::RDFa::Linter::Error;
use RDF::RDFa::Linter::Service::Facebook;
use RDF::RDFa::Parser;
use RDF::Trine;

sub new
{
	my ($class, $service, $thisuri, $parser) = @_;
	
	my $self = bless {
		service  => __PACKAGE__ . '::Service::' . $service,
		uri      => $thisuri,
		parser   => $parser,
		}, $class;

	$parser->{'__linter'} = $self;
	$parser->set_callbacks({
		onprefix => \&cb_onprefix,
		oncurie  => \&cb_oncurie,
		});
	$self->{'graph'} = $parser->graph;
	$self->{'lint'}  = $self->{'service'}->new($parser->graph, $thisuri);

	return $self;
}

sub filtered_graph
{
	my ($self) = @_;
	return $self->{'lint'}->filtered_graph;
}

sub find_errors
{
	my ($self) = @_;
	my @errs = @{ $self->{'parse_errors'} };
	push @errs, $self->{'lint'}->find_errors;
	
	return @errs;
}

sub cb_onprefix
{
	my ($parser, $node, $prefix, $uri) = @_;
	my $self = $parser->{'__linter'};
	
	my $preferred = $self->{'service'}->prefixes;
	
	if (defined $preferred->{$prefix}
	and $preferred->{$prefix} ne $uri)
	{
		push @{ $self->{'parse_errors'} },
			RDF::RDFa::Linter::Error->new(
				'subject' => RDF::Trine::Node::Resource->new($self->{'uri'}),
				'text'    => "Prefix '$prefix' bound to <$uri>, instead of the usual <".$preferred->{$prefix}."> - this is allowed, but unusual.",
				'level'   => 1,
				);
	}
	elsif (!defined $preferred->{$prefix})
	{
		while (my ($p,$f) = each %$preferred)
		{
			if ($f eq $uri)
			{
				push @{ $self->{'parse_errors'} },
					RDF::RDFa::Linter::Error->new(
						'subject' => RDF::Trine::Node::Resource->new($self->{'uri'}),
						'text'    => "Prefix '$prefix' bound to <$uri>, instead of the usual prefix '$p' - this is allowed, but unusual.",
						'level'   => 1,
						);
			}
		}
	}
	
	return 0;
}

sub cb_oncurie
{
	my ($parser, $node, $curie, $uri) = @_;
	my $self = $parser->{'__linter'};

	return $uri unless $curie eq $uri || $uri eq '';

	my $preferred = $self->{'service'}->prefixes;
	
	if ($curie =~ m/^([^:]+):(.*)$/)
	{
		my ($pfx, $sfx) = ($1, $2);
		
		if (defined $preferred->{$pfx})
		{
			push @{ $self->{'parse_errors'} },
				RDF::RDFa::Linter::Error->new(
					'subject' => RDF::Trine::Node::Resource->new($self->{'uri'}),
					'text'    => "CURIE '$curie' used but '$pfx' is not bound - perhaps you forgot to specify xmlns:${pfx}=\"".$preferred->{$pfx}."\"",
					'level'   => 5,
					);
			
			return $preferred->{$pfx} . $sfx;
		}
		elsif ($pfx !~ m'^(http|https|file|ftp|urn|tag|mailto|acct|data|
			fax|tel|modem|gopher|info|news|sip|irc|javascript|sgn|ssh|xri)$'ix)
		{
			push @{ $self->{'parse_errors'} },
				RDF::RDFa::Linter::Error->new(
					'subject' => RDF::Trine::Node::Resource->new($self->{'uri'}),
					'text'    => "CURIE '$curie' used but '$pfx' is not bound - perhaps you forgot to specify xmlns:${pfx}=\"".$preferred->{$pfx}."\"",
					'level'   => 1,
					);
		}
	}

	return $uri;
}

1;
