use Test::More;
use Test::Pod::Coverage;

my @modules = qw(RDF::RDFa::Linter RDF::RDFa::Linter::Error RDF::RDFa::Linter::Service);
pod_coverage_ok($_, "$_ is covered")
	foreach @modules;
done_testing(scalar @modules);

