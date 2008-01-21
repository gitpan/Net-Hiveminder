use inc::Module::Install;

name            'Net-Hiveminder';
all_from        'lib/Net/Hiveminder.pm';

requires        'Net::Jifty' => '0.04';
requires        'Number::RecordLocator';

features(
    'comment on tasks' => [
        -default => 1,
        requires('Email::Simple::Creator'),
    ],
);

build_requires  'Test::More';

auto_install;
WriteAll;


