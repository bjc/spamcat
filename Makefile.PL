use ExtUtils::MakeMaker;

WriteMakefile(NAME         => 'SpamCat',
	      VERSION_FROM =>  'lib/SpamCat.pm',
	      EXE_FILES    => ['bin/spamcat'],
              PREREQ_PM    => {'DBI'           => '0',
			       'Email::Simple' => '0',
			       'IO::File'      => '0',
	                       'Test::More'    => '0'});
