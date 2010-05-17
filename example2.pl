use 5.010;
use lib "lib";
use lib "../RDF-RDFa-Generator/lib/";
use Data::Dumper;
use RDF::RDFa::Generator;
use RDF::RDFa::Linter;
use RDF::RDFa::Parser;
use RDF::TrineShortcuts;

my $uri    = shift @ARGV || 'http://srv.buzzword.org.uk/opengraph-to-json.html';
my $parser = RDF::RDFa::Parser->new_from_url($uri);
my $linter = RDF::RDFa::Linter->new('CreativeCommons', $uri, $parser);

my $gen = RDF::RDFa::Generator->new(style  => 'HTML::Pretty');

say $gen->create_document($linter->filtered_graph, notes=>[$linter->find_errors])->toString;
