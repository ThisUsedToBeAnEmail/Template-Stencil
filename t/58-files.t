use strict;
use warnings;
use Test::More;
use Template::Stencil;

# files => 0: an engine that reads no file. A source is never a file's
# name, include, content and a wrapper are refused at compile with the
# tag's place, and what a template can do without files is unchanged.

my $open = Template::Stencil->new;
my $shut = Template::Stencil->new(files => 0);

is($shut->{files}, 0, 'the option is kept');
is($open->{files}, 1, '  and is 1 by default');

# a one-word source that names a file
like($open->render('Makefile.PL', {}), qr/WriteMakefile/, 'by default a one-word source naming a file renders the file');
is($shut->render('Makefile.PL', {}), 'Makefile.PL', 'files => 0: it is text');
is($shut->render('t/template/loops', {}), 't/template/loops', '  with .tmpl inferred by default, still text');
is(Template::Stencil::render($shut, 'Makefile.PL', {}), 'Makefile.PL', '  through the direct call too');

# include and content refused, with the tag's place
sub refused {
    my ($src, $re, $what) = @_;
    my $ok = eval { $shut->render($src, {}); 1 };
    ok(!$ok, "$what: refused");
    like($@, $re, '  saying where and why');
}
refused('{% include Makefile.PL %}', qr/\ATemplate::Stencil: <string>:1:1: include is refused: this engine reads no files \(files => 0\)/, 'an include of a file in the working directory');
refused("one\n  two {% include t/template/loops %}", qr/<string>:2:7: include is refused/, 'an include on line 2');
refused('{% for x in xs %}{% include nothing %}{% end %}', qr/<string>:1:18: include is refused/, 'an include in a loop');
refused('{% if 1 %}{% include x.tmpl %}{% end %}', qr/include is refused/, 'an include in a branch never taken at render');
refused('{%include Makefile.PL%}', qr/include is refused/, 'an include without spaces');
refused("a\n{% content %}\nb", qr/<string>:2:1: content is refused: this engine reads no files/, 'content');
{
    my $ok = eval { $shut->render('hi', {}, { wrapper => 'x.tmpl' }); 1 };
    ok(!$ok, 'a wrapper asked at render: refused');
    like($@, qr/a wrapper is refused: this engine reads no files \(files => 0\)/, '  saying why');
}
like(eval { Template::Stencil->new(files => 0, template_dir => 't/template'); 1 } ? '' : $@,
     qr/template_dir and files => 0 cannot go together/, 'template_dir with files => 0: croaks');
like(eval { Template::Stencil->new(template_dir => 't/template', files => 0); 1 } ? '' : $@,
     qr/template_dir and files => 0 cannot go together/, '  in either order');
like(eval { Template::Stencil->new(files => 0, wrapper => 'w.tmpl'); 1 } ? '' : $@,
     qr/wrapper and files => 0 cannot go together/, 'a wrapper with files => 0: croaks');
ok(eval { Template::Stencil->new(files => 0, template_dir => undef, wrapper => undef); 1 }, 'undef for either is no option at all');
ok(eval { Template::Stencil->new({ files => 0 }); 1 }, 'the option in a hashref too');

# everything else unchanged
my $data = { name => 'Ada & <Grace>', xs => [1, 2, 3], h => { b => 2, a => 1 }, files => 'a key', include => 'also a key' };
for my $src ('Hi {% name %}', "{% for x in xs %}[{% x %}]{% end %}\n", '{% for k, v in h %}{% k %}={% v %};{% end %}',
             '{% if name %}yes{% else %}no{% end %}', '{% name | upper %} {% raw name %} {% name | uri %}',
             '{% set y = name %}{% y | default("z") %}', '{% files %} and {% include_me | default("d") %}',
             "{# a comment #}x\n", '{% h.a %}{% h.b %}') {
    is($shut->render($src, $data), $open->render($src, $data), "the same as an engine with files: '" . ($src =~ s/\n/\\n/gr) . "'");
}
is($shut->render('{% name %}', $data), 'Ada &amp; &lt;Grace&gt;', 'escaping is still on');
my $deep = ('{% if 1 %}' x 64) . 'x' . ('{% end %}' x 64);
is($shut->render($deep, {}), 'x', 'nesting to 64 still renders');
ok(!eval { $shut->render('{% if 1 %}' x 65 . ('{% end %}' x 65), {}); 1 }, '65 is still refused');

# the same source in two engines: each its own compile
my $src = '{% include Makefile.PL %}';
like($open->render($src, {}), qr/WriteMakefile/, 'an engine with files reads the include');
ok(!eval { $shut->render($src, {}); 1 }, '  the one without, given the same source after it, refuses');

done_testing;
