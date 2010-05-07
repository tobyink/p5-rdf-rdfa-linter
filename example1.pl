use lib "lib";
use Data::Dumper;
use RDF::RDFa::Linter::Facebook;
use RDF::RDFa::Parser;
use RDF::TrineShortcuts;

my $uri    = 'http://srv.buzzword.org.uk/opengraph-to-json.html';
my $model  = RDF::RDFa::Parser->new_from_url($uri)->graph;
my $linter = RDF::RDFa::Linter::Facebook->new($model, $uri);

print rdf_string($linter->{'filtered'});

print Dumper([ $linter->find_errors ]);