use inc::Module::Install;
name 'Xatana';
all_from 'lib/Xatana.pm';

# requires '';

tests 't/*.t';
author_tests 'xt';

test_requires 'Test::More';
auto_set_repository;
auto_include;
WriteAll;
