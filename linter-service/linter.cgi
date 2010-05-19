#!/usr/bin/perl

use lib "/home/tai/src/perlmods/HTML-HTML5-Writer/lib";
use lib "/home/tai/src/perlmods/RDF-RDFa-Generator/lib";
use lib "/home/tai/src/perlmods/RDF-RDFa-Linter/lib";

use constant XHTML_NS => 'http://www.w3.org/1999/xhtml';
use CGI;
use File::Slurp qw'slurp';
use HTML::HTML5::Writer;
use HTTP::Cache::Transparent (BasePath=>'/tmp/cache/');
use HTTP::Negotiate qw'choose';
use JSON;
use RDF::RDFa::Generator;
use RDF::RDFa::Linter;
use RDF::RDFa::Linter::Error;
use RDF::RDFa::Parser;
use XML::LibXML qw':all';

my @services = qw(Facebook CreativeCommons);

my $CGI = CGI->new;
my $url = $CGI->param('url') || $CGI->param('uri') || shift @ARGV || die "please provide a URL!\n";

my $template = slurp('linter-template.xml');
my $dom = XML::LibXML->new->parse_string($template);
my $xpc = XML::LibXML::XPathContext->new($dom);
$xpc->registerNs('x', XHTML_NS);
my $gen = RDF::RDFa::Generator->new(style=>'HTML::Pretty', safe_xml_literals=>1);

# Title
my @title = $dom->getElementsByTagName('title');
$title[0]->appendTextNode("Lint Results for $url");

# Header
my @head = $xpc->findnodes('//x:*[@class="head"]');
$head[0]->addNewChild(XHTML_NS, 'h1')->appendTextNode("RDFa Linter");

# Form
my @summary = $xpc->findnodes('//x:input[@name="url"]');
$summary[0]->setAttribute('value', $url);

# Summary
my @summary = $xpc->findnodes('//x:*[@class="summary"]');
$summary[0]->addNewChild(XHTML_NS, 'p')->appendTextNode("Results for <$url>.");

# Main tab
my $rdfa_parser = RDF::RDFa::Parser->new_from_url($url);
my @main_errs;
$rdfa_parser->set_callbacks({oncurie => \&main_cb_oncurie});
my $main_tab = _add_tab($xpc, 'RDFa', undef, 0, 'All Data');
$main_tab->addNewChild(XHTML_NS, 'p')->appendTextNode("This tab shows all RDFa data extracted from your page; the other tabs filter this data down to show what particular services will see.");
foreach my $node ($gen->nodes($rdfa_parser->graph, notes=>\@main_errs))
{
	$node->setAttribute('class', $node->getAttribute('class').' rdfa');
	$main_tab->appendChild($node);
}
@main_errs = qw();

# Service tabs
foreach my $srv (@services)
{
	my $this_parser = RDF::RDFa::Parser->new($rdfa_parser->dom, $rdfa_parser->uri);
	my $linter      = RDF::RDFa::Linter->new($srv, $url, $this_parser);
	
	my $this_tab    = _add_tab($xpc, $linter->info->{'short'}, undef, 0, $linter->info->{'title'});	
	$this_tab->addNewChild(XHTML_NS, 'p')->appendTextNode($linter->info->{'description'});
	
	if ($linter->filtered_graph->count_statements)
	{
		foreach my $node ($gen->nodes($linter->filtered_graph, notes=>[$linter->find_errors]))
		{
			$node->setAttribute('class', $node->getAttribute('class').' rdfa');
			$this_tab->appendChild($node);
		}
	}
	else
	{
		$this_tab->addNewChild(XHTML_NS, 'p')->appendTextNode("No data found by this service.");
	}
}

# Output
my $var = choose([
	[ 'html', 1.000, 'text/html'],
	[ 'xhtml', 0.900, 'application/xhtml+xml'],
	]) || 'html';
print $CGI->header($var eq 'html' ? 'text/html' : 'application/xhtml+xml')
	if defined $CGI->request_method;
print HTML::HTML5::Writer->new(markup=>$var)->document($dom);

sub _xpath_has_class
{
	my ($nodelist, $class) = @_;
	my $result = XML::LibXML::NodeList->new;
	for my $node ($nodelist->get_nodelist)
	{
		next unless $node->nodeType eq XML_ELEMENT_NODE;
		next unless $node->hasAttribute('class');
		$result->push($node) if $node->getAttribute('class') =~ /\b($class)\b/;
	}
	return $result;
}

