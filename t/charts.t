BEGIN { $ENV{PASTE_ENABLE_CHARTS} = 1 }
use t::Helper;

my $t = t::Helper->t;
my ($raw, $file, $json);

plan skip_all => "$ENV{PASTE_DIR} was not created" unless -d $ENV{PASTE_DIR};

$raw = q(
#
# Some cool header
#
# A wonderful
  # description.

      [
  { "x": "2015-02-04 15:03", "a": 120, "b": 90 },
  { "x": "2015-03-14", "a": 75, "b": 65 },
  { "x": "2015-04", "a": 100, "b": 40 }
]);
$t->post_ok('/', form => {paste => $raw, p => 1})->status_is(302);
$file = $t->tx->res->headers->location =~ m!/(\w+)$! ? $1 : 'nope';
$t->get_ok("/$file")->status_is(200)->element_exists(qq(a[href\$="/chart"]));

$t->get_ok("/$file/chart")->status_is(200)->content_like(qr{jquery\.min\.js})->content_like(qr{morris\.css})
  ->content_like(qr{morris\.min\.js})->content_like(qr{raphael-min\.js})->element_exists('div[id="chart"]')
  ->element_exists('nav')->text_like('h2', qr{Some cool header}, 'header')
  ->text_like('p', qr{A wonderful description\.}, 'description');

$json = $t->tx->res->body =~ m!new Morris\.Line\(([^\)]+)\)! ? Mojo::JSON::decode_json($1) : undef;
is_deeply($json->{labels}, ['a', 'b'], 'default labels');
is_deeply($json->{ykeys},  ['a', 'b'], 'default ykeys');
is($json->{element}, 'chart', 'default element');
is($json->{xkey},    'x',     'default xkey');

$t->get_ok("/$file/chart?embed=chart")->status_is(200)->element_exists_not('h2')->element_exists_not('nav')
  ->element_exists_not('p');

$raw = q(
  // some comment
# Some other comment
     {
  "labels": ["Down", "Up"],
  "data": [
    { "x": "2015-02-04 15:03", "b": 90 },
    { "x": "2015-02-04 15:03", "a": 120, "b": 90, "c": 12 },
    { "x": "2015-03-14", "a": 75, "b": 65 },
    { "x": "2015-04", "a": 100, "b": 40 }
  ]
});
$t->post_ok('/', form => {paste => $raw, p => 1})->status_is(302);
$file = $t->tx->res->headers->location =~ m!/(\w+)$! ? $1 : 'nope';
$t->get_ok("/$file/chart")->status_is(200);

$json = $t->tx->res->body =~ m!new Morris\.Line\(([^\)]+)\)! ? Mojo::JSON::decode_json($1) : undef;
is_deeply($json->{labels}, ['Down', 'Up'], 'labels');
is_deeply($json->{ykeys}, ['a', 'b', 'c'], 'default ykeys');

$raw = qq( { "labels": ["Down", "Up"],,,, invalid );
$t->post_ok('/', form => {paste => $raw, p => 1})->status_is(302);
$file = $t->tx->res->headers->location =~ m!/(\w+)$! ? $1 : 'nope';
$t->get_ok("/$file/chart")->status_is(200)->content_unlike(qr{new Morris})
  ->text_like('#chart', qr{Could not parse chart arguments:});

$raw = qq( [ "labels": ["Down", "Up"],,,, invalid );
$t->post_ok('/', form => {paste => $raw, p => 1})->status_is(302);
$file = $t->tx->res->headers->location =~ m!/(\w+)$! ? $1 : 'nope';
$t->get_ok("/$file/chart")->status_is(200)->content_unlike(qr{new Morris})
  ->text_like('#chart', qr{Could not parse chart data:});

if (eval 'require Text::CSV;1') {
  $raw = qq( "labels"\n: ["Down", "Up"],,,, invali\nd );
  $t->post_ok('/', form => {paste => $raw, p => 1})->status_is(302);
  $file = $t->tx->res->headers->location =~ m!/(\w+)$! ? $1 : 'nope';
  $t->get_ok("/$file/chart")->status_is(200)->content_unlike(qr{new Morris})
    ->text_like('#chart', qr{Could not parse CSV data:});

  $raw = <<"HERE";


#
# This data is retrive from this command...
#

Date,Down,Up
2015-02-04 15:03,120,90
2015-03-14,75,65

# this is a bit weird...?
2015-04,100,40

#
HERE
  $t->post_ok('/', form => {paste => $raw, p => 1})->status_is(302);
  $file = $t->tx->res->headers->location =~ m!/(\w+)$! ? $1 : 'nope';
  $t->get_ok("/$file/chart")->status_is(200);

  $json = $t->tx->res->body =~ m!new Morris\.Line\(([^\)]+)\)! ? Mojo::JSON::decode_json($1) : undef;
  is_deeply($json->{labels}, ['Down', 'Up'], 'csv labels');
  is_deeply($json->{ykeys},  ['Down', 'Up'], 'csv ykeys');
  is($json->{xkey}, 'Date', 'xkey');
}
else {
SKIP: { skip 'Text::CSV is required', 1; }
}

unlink glob("$ENV{PASTE_DIR}/*");

done_testing;
