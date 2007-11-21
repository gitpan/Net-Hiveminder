use inc::Module::Install;

name            'Net-Hiveminder';
all_from        'lib/Net/Hiveminder.pm';

requires        'Net::Jifty' => '0.02';
requires        'Number::RecordLocator';

build_requires  'Test::More';

auto_install;
WriteAll;