sub _add_tab
{
	my ($xpc, $title, $id, $index, $long) = @_;
	
	($id = 'tab-'.lc $title) =~ s/[^a-z0-9-]//i
		unless defined $id;
	
	$index = 0 unless defined $index;
		
	my @containers = $xpc->findnodes('//x:*[@class="tabs"]');
	my $tab = $containers[$index]->addNewChild(XHTML_NS, 'div');
	$tab->setAttribute('id', $id);	
	$tab->addNewChild(XHTML_NS, 'h2')->appendTextNode($long||$title);
	
	my @menus = $xpc->findnodes('//x:*[@class="tabNavigation"]');
	my $item = $menus[$index]->addNewChild(XHTML_NS, 'li');
	my $a = $item->addNewChild(XHTML_NS, 'a');
	$a->setAttribute('href', '#'.$id);
	$a->appendTextNode($title);
	
	return $tab;
}

sub main_cb_oncurie
{
	my ($parser, $node, $curie, $uri) = @_;

	return $uri unless $curie eq $uri || $uri eq '';

	my $preferred = {
			bibo => 'http://purl.org/ontology/bibo/' ,
			cc => 'http://creativecommons.org/ns#' ,
			ctag => 'http://commontag.org/ns#' ,
			dbp => 'http://dbpedia.org/property/' ,
			dc => 'http://purl.org/dc/terms/' ,
			doap => 'http://usefulinc.com/ns/doap#' ,
			fb => 'http://developers.facebook.com/schema/' ,
			foaf => 'http://xmlns.com/foaf/0.1/' ,
			geo => 'http://www.w3.org/2003/01/geo/wgs84_pos#' ,
			gr => 'http://purl.org/goodrelations/v1#' ,
			ical => 'http://www.w3.org/2002/12/cal/ical#' ,
			og => 'http://opengraphprotocol.org/schema/' ,
			owl => 'http://www.w3.org/2002/07/owl#' ,
			rdf => 'http://www.w3.org/1999/02/22-rdf-syntax-ns#' ,
			rdfa => 'http://www.w3.org/ns/rdfa#' ,
			rdfs => 'http://www.w3.org/2000/01/rdf-schema#' ,
			rel => 'http://purl.org/vocab/relationship/' ,
			rev => 'http://purl.org/stuff/rev#' ,
			rss => 'http://purl.org/rss/1.0/' ,
			sioc => 'http://rdfs.org/sioc/ns#' ,
			skos => 'http://www.w3.org/2004/02/skos/core#' ,
			v => 'http://rdf.data-vocabulary.org/#' ,
			vann => 'http://purl.org/vocab/vann/' ,
			vcard => 'http://www.w3.org/2006/vcard/ns#' ,
			void => 'http://rdfs.org/ns/void#' ,
			xfn => 'http://vocab.sindice.com/xfn#' ,
			xhv => 'http://www.w3.org/1999/xhtml/vocab#' ,
			xsd => 'http://www.w3.org/2001/XMLSchema#' ,
		};
	
	if ($curie =~ m/^([^:]+):(.*)$/)
	{
		my ($pfx, $sfx) = ($1, $2);
		
		if (defined $preferred->{$pfx})
		{
			push @main_errs,
				RDF::RDFa::Linter::Error->new(
					'subject' => RDF::Trine::Node::Resource->new($url),
					'text'    => "CURIE '$curie' used but '$pfx' is not bound - perhaps you forgot to specify xmlns:${pfx}=\"".$preferred->{$pfx}."\"",
					'level'   => 5,
					);
		}
		elsif ($pfx !~ m'^(http|https|file|ftp|urn|tag|mailto|acct|data|
			fax|tel|modem|gopher|info|news|sip|irc|javascript|sgn|ssh|xri|widget)$'ix)
		{
			push @main_errs,
				RDF::RDFa::Linter::Error->new(
					'subject' => RDF::Trine::Node::Resource->new($url),
					'text'    => "CURIE '$curie' used but '$pfx' is not bound - perhaps you forgot to specify xmlns:${pfx}=\"SOMETHING\"",
					'level'   => 1,
					);
		}
	}

	return $uri;
}
