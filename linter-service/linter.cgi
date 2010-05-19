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
use RDF::RDFa::Parser;
use XML::LibXML qw':all';

my @services = qw(Facebook CreativeCommons);

my $CGI = CGI->new;
my $url = $CGI->param('url') || $CGI->param('uri') || shift @ARGV || die "please provide a URL!\n";

my $template = slurp('linter-template.xml');
my $dom = XML::LibXML->new->parse_string($template);
my $xpc = XML::LibXML::XPathContext->new($dom);
$xpc->registerNs('x', XHTML_NS);
my $gen = RDF::RDFa::Generator->new(style=>'HTML::Pretty');

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
my $main_tab = _add_tab($xpc, 'RDFa', undef, 0, 'All Data');
$main_tab->addNewChild(XHTML_NS, 'p')->appendTextNode("This tab shows all RDFa data extracted from your page; the other tabs filter this data down to show what particular services will see.");
foreach my $node ($gen->nodes($rdfa_parser->graph))
{
	$node->setAttribute('class', $node->getAttribute('class').' rdfa');
	$main_tab->appendChild($node);
}

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
