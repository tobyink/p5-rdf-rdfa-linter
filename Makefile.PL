use strict;
use warnings;

use inc::Module::Install;

my $dist = 'RDF-RDFa-Linter';
my $fn   = "lib/$dist.pm"; $fn =~ s#-#/#g;

name                $dist;
perl_version_from   $fn;
version_from        $fn;
abstract_from       $fn;
readme_from         $fn;
author              'Toby Inkster <tobyink@cpan.org>';
license             'perl';

test_requires       'Module::Signature'   => '0.66';
test_requires       'Test::More'          => '0.61';
requires            'RDF::Trine'          => '0.112';
requires            'RDF::TrineShortcuts' => '0.100';
requires            'RDF::RDFa::Generator'=> '0.02';
requires            'RDF::RDFa::Parser'   => '1.093';
requires            'XML::LibXML'         => '1.60';

resources(
	'homepage'   => "http://search.cpan.org/dist/$dist/",
	'repository' => "http://goddamn.co.uk/viewvc/perlmods/$dist/",
	'bugtracker' => "http://rt.cpan.org/Dist/Display.html?Queue=$dist",
	);

keywords(qw(SemWeb Semantic Web HTML XHTML RDF RDFa Linter Validator Checker));

write_doap_changes;
write_doap_changes_xml;

include 'Test::Signature';
auto_install;
WriteAll(
	'meta' => 1,
	'sign' => 1,
	);
